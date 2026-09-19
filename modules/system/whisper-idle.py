"""Lazy subprocess with bounded idle lifetime and serialized model access."""
import json
import select
import subprocess
import threading
import time


class IdleWorker:
    def __init__(self, command, idle_seconds=300, request_timeout=600):
        self.command = command
        self.idle_seconds = idle_seconds
        self.request_timeout = request_timeout
        self.process = None
        self.lock = threading.Lock()
        self.last_used = 0
        self.closed = threading.Event()
        self.reaper = threading.Thread(target=self._reap, daemon=True)
        self.reaper.start()

    def _stop(self):
        process, self.process = self.process, None
        if process is None:
            return
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
        process.stdin.close()
        process.stdout.close()

    def _reap(self):
        while not self.closed.wait(min(10, self.idle_seconds)):
            if self.lock.acquire(blocking=False):
                try:
                    if self.process and time.monotonic() - self.last_used >= self.idle_seconds:
                        self._stop()
                finally:
                    self.lock.release()

    def transcribe(self, path, language):
        with self.lock:
            if self.closed.is_set():
                raise RuntimeError('Transcription server is shutting down')
            if self.process is None or self.process.poll() is not None:
                self._stop()
                self.process = subprocess.Popen(self.command, stdin=subprocess.PIPE,
                    stdout=subprocess.PIPE, text=True, bufsize=1)
            try:
                self.process.stdin.write(json.dumps({'path': path, 'language': language}) + '\n')
                self.process.stdin.flush()
                if not select.select([self.process.stdout], [], [], self.request_timeout)[0]:
                    raise TimeoutError('Transcription timed out')
                response = json.loads(self.process.stdout.readline())
                if 'error' in response:
                    raise RuntimeError(response['error'])
                return response['text']
            except Exception:
                self._stop()
                raise
            finally:
                self.last_used = time.monotonic()

    def close(self):
        self.closed.set()
        with self.lock:
            self._stop()
