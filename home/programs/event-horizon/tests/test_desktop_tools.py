"""No tests read the live clipboard or capture the host desktop."""
import importlib.util
import json
from pathlib import Path
import stat
import subprocess
import tempfile
import unittest
from unittest.mock import Mock, patch

SPEC = importlib.util.spec_from_file_location('desktop_tools', Path(__file__).parents[1] / 'ui/runtime/desktop_tools.py')
tools = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(tools)


class ClipboardTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.now = 1000000
        self.history = tools.ClipboardHistory(Path(self.tmp.name) / 'clips', clock=lambda: self.now)

    def tearDown(self):
        self.tmp.cleanup()

    def test_sensitive_and_large_values_are_never_stored(self):
        self.assertFalse(self.history.store(b'password', 'text/plain', sensitive=True))
        self.assertFalse(self.history.store(b'a' * 65537, 'text/plain'))
        self.assertFalse(self.history.store(b'archive', 'application/octet-stream'))
        self.assertEqual(self.history.snapshot()['items'], [])

    def test_pause_deduplication_and_copy_use_exact_bytes(self):
        value = 'Привет\n\t$(echo nope)'.encode()
        self.history.store(value, 'text/plain')
        self.history.store(value, 'text/plain')
        items = self.history.snapshot()['items']
        self.assertEqual(len(items), 1)
        with patch.object(tools.subprocess, 'run') as run:
            self.history.handle('clipboard_copy', {'id': items[0]['id']})
            run.assert_called_once_with(['wl-copy','--type','text/plain'], input=value, check=True, timeout=3)
        self.history.handle('clipboard_pause', {'value': True})
        self.assertFalse(self.history.store(b'new', 'text/plain'))
        self.assertTrue(self.history.snapshot()['paused'])

    def test_images_preserve_mime_and_pins_survive_retention(self):
        self.history.store(b'png-data', 'image/png')
        ident = self.history.snapshot()['items'][0]['id']
        self.history.handle('clipboard_pin', {'id': ident})
        self.history.store(b'old text', 'text/plain')
        self.now += tools.RETENTION + 1
        items = self.history.snapshot()['items']
        self.assertEqual([row['id'] for row in items], [ident])
        self.assertEqual(items[0]['mime'], 'image/png')
        self.history.handle('clipboard_clear', {})
        self.assertEqual(self.history.snapshot()['items'], [])

    def test_storage_is_bounded_and_private(self):
        for index in range(tools.MAX_ITEMS + 10):
            self.now += 1
            self.history.store(str(index).encode(), 'text/plain')
        self.assertEqual(len(self.history.snapshot()['items']), tools.MAX_ITEMS)
        self.assertEqual(stat.S_IMODE(self.history.path.stat().st_mode), 0o600)
        self.assertEqual(stat.S_IMODE(self.history.directory.stat().st_mode), 0o700)

    def test_pin_limit_and_missing_selection(self):
        for index in range(tools.MAX_PINS + 1):
            self.now += 1
            self.history.store(str(index).encode(), 'text/plain')
        items = self.history.snapshot()['items']
        for item in items[:tools.MAX_PINS]:
            self.history.handle('clipboard_pin', {'id': item['id']})
        with self.assertRaisesRegex(ValueError, 'clipboard_pin_limit'):
            self.history.handle('clipboard_pin', {'id': items[-1]['id']})
        with self.assertRaisesRegex(ValueError, 'clipboard_not_found'):
            self.history.handle('clipboard_copy', {'id': 'not-present'})

    def thumbnail_decoder(self, command, **kwargs):
        if command[0] == 'ffprobe':
            return Mock(stdout=b'{"streams":[{"width":640,"height":480}]}')
        self.assertEqual(command[0], 'ffmpeg')
        self.assertEqual(command[command.index('-threads') + 1], '1')
        self.assertEqual(kwargs['timeout'], 4)
        Path(command[-1]).write_bytes(b'bounded-png-thumbnail')
        return Mock(returncode=0)

    def test_thumbnail_creation_and_all_removal_paths(self):
        for action in ('clipboard_delete', 'clipboard_clear', 'expire'):
            with patch.object(tools.subprocess, 'run', side_effect=self.thumbnail_decoder):
                self.history.store(action.encode(), 'image/png')
            item = self.history.snapshot()['items'][0]
            self.assertTrue(item['thumbnail'].startswith('file://'))
            cache = self.history.thumbnails / (item['id'] + '.png')
            self.assertTrue(cache.is_file())
            self.assertEqual(stat.S_IMODE(cache.stat().st_mode), 0o600)
            if action == 'expire':
                self.now += tools.RETENTION + 1
                self.history.snapshot()
            else:
                self.history.handle(action, {'id':item['id']})
            self.assertFalse(cache.exists())
        self.assertEqual(list(self.history.thumbnails.iterdir()), [])

    def test_invalid_or_oversized_image_has_label_without_decode(self):
        with patch.object(tools.subprocess, 'run', return_value=Mock(stdout=b'{"streams":[{"width":90000,"height":90000}]}')) as run:
            self.history.store(b'oversized', 'image/png')
            self.assertEqual(run.call_count, 1)
        self.assertEqual(self.history.snapshot()['items'][0]['thumbnail'], '')
        with patch.object(tools.subprocess, 'run', side_effect=subprocess.TimeoutExpired('ffprobe', 2)):
            self.history.store(b'broken', 'image/png')
        self.assertTrue(all(not item['thumbnail'] for item in self.history.snapshot()['items']))
        self.assertEqual(list(self.history.thumbnails.iterdir()), [])

    def test_clear_during_decode_never_recreates_thumbnail(self):
        def decode(command, **kwargs):
            result = self.thumbnail_decoder(command, **kwargs)
            if command[0] == 'ffmpeg':
                self.history.handle('clipboard_clear', {})
                # Simulate a decoder that recreates its temporary output after clear.
                Path(command[-1]).write_bytes(b'late-output')
            return result
        with patch.object(tools.subprocess, 'run', side_effect=decode):
            self.history.store(b'racing', 'image/png')
        self.assertEqual(self.history.snapshot()['items'], [])
        self.assertEqual(list(self.history.thumbnails.iterdir()), [])

    def test_sensitive_watch_hint_does_not_read_selection(self):
        with patch.dict(tools.os.environ, {'CLIPBOARD_STATE': 'sensitive'}), patch.object(tools.subprocess, 'run') as run:
            tools.store_selection('text')
            run.assert_not_called()
        with patch.dict(tools.os.environ, {'CLIPBOARD_STATE': 'data'}), patch.object(tools.subprocess, 'run', return_value=Mock(stdout=b'text/plain\nx-kde-passwordManagerHint')):
            with patch.object(tools, 'ClipboardHistory') as history:
                tools.store_selection('text')
                history.assert_not_called()


class CaptureTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.instance = tools.DesktopTools(Path(self.tmp.name) / 'state', Path(self.tmp.name) / 'runtime')

    def tearDown(self):
        self.tmp.cleanup()

    def test_unavailable_history_does_not_break_other_tools(self):
        with patch.object(self.instance.clipboard, 'snapshot', side_effect=tools.sqlite3.DatabaseError('broken')):
            state = self.instance.snapshot()
            self.assertEqual(state['clipboard']['error'], 'clipboard_unavailable')
            self.assertEqual(state['capture']['status'], 'idle')
        with patch.object(self.instance.clipboard, 'handle', side_effect=subprocess.CalledProcessError(1, 'wl-copy')):
            with self.assertRaisesRegex(ValueError, 'clipboard_copy_failed'):
                self.instance.handle('clipboard_copy', {'id':'missing'})

    def test_validation_and_launch_are_nonblocking(self):
        with self.assertRaisesRegex(ValueError, 'capture_invalid'):
            self.instance.handle('capture_start', {'target': '; touch /tmp/no'})
        with patch.object(tools.subprocess, 'Popen') as popen:
            popen.return_value.poll.return_value = None
            self.instance.handle('capture_start', {'kind':'recording','target':'monitor','destination':'clipboard','delay':3})
            job = json.loads(self.instance.job.read_text())
            self.assertEqual(job['destination'], 'file')
            self.assertEqual(self.instance.snapshot()['capture']['status'], 'preparing')
            with self.assertRaisesRegex(ValueError, 'capture_busy'):
                self.instance.handle('capture_start', {})
            self.instance.handle('capture_stop', {})
            self.assertTrue(self.instance.job.with_suffix('.stop').exists())
            popen.return_value.send_signal.assert_not_called()
            tools.atomic_json(self.instance.job.with_suffix('.status'), {'status':'preparing'})
            self.instance.handle('capture_stop', {})
            popen.return_value.send_signal.assert_called_once_with(tools.signal.SIGUSR1)

    def test_window_and_monitor_geometry(self):
        with patch.object(tools.subprocess, 'run', return_value=Mock(stdout=json.dumps({'at':[-1920,50],'size':[800,600]}))):
            self.assertEqual(tools.geometry('window'), ['-g', '-1920,50 800x600'])
        with patch.object(tools.subprocess, 'run', return_value=Mock(stdout=json.dumps([{'name':'DP-1','focused':False},{'name':'HDMI-A-1','focused':True}]))):
            self.assertEqual(tools.geometry('monitor'), ['-o', 'HDMI-A-1'])
        with patch.object(tools.subprocess, 'run', return_value=Mock(stdout='{}')):
            with self.assertRaisesRegex(ValueError, 'capture_no_window'):
                tools.geometry('window')

    def test_region_cancel_is_not_a_capture(self):
        with patch.object(tools.subprocess, 'Popen') as popen:
            popen.return_value.communicate.return_value = ('', '')
            popen.return_value.returncode = 1
            self.assertIsNone(tools.geometry('region'))

    def test_worker_failure_detected_and_shutdown_stops_recording(self):
        self.instance.job = self.instance.runtime_dir / 'example.json'
        self.instance.last_capture = {'status':'recording'}
        self.instance.worker = Mock()
        self.instance.worker.poll.return_value = 1
        self.assertEqual(self.instance.snapshot()['capture']['status'], 'failed')
        self.instance.worker.poll.return_value = None
        self.instance.close()
        self.instance.worker.terminate.assert_called_once()
        self.instance.worker.wait.assert_called_once_with(timeout=6)

    def test_capture_cancelled_before_geometry_has_no_output(self):
        job = self.instance.runtime_dir / 'cancel.json'
        tools.atomic_json(job, {'kind':'screenshot','target':'region','destination':'file','delay':0})
        with patch.object(tools.signal, 'signal'), patch.object(tools.os, 'umask'), patch.object(tools, 'geometry', return_value=None), patch.object(tools, 'output_directory') as output, patch.object(tools.time, 'sleep'), patch.object(tools.time, 'monotonic', side_effect=[0,1]):
            tools.capture_worker(job)
        output.assert_not_called()
        self.assertEqual(tools.read_json(job.with_suffix('.status'), {})['status'], 'cancelled')
        self.assertFalse(job.exists())


if __name__ == '__main__':
    unittest.main()
