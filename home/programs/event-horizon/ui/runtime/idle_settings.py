"""Persistent idle preferences and a short-lived Hypridle configuration launcher."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

DEFAULTS = {'lockMinutes': 10, 'screenMinutes': 15, 'suspendMinutes': 30}
LOCK_COMMAND = 'pidof hyprlock || hyprctl dispatch exec hyprlock'


def state_root():
    return Path(os.environ.get('EVENT_HORIZON_STATE_DIR', str(
        Path(os.environ.get('XDG_STATE_HOME', str(Path.home() / '.local/state'))) / 'event-horizon')))


def validate(values):
    if not isinstance(values, dict) or set(values) != set(DEFAULTS):
        raise ValueError('Укажите все три таймаута: блокировка, экран и сон.')
    if any(type(value) is not int or not 0 <= value <= 240 for value in values.values()):
        raise ValueError('Таймаут должен быть целым числом от 1 до 240 минут; 0 отключает действие.')
    lock = values['lockMinutes']
    if lock and any(value and value < lock for value in (values['screenMinutes'], values['suspendMinutes'])):
        raise ValueError('Выключение экрана и сон не должны происходить раньше блокировки.')
    return dict(values)


def atomic_write(path, content):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix='.' + path.name + '-', dir=path.parent)
    try:
        with os.fdopen(fd, 'w') as stream:
            stream.write(content)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def restart_hypridle():
    completed = subprocess.run(['systemctl', '--user', 'restart', 'hypridle.service'],
                               capture_output=True, text=True, timeout=15)
    if completed.returncode:
        raise RuntimeError(completed.stderr.strip() or 'Не удалось перезапустить Hypridle.')
    # A successful start request alone does not prove that the daemon stayed up.
    subprocess.run(['systemctl', '--user', 'is-active', '--quiet', 'hypridle.service'],
                   check=True, capture_output=True, timeout=3)


class IdleSettings:
    def __init__(self, path=None):
        self.path = Path(path) if path is not None else state_root() / 'idle.json'
        self.error = ''
        self.values = dict(DEFAULTS)
        try:
            data = json.loads(self.path.read_text())
            if not isinstance(data, dict) or data.get('version', 0) not in (0, 1):
                raise ValueError('неизвестный формат')
            version = data.pop('version', 0)
            # Migrate an early, unversioned preference file without losing its values.
            if version == 0:
                data = dict(DEFAULTS, **data)
            self.values = validate(data)
        except FileNotFoundError:
            pass
        except (OSError, ValueError, TypeError) as error:
            self.error = 'Не удалось прочитать настройки ожидания; используются 10/15/30 минут: ' + str(error)

    def apply(self, values, restart=restart_hypridle):
        candidate = validate(values)
        previous = self.path.read_text() if self.path.exists() else None
        atomic_write(self.path, json.dumps(dict(version=1, **candidate), ensure_ascii=False) + '\n')
        try:
            restart()
        except (OSError, RuntimeError, subprocess.SubprocessError) as error:
            if previous is None:
                self.path.unlink()
            else:
                atomic_write(self.path, previous)
            recovery_error = ''
            try:
                restart()
            except (OSError, RuntimeError, subprocess.SubprocessError):
                recovery_error = ' Hypridle не удалось восстановить; проверьте его службу.'
            raise RuntimeError('Настройки не применены, сохранён прежний выбор.' + recovery_error) from error
        self.values = candidate
        self.error = ''


def render_config(base, values):
    values = validate(values)
    result = [base.rstrip(), '']
    actions = [
        ('lockMinutes', LOCK_COMMAND, None),
        ('screenMinutes', 'hyprctl dispatch dpms off', 'hyprctl dispatch dpms on'),
        ('suspendMinutes', 'systemctl suspend', None),
    ]
    for key, command, resume in actions:
        if values[key] == 0:
            continue
        result.extend(['listener {', f'    timeout = {values[key] * 60}', f'    on-timeout = {command}'])
        if resume:
            result.append(f'    on-resume = {resume}')
        result.append('}')
    return '\n'.join(result) + '\n'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--hypridle', required=True)
    parser.add_argument('--base', type=Path, default=Path(os.environ.get('XDG_CONFIG_HOME', str(Path.home() / '.config'))) / 'hypr/hypridle.conf')
    args = parser.parse_args()
    settings = IdleSettings()
    if settings.error:
        print(settings.error, file=sys.stderr)
    runtime = Path(os.environ['XDG_RUNTIME_DIR']) / 'event-horizon'
    runtime.mkdir(mode=0o700, parents=True, exist_ok=True)
    config = runtime / 'hypridle.conf'
    atomic_write(config, render_config(args.base.read_text(), settings.values))
    # No extra Python daemon remains resident after starting Hypridle.
    os.execv(args.hypridle, [args.hypridle, '--config', str(config)])


if __name__ == '__main__':
    main()
