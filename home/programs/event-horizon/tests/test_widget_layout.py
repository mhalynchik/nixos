import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'ui/runtime'))
from widget_layout import DEFAULTS, WidgetLayouts, profile_key, validate


class WidgetLayoutTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.path = Path(self.directory.name) / 'layouts.json'
        self.store = WidgetLayouts(self.path)

    def test_profile_selection_per_monitor_and_wallpaper(self):
        base = self.store.resolve('DP-1')
        base['media']['visible'] = False
        self.store.save('DP-1', '', base)
        exact = self.store.resolve('DP-1', '/sky.png')
        exact['clock']['x'] = .4
        self.store.save('DP-1', '/sky.png', exact)
        self.assertEqual(self.store.resolve('DP-1', '/sky.png'), exact)
        self.assertEqual(self.store.resolve('DP-1', '/other.png'), base)
        self.assertEqual(self.store.resolve('DP-2', '/sky.png'), DEFAULTS)
        self.assertEqual(WidgetLayouts(self.path).resolve('DP-1', '/sky.png'), exact)
        self.store.reset('DP-1', '/sky.png')
        self.assertEqual(self.store.resolve('DP-1', '/sky.png'), base)

    def test_cancel_cannot_mutate_persisted_values(self):
        draft = self.store.resolve('DP-1')
        draft['clock']['visible'] = False
        self.assertTrue(self.store.resolve('DP-1')['clock']['visible'])
        self.assertFalse(self.path.exists())

    def test_invalid_numeric_values_rejected(self):
        for field, value in [('x', float('nan')), ('y', float('inf')), ('scale', True), ('scale', 0), ('x', -1), ('visible', 1)]:
            with self.subTest(field=field, value=value):
                draft = self.store.resolve('DP-1')
                draft['clock'][field] = value
                with self.assertRaises(ValueError):
                    self.store.save('DP-1', '', draft)
                self.assertEqual(self.store.profiles, {})

    def test_atomic_failure_preserves_memory(self):
        self.store.save('DP-1', '', DEFAULTS)
        before = self.store.snapshot()
        with patch('widget_layout.atomic_write', side_effect=OSError('disk full')):
            with self.assertRaises(OSError):
                self.store.reset('DP-1', '')
        self.assertEqual(self.store.snapshot(), before)

    def test_corrupt_or_unknown_version_falls_back(self):
        for text in ['{', '{"version":2,"profiles":{}}', '{"version":1,"profiles":{"[]":{}}}']:
            self.path.write_text(text)
            loaded = WidgetLayouts(self.path)
            self.assertTrue(loaded.error)
            self.assertEqual(loaded.resolve('DP-1'), DEFAULTS)

    def test_snapshot_and_unicode_key(self):
        self.store.save('DP-1', '/Обои/небо.png', DEFAULTS)
        key = profile_key('DP-1', '/Обои/небо.png')
        self.assertEqual(json.loads(key), ['DP-1', '/Обои/небо.png'])
        snapshot = self.store.snapshot('/Обои/небо.png')
        snapshot['profiles'][key]['clock']['x'] = .9
        self.assertEqual(self.store.resolve('DP-1', '/Обои/небо.png'), DEFAULTS)


if __name__ == '__main__':
    unittest.main()
