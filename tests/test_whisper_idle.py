import importlib.util
from pathlib import Path
import sys
import tempfile
import time
import unittest

spec=importlib.util.spec_from_file_location('whisper_idle',Path(__file__).resolve().parents[1]/'modules/system/whisper-idle.py')
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)


class WhisperIdleTests(unittest.TestCase):
    def test_lazy_load_reuse_idle_release_and_reload(self):
        with tempfile.TemporaryDirectory() as directory:
            worker=Path(directory)/'worker.py'
            worker.write_text('import sys,json,os\nfor line in sys.stdin:\n request=json.loads(line);print(json.dumps({"text":str(os.getpid())+":"+request["language"]}),flush=True)\n')
            pool=module.IdleWorker([sys.executable,str(worker)],idle_seconds=.1)
            try:
                self.assertIsNone(pool.process)
                first=pool.transcribe('/unused','ru')
                self.assertEqual(first,pool.transcribe('/unused','ru'))
                old=pool.process
                deadline=time.monotonic()+3
                while pool.process is not None and time.monotonic()<deadline:time.sleep(.05)
                self.assertIsNone(pool.process);self.assertIsNotNone(old.poll())
                self.assertNotEqual(first,pool.transcribe('/unused','ru'))
            finally:pool.close()

    def test_worker_failure_releases_process(self):
        pool=module.IdleWorker([sys.executable,'-c','import sys;sys.exit(2)'])
        try:
            with self.assertRaises(ValueError):pool.transcribe('/unused','en')
            self.assertIsNone(pool.process)
        finally:pool.close()

    def test_timeout_releases_process(self):
        pool=module.IdleWorker([sys.executable,'-c','import time;time.sleep(10)'],request_timeout=.1)
        try:
            with self.assertRaises(TimeoutError):pool.transcribe('/unused','en')
            self.assertIsNone(pool.process)
        finally:pool.close()
