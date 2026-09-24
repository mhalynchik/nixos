"""Private clipboard history and explicit, asynchronous Wayland screen capture.

Clipboard contents stay local (0700 directory, 0600 SQLite database). wl-paste
marks password selections as sensitive; applications that omit that hint cannot
be detected reliably, so the picker always offers Pause and Clear.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import signal
import sqlite3
import subprocess
import sys
import tempfile
import time
import uuid

MAX_ITEM = 8 * 1024 * 1024
MAX_TOTAL = 32 * 1024 * 1024
MAX_ITEMS = 100
MAX_PINS = 20
RETENTION = 7 * 86400
THUMBNAIL_EDGE = 160
MAX_IMAGE_PIXELS = 16 * 1024 * 1024
IMAGE_FORMATS = {'image/png': 'png_pipe', 'image/jpeg': 'jpeg_pipe', 'image/webp': 'webp_pipe', 'image/bmp': 'bmp_pipe'}


def private_dir(path):
    path = Path(path)
    path.mkdir(parents=True, exist_ok=True, mode=0o700)
    path.chmod(0o700)
    return path


def atomic_json(path, value):
    path = Path(path)
    fd, temporary = tempfile.mkstemp(prefix=path.name, dir=path.parent)
    try:
        with os.fdopen(fd, 'w') as stream:
            json.dump(value, stream, ensure_ascii=False)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def read_json(path, default):
    try:
        value = json.loads(Path(path).read_text())
        return value if isinstance(value, type(default)) else default
    except (OSError, ValueError):
        return default


class ClipboardHistory:
    def __init__(self, directory, clock=time.time):
        self.directory = private_dir(directory)
        self.clock = clock
        self.thumbnails = private_dir(self.directory / 'thumbnails')
        self.path = self.directory / 'history.sqlite'
        fd = os.open(self.path, os.O_CREAT | os.O_RDWR, 0o600)
        os.close(fd)
        self.path.chmod(0o600)
        with self.connect() as db:
            db.execute('CREATE TABLE IF NOT EXISTS clips (id TEXT PRIMARY KEY, mime TEXT NOT NULL, content BLOB NOT NULL, preview TEXT NOT NULL, stamp REAL NOT NULL, pinned INTEGER NOT NULL DEFAULT 0)')
            db.execute('CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value INTEGER NOT NULL)')

    def connect(self):
        db = sqlite3.connect(self.path, timeout=3)
        db.execute('PRAGMA secure_delete=ON')
        return db

    def trim(self, db):
        db.execute('DELETE FROM clips WHERE pinned=0 AND stamp < ?', (self.clock() - RETENTION,))
        rows = db.execute('SELECT id, length(content), pinned FROM clips ORDER BY pinned DESC, stamp DESC').fetchall()
        size = 0
        for index, (ident, length, pinned) in enumerate(rows):
            size += length
            if index >= MAX_ITEMS or size > MAX_TOTAL:
                db.execute('DELETE FROM clips WHERE id=?', (ident,))
        self.prune_thumbnails(db)

    def prune_thumbnails(self, db, clear=False):
        keep = {row[0] + '.png' for row in db.execute('SELECT id FROM clips')}
        for path in self.thumbnails.iterdir():
            # Temporary outputs are bounded and normally removed in finally.
            # Recover leftovers after a crashed decoder, without racing live jobs.
            try:
                if path.is_file() and (clear or (len(path.stem) == 64 and path.name not in keep) or (path.name.startswith('decode-') and time.time() - path.stat().st_mtime > 60)):
                    path.unlink(missing_ok=True)
            except FileNotFoundError:
                pass

    def create_thumbnail(self, ident, content, mime):
        target = self.thumbnails / (ident + '.png')
        if target.is_file():
            return
        temporary = None
        try:
            image_format = IMAGE_FORMATS[mime]
            metadata = subprocess.run(['ffprobe', '-v', 'error', '-max_alloc', '67108864', '-threads', '1', '-f', image_format, '-i', 'pipe:0', '-select_streams', 'v:0', '-show_entries', 'stream=width,height', '-of', 'json'], input=content, capture_output=True, check=True, timeout=2)
            stream = json.loads(metadata.stdout)['streams'][0]
            width, height = int(stream['width']), int(stream['height'])
            if not (0 < width <= 8192 and 0 < height <= 8192 and width * height <= MAX_IMAGE_PIXELS):
                return
            fd, filename = tempfile.mkstemp(prefix='decode-', suffix='.png', dir=self.thumbnails)
            os.close(fd)
            temporary = Path(filename)
            subprocess.run(['ffmpeg', '-v', 'error', '-nostdin', '-y', '-max_alloc', '67108864', '-threads', '1', '-f', image_format, '-i', 'pipe:0', '-frames:v', '1', '-vf', f'scale={THUMBNAIL_EDGE}:{THUMBNAIL_EDGE}:force_original_aspect_ratio=decrease', '-filter_threads', '1', '-threads', '1', str(temporary)], input=content, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True, timeout=4)
            if not (0 < temporary.stat().st_size <= 256 * 1024):
                return
            # Serialize publication against clear/delete/prune. A late decoder
            # must never restore an image after its history entry was removed.
            with self.connect() as db:
                db.execute('BEGIN IMMEDIATE')
                if db.execute('SELECT 1 FROM clips WHERE id=?', (ident,)).fetchone():
                    os.replace(temporary, target)
        except (OSError, ValueError, TypeError, KeyError, IndexError, sqlite3.Error, subprocess.SubprocessError):
            pass  # Damaged/unsupported images remain copyable via their label.
        finally:
            if temporary:
                temporary.unlink(missing_ok=True)

    def store(self, content, mime, sensitive=False):
        if sensitive or not content or len(content) > MAX_ITEM:
            return False
        if mime.startswith('text/'):
            if len(content) > 65536:
                return False
            preview = content.decode('utf-8', errors='replace').replace('\x00', '')[:1500]
        elif mime in ('image/png', 'image/jpeg', 'image/webp', 'image/bmp'):
            preview = f'{mime.split("/")[1].upper()} · {round(len(content) / 1024)} KB'
        else:
            return False
        ident = hashlib.sha256(mime.encode() + b'\0' + content).hexdigest()
        with self.connect() as db:
            if self.paused(db):
                return False
            db.execute('INSERT INTO clips (id,mime,content,preview,stamp) VALUES (?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET stamp=excluded.stamp', (ident, mime, content, preview, self.clock()))
            self.trim(db)
        if mime in IMAGE_FORMATS:
            self.create_thumbnail(ident, content, mime)
        return True

    def paused(self, db):
        row = db.execute("SELECT value FROM settings WHERE key='paused'").fetchone()
        return bool(row and row[0])

    def snapshot(self):
        with self.connect() as db:
            self.trim(db)
            rows = db.execute('SELECT id,mime,preview,stamp,pinned,length(content) FROM clips ORDER BY pinned DESC, stamp DESC').fetchall()
            items = [dict(zip(('id','mime','preview','time','pinned','bytes'), row)) for row in rows]
            for item in items:
                thumbnail = self.thumbnails / (item['id'] + '.png')
                item['thumbnail'] = thumbnail.as_uri() if thumbnail.is_file() else ''
            return {'paused': self.paused(db), 'items': items}

    def handle(self, action, args):
        with self.connect() as db:
            ident = str(args.get('id', ''))
            if action == 'clipboard_pause':
                db.execute("INSERT INTO settings VALUES ('paused',?) ON CONFLICT(key) DO UPDATE SET value=excluded.value", (bool(args.get('value')),))
            elif action == 'clipboard_clear':
                # Explicit clear removes pins too; there is no hidden second history.
                db.execute('DELETE FROM clips')
                self.prune_thumbnails(db, clear=True)
                db.execute('PRAGMA secure_delete=ON')
            elif action == 'clipboard_delete':
                db.execute('PRAGMA secure_delete=ON')
                db.execute('DELETE FROM clips WHERE id=?', (ident,))
                self.prune_thumbnails(db)
            elif action == 'clipboard_pin':
                row = db.execute('SELECT pinned FROM clips WHERE id=?', (ident,)).fetchone()
                if not row:
                    raise ValueError('clipboard_not_found')
                if not row[0] and (db.execute('SELECT count(*) FROM clips WHERE pinned=1').fetchone()[0] >= MAX_PINS or db.execute('SELECT COALESCE(sum(length(content)),0) FROM clips WHERE pinned=1 OR id=?', (ident,)).fetchone()[0] > MAX_TOTAL):
                    raise ValueError('clipboard_pin_limit')
                db.execute('UPDATE clips SET pinned=? WHERE id=?', (not row[0], ident))
            elif action == 'clipboard_copy':
                row = db.execute('SELECT mime,content FROM clips WHERE id=?', (ident,)).fetchone()
                if not row:
                    raise ValueError('clipboard_not_found')
                subprocess.run(['wl-copy', '--type', row[0]], input=row[1], check=True, timeout=3)
            else:
                return False
        return True


def store_selection(mime):
    if os.environ.get('CLIPBOARD_STATE') in ('sensitive', 'clear', 'nil'):
        return
    # This is run only by wl-paste --watch, never by a snapshot/poll operation.
    try:
        types = subprocess.run(['wl-paste', '--list-types'], capture_output=True, timeout=2, check=True).stdout.decode().splitlines()
    except (OSError, subprocess.SubprocessError):
        return
    if any('password' in value.lower() or 'secret' in value.lower() for value in types):
        return
    selected = next((value for value in types if value.startswith('text/')), 'text/plain') if mime == 'text' else next((value for value in types if value in ('image/png','image/jpeg','image/webp','image/bmp')), '')
    if not selected:
        return
    content = sys.stdin.buffer.read(MAX_ITEM + 1)
    directory = Path(os.environ.get('XDG_STATE_HOME', Path.home() / '.local/state')) / 'event-horizon' / 'clipboard'
    ClipboardHistory(directory).store(content, selected)


def output_directory(kind):
    category = 'VIDEOS' if kind == 'recording' else 'PICTURES'
    try:
        result = subprocess.run(['xdg-user-dir', category], capture_output=True, text=True, check=True, timeout=2).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        result = ''
    directory = Path(result) if result and Path(result).is_absolute() else Path.home() / ('Videos' if kind == 'recording' else 'Pictures')
    return private_dir(directory / ('Recordings' if kind == 'recording' else 'Screenshots'))


def geometry(target, child=None):
    if target == 'region':
        process = subprocess.Popen(['slurp'], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
        if child is not None:
            child[0] = process
        try:
            selected, _ = process.communicate(timeout=120)
        except subprocess.TimeoutExpired:
            process.terminate()
            process.communicate()
            return None
        if process.returncode or not selected.strip():
            return None
        return ['-g', selected.strip()]
    if target == 'window':
        value = json.loads(subprocess.run(['hyprctl', '-j', 'activewindow'], capture_output=True, text=True, check=True, timeout=3).stdout)
        x, y = value.get('at', (0, 0))
        w, h = value.get('size', (0, 0))
        if w <= 0 or h <= 0:
            raise ValueError('capture_no_window')
        return ['-g', f'{int(x)},{int(y)} {int(w)}x{int(h)}']
    monitors = json.loads(subprocess.run(['hyprctl', '-j', 'monitors'], capture_output=True, text=True, check=True, timeout=3).stdout)
    monitor = next((item for item in monitors if item.get('focused')), next(iter(monitors), {}))
    if not monitor.get('name'):
        raise ValueError('capture_no_monitor')
    return ['-o', str(monitor['name'])]


def capture_worker(job_path):
    os.umask(0o077)
    job_path = Path(job_path)
    job = read_json(job_path, {})
    state_path = job_path.with_suffix('.status')
    stop_path = job_path.with_suffix('.stop')
    stop = [stop_path.exists()]
    child = [None]
    def request_stop(signum, frame):
        stop[0] = True
        if child[0] and child[0].poll() is None:
            child[0].send_signal(signal.SIGINT)
    signal.signal(signal.SIGUSR1, request_stop)
    signal.signal(signal.SIGTERM, request_stop)
    started = time.time()
    state = {'status': 'preparing', 'kind': job['kind'], 'started': started, 'path': '', 'error': ''}
    atomic_json(state_path, state)
    temporary = None
    output = None
    try:
        deadline = time.monotonic() + job['delay'] + 0.85  # Let the layer surface close first.
        while time.monotonic() < deadline and not stop[0]:
            stop[0] = stop_path.exists()
            time.sleep(0.05)
        if stop[0]:
            state['status'] = 'cancelled'
            return
        bounds = geometry(job['target'], child)
        if bounds is None or stop[0]:
            state['status'] = 'cancelled'
            return
        suffix = '.mp4' if job['kind'] == 'recording' else '.png'
        name = time.strftime('%Y-%m-%d_%H-%M-%S_') + uuid.uuid4().hex[:8] + suffix
        if job['kind'] == 'screenshot' and job['destination'] == 'clipboard':
            fd, filename = tempfile.mkstemp(suffix=suffix, dir=job_path.parent)
            os.close(fd)
            temporary = Path(filename)
            output = temporary
        else:
            output = output_directory(job['kind']) / name
        if job['kind'] == 'recording':
            state.update(status='recording', started=time.time(), path=str(output))
            with tempfile.TemporaryFile() as errors:
                child[0] = subprocess.Popen(['wf-recorder', *bounds, '-r', '30', '-p', 'preset=ultrafast', '-p', 'threads=2', '-f', str(output)], stdout=subprocess.DEVNULL, stderr=errors)
                atomic_json(state_path, state)
                code = child[0].wait()
                if (code != 0 and not stop[0]) or not output.exists() or output.stat().st_size == 0:
                    raise ValueError('capture_failed')
        else:
            subprocess.run(['grim', *bounds, str(output)], check=True, timeout=15, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            if job['destination'] == 'clipboard':
                subprocess.run(['wl-copy', '--type', 'image/png'], input=output.read_bytes(), check=True, timeout=5)
            else:
                state['path'] = str(output)
        state['status'] = 'finished'
    except (OSError, ValueError, TypeError, KeyError, subprocess.SubprocessError):
        state.update(status='failed', error='capture_failed')
    finally:
        if child[0] and child[0].poll() is None:
            child[0].send_signal(signal.SIGINT)
            try:
                child[0].wait(timeout=5)
            except subprocess.TimeoutExpired:
                child[0].kill()
                child[0].wait()
        if temporary:
            temporary.unlink(missing_ok=True)
        atomic_json(state_path, state)
        job_path.unlink(missing_ok=True)
        stop_path.unlink(missing_ok=True)


class DesktopTools:
    def __init__(self, state_dir, runtime_dir=None):
        try:
            self.clipboard = ClipboardHistory(Path(state_dir) / 'clipboard')
        except (OSError, sqlite3.Error):
            self.clipboard = None
        base = runtime_dir or Path(os.environ.get('XDG_RUNTIME_DIR', tempfile.gettempdir())) / f'event-horizon-tools-{os.getuid()}'
        self.runtime_dir = private_dir(base)
        self.worker = None
        self.job = None
        self.last_capture = {'status': 'idle', 'elapsed': 0, 'path': '', 'error': ''}

    def snapshot(self):
        if self.job:
            self.last_capture = read_json(self.job.with_suffix('.status'), self.last_capture)
            if self.worker and self.worker.poll() is not None and self.last_capture.get('status') in ('preparing', 'recording'):
                self.last_capture.update(status='failed', error='capture_failed')
            if self.last_capture.get('status') == 'recording':
                self.last_capture['elapsed'] = max(0, int(time.time() - self.last_capture.get('started', time.time())))
        try:
            clipboard = self.clipboard.snapshot() if self.clipboard else None
        except (OSError, sqlite3.Error):
            clipboard = None
        return {'clipboard': clipboard or {'items': [], 'paused': True, 'error': 'clipboard_unavailable'}, 'capture': self.last_capture}

    def handle(self, action, args):
        if action.startswith('clipboard_'):
            if not self.clipboard:
                raise ValueError('clipboard_unavailable')
            try:
                return self.clipboard.handle(action, args)
            except sqlite3.Error:
                raise ValueError('clipboard_unavailable') from None
            except subprocess.CalledProcessError:
                raise ValueError('clipboard_copy_failed') from None
        if action == 'capture_open_folder':
            path = self.last_capture.get('path', '')
            if path and Path(path).is_file():
                subprocess.Popen(['xdg-open', str(Path(path).parent)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
            return True
        if action == 'capture_stop':
            if self.worker and self.worker.poll() is None:
                self.job.with_suffix('.stop').touch(mode=0o600)
                # The status file is published only after signal handlers exist.
                if self.job.with_suffix('.status').exists():
                    self.worker.send_signal(signal.SIGUSR1)
            return True
        if action != 'capture_start':
            return False
        if self.worker and self.worker.poll() is None:
            raise ValueError('capture_busy')
        kind = args.get('kind', 'screenshot')
        target = args.get('target', 'region')
        destination = args.get('destination', 'file')
        delay = args.get('delay', 0)
        if kind not in ('screenshot','recording') or target not in ('region','window','monitor') or destination not in ('file','clipboard') or delay not in (0,3,5):
            raise ValueError('capture_invalid')
        if kind == 'recording':
            destination = 'file'
        if self.job:
            self.job.with_suffix('.status').unlink(missing_ok=True)
            self.job.with_suffix('.stop').unlink(missing_ok=True)
        self.job = self.runtime_dir / (uuid.uuid4().hex + '.json')
        atomic_json(self.job, {'kind': kind, 'target': target, 'destination': destination, 'delay': delay})
        self.last_capture = {'status': 'preparing', 'elapsed': 0, 'path': '', 'error': ''}
        self.worker = subprocess.Popen([sys.executable, str(Path(__file__).resolve()), '--capture', str(self.job)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        return True

    def close(self):
        if self.worker and self.worker.poll() is None:
            self.worker.terminate()
            try:
                self.worker.wait(timeout=6)
            except subprocess.TimeoutExpired:
                self.worker.kill()
                self.worker.wait()


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--watch', choices=('text','image'))
    parser.add_argument('--capture')
    options = parser.parse_args()
    if options.watch:
        store_selection(options.watch)
    elif options.capture:
        capture_worker(options.capture)
