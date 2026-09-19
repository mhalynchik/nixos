"""Wallpaper catalogue and reversible previews; only Enter/Apply commits selection."""
import concurrent.futures
import hashlib
import json
import os
from pathlib import Path
import select
import signal
import subprocess
import sys
import time

STATIC = {'.png', '.jpg', '.jpeg', '.webp', '.avif', '.bmp'}
ANIMATED = {'.gif', '.mp4', '.webm', '.mkv', '.mov'}


class WallpaperQueue:
    """Coalesce hover work without ever replacing an accepted Enter command."""
    def __init__(self):
        self.pending = []
        self.active = None

    def put(self, message):
        action = message['action']
        if action == 'preview':
            if self.active and self.active['action'] == 'commit' or any(x['action'] == 'commit' for x in self.pending):
                return
            self.pending = [x for x in self.pending if x['action'] != 'preview']
            # A cancel restores the previous session before the next preview.
            position = next((i for i, x in enumerate(self.pending) if x['action'] not in ['cancel', 'index']), len(self.pending))
            self.pending.insert(position, message)
        elif action in ['cancel', 'commit']:
            self.pending = [x for x in self.pending if x['action'] not in ['preview', 'thumbnail']]
            if action == 'commit' and (self.active and self.active['action'] == 'commit' or any(x['action'] == 'commit' for x in self.pending)):
                return
            if not self.pending or self.pending[-1] != message:
                self.pending.append(message)
        elif message != self.active and message not in self.pending:
            self.pending.append(message)

    def take(self):
        self.active = self.pending.pop(0)
        return self.active

    def finish(self):
        self.active = None


def catalogue(config):
    items = []
    seen = set()
    for kind, suffixes in [('static', STATIC), ('animated', ANIMATED)]:
        for directory in config.get(kind, []):
            root = Path(directory).expanduser()
            if not root.is_dir():
                continue
            for current, dirs, files in os.walk(root):
                depth = len(Path(current).relative_to(root).parts)
                dirs[:] = sorted(d for d in dirs if not d.startswith('.') and depth < 5)
                for name in sorted(files):
                    path = (Path(current)/name).resolve()
                    if path.suffix.lower() not in suffixes or path in seen or not path.is_file():
                        continue
                    seen.add(path)
                    items.append({'id': hashlib.sha256(str(path).encode()).hexdigest()[:24],
                        'name': name, 'path': str(path), 'url': path.as_uri(), 'kind': kind,
                        'thumbnail': path.as_uri() if kind == 'static' else ''})
                    if len(items) >= 2000:
                        return items
    return items


class WallpaperSession:
    def __init__(self, config=None, home=None, runner=None):
        self.home = Path(home or Path.home())
        self.state = self.home/'.local/state'
        self.current = self.state/'current-wallpaper'
        self.marker = self.state/'event-horizon/wallpaper-preview.json'
        self.cache = self.home/'.cache/event-horizon/wallpapers'
        self.config = config or {'static': [str(self.home/'Pictures/static')], 'animated': [str(self.home/'Pictures/animated')]}
        self.run = runner or self.run_command
        self.items = {}
        self.player = None
        self.player_log = None

    @staticmethod
    def run_command(args, timeout=20):
        result = subprocess.run(args, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
            stderr=subprocess.PIPE, text=True, timeout=timeout)
        if result.returncode:
            raise RuntimeError((result.stderr.strip() or result.stdout.strip() or 'Wallpaper command failed')[:350])
        return result.stdout

    def index(self):
        items = catalogue(self.config)
        self.cache.mkdir(parents=True, exist_ok=True)
        for item in items:
            if item['kind'] == 'animated':
                key = item['id']+'-'+str(Path(item['path']).stat().st_mtime_ns)
                thumb = self.cache/(key+'.png')
                if thumb.is_file():
                    item['thumbnail'] = thumb.as_uri()
        self.items = {item['id']: item for item in items}
        return {'items': items, 'directories': self.config}

    def thumbnail(self, ident):
        item = self.resolve(ident)
        key = item['id']+'-'+str(Path(item['path']).stat().st_mtime_ns)
        target = self.cache/(key+'.png')
        if not target.exists():
            temporary = target.with_suffix('.tmp.png')
            try:
                self.run(['ffmpeg', '-v', 'error', '-y', '-threads', '1', '-i', item['path'], '-frames:v', '1',
                    '-vf', 'scale=240:150:force_original_aspect_ratio=decrease', '-threads', '1', str(temporary)], timeout=12)
                temporary.replace(target)
            finally:
                temporary.unlink(missing_ok=True)
        item['thumbnail'] = target.as_uri()
        return {'thumbnail': {'id': ident, 'url': target.as_uri()}}

    def resolve(self, ident):
        item = self.items.get(ident)
        if not item or not Path(item['path']).is_file():
            raise ValueError('Обои больше недоступны. Обнови список.')
        return item

    def stop_player(self):
        if self.player:
            if self.player.poll() is None:
                os.killpg(self.player.pid, signal.SIGTERM)
                try:
                    self.player.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    os.killpg(self.player.pid, signal.SIGKILL)
                    self.player.wait(timeout=3)
            self.player = None
        if self.player_log:
            self.player_log.close()
            self.player_log = None

    def render_static(self, path):
        self.run(['swww', 'img', str(path), '--transition-type', 'fade', '--transition-duration', '0.2', '--transition-fps', '30'])

    def preview(self, ident):
        item = self.resolve(ident)
        self.marker.parent.mkdir(parents=True, exist_ok=True)
        # Never modify either persistent wallpaper symlink during a preview.
        if not self.marker.exists():
            self.marker.write_text(json.dumps({'original': str(self.current.resolve())}))
            self.marker.chmod(0o600)
        self.stop_player()
        self.run(['systemctl', '--user', 'stop', 'animated-wallpaper.service'])
        if item['kind'] == 'static':
            self.render_static(item['path'])
        else:
            self.player_log = (self.cache/'preview.log').open('w')
            self.player = subprocess.Popen(['mpvpaper', '-o', 'no-audio loop no-cache hwdec=no vd-lavc-threads=1 no-config', '*', item['path']],
                stdin=subprocess.DEVNULL, stdout=self.player_log, stderr=self.player_log, start_new_session=True)
            time.sleep(.15)
            if self.player.poll() is not None:
                raise RuntimeError('Не удалось запустить анимированный предпросмотр.')
        return {'preview': ident}

    def restore(self):
        self.stop_player()
        if not self.marker.exists():
            return {'preview': ''}
        # If another picker committed a wallpaper meanwhile, respect its choice.
        target = self.current.resolve()
        if not target.is_file():
            raise ValueError('Установленные обои недоступны; выбери другой файл.')
        if target.suffix.lower() in ANIMATED:
            self.run(['systemctl', '--user', 'restart', 'animated-wallpaper.service'])
        else:
            self.run(['systemctl', '--user', 'stop', 'animated-wallpaper.service'])
            self.render_static(target)
        self.marker.unlink(missing_ok=True)
        return {'preview': ''}

    def commit(self, ident):
        item = self.resolve(ident)
        self.stop_player()
        self.run(['wallpaper-set', item['path']], timeout=45)
        self.marker.unlink(missing_ok=True)
        return {'preview': '', 'committed': ident}


def main():
    path = os.environ.get('EVENT_HORIZON_WALLPAPER_CONFIG')
    config = json.loads(Path(path).read_text()) if path else None
    session = WallpaperSession(config)
    if '--restore' in sys.argv:
        session.restore()
        return
    pool = concurrent.futures.ThreadPoolExecutor(max_workers=1)
    future, queue, buffer = None, WallpaperQueue(), b''
    alive = True
    def stop(*args):
        nonlocal alive
        alive = False
    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    try:
        session.restore()
        while alive:
            if select.select([sys.stdin], [], [], .1)[0]:
                chunk = os.read(sys.stdin.fileno(), 65536)
                if not chunk:
                    break
                buffer += chunk
                while b'\n' in buffer:
                    line, buffer = buffer.split(b'\n', 1)
                    try:
                        message = json.loads(line)
                    except ValueError:
                        continue
                    action = message.get('action')
                    if action not in ['index', 'thumbnail', 'preview', 'cancel', 'commit']:
                        continue
                    queue.put(message)
            if future and future.done():
                try:
                    print(json.dumps(future.result(), ensure_ascii=False), flush=True)
                except Exception as error:
                    print(json.dumps({'error': str(error)[:400]}), flush=True)
                future = None
                queue.finish()
            if future is None and queue.pending:
                message = queue.take()
                action = message['action']
                function = {'index': session.index, 'thumbnail': session.thumbnail, 'preview': session.preview,
                            'cancel': session.restore, 'commit': session.commit}[action]
                future = pool.submit(function, *([message['id']] if action in ['thumbnail', 'preview', 'commit'] else []))
    finally:
        pool.shutdown(wait=True, cancel_futures=True)
        session.restore()


if __name__ == '__main__':
    main()
