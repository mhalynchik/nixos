"""Temporarily reserve Bluetooth authorization for Event Horizon.

Blueman's AuthAgent is a second, default BlueZ agent. Disable only that
plugin while the shell runs, retaining unrelated user plugin preferences.
"""
import argparse
import ast
import fcntl
import json
import os
from pathlib import Path
import subprocess

from idle_settings import atomic_write

KEY = '/org/blueman/general/plugin-list'
AGENT_ENTRIES = {'AuthAgent', '!AuthAgent'}


class DconfPlugins:
    def read(self):
        raw = subprocess.run(['dconf', 'read', KEY], check=True, text=True,
                             capture_output=True, timeout=10).stdout.strip()
        if not raw:
            return None
        values = ast.literal_eval(raw.removeprefix('@as '))
        if not isinstance(values, list) or any(not isinstance(x, str) for x in values):
            raise ValueError('Invalid Blueman plugin list')
        return values

    def write(self, values):
        command = ['dconf', 'reset', KEY] if values is None else [
            'dconf', 'write', KEY, repr(values) if values else '@as []']
        subprocess.run(command, check=True, capture_output=True, timeout=10)


def reserve(path, settings):
    current = settings.read()
    if path.exists():
        previous = json.loads(path.read_text())
        if previous.get('version') != 1:
            raise ValueError('Unknown Blueman authorization state')
    else:
        previous = {'version': 1, 'unset': current is None,
                    'agent': [x for x in current or [] if x in AGENT_ENTRIES]}
        atomic_write(path, json.dumps(previous) + '\n')
    disabled = [x for x in current or [] if x not in AGENT_ENTRIES] + ['!AuthAgent']
    if disabled != current:
        settings.write(disabled)


def restore(path, settings):
    if not path.exists():
        return
    previous = json.loads(path.read_text())
    if previous.get('version') != 1:
        raise ValueError('Unknown Blueman authorization state')
    current = settings.read()
    # Respect an explicit user change made since the shell acquired the lease.
    if [x for x in current or [] if x in AGENT_ENTRIES] == ['!AuthAgent']:
        restored = [x for x in current or [] if x not in AGENT_ENTRIES] + previous['agent']
        settings.write(None if previous['unset'] and not restored else restored)
    path.unlink()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['reserve', 'restore'])
    args = parser.parse_args()
    root = Path(os.environ.get('XDG_STATE_HOME', str(Path.home() / '.local/state'))) / 'event-horizon'
    root.mkdir(parents=True, exist_ok=True, mode=0o700)
    path = root / 'blueman-agent.json'
    fd = os.open(root / 'blueman-agent.lock', os.O_CREAT | os.O_RDWR, 0o600)
    with os.fdopen(fd, 'w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        (reserve if args.action == 'reserve' else restore)(path, DconfPlugins())


if __name__ == '__main__':
    main()
