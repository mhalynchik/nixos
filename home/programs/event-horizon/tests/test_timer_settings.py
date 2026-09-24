import json
from pathlib import Path
import sys
import tempfile
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'ui/runtime'))
from desktop_state import DesktopState
from timer_sound import SOUND_DEFAULTS


class TimerSettingsTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.path = Path(self.directory.name) / 'state.json'
        self.state = DesktopState(self.path)

    def test_preferences_persist(self):
        for key, value in {'timerVolume': 100, 'timerMelody': 'orbit', 'timerRepeats': 5}.items():
            self.state.setting(key, value)
            self.assertEqual(DesktopState(self.path).data['settings'][key], value)

    def test_invalid_values_are_rejected(self):
        invalid = {'timerVolume': [-1, 101, 75.5, '80', True, None, float('nan')],
                   'timerMelody': ['missing', '../escape', 1, None, []],
                   'timerRepeats': [0, 2, 100000, True, '3', None]}
        for key, values in invalid.items():
            for value in values:
                with self.subTest(key=key, value=value), self.assertRaises(ValueError):
                    self.state.setting(key, value)
        self.assertEqual({key: self.state.data['settings'][key] for key in SOUND_DEFAULTS}, SOUND_DEFAULTS)

    def test_legacy_settings_gain_defaults_without_losing_data(self):
        task = self.state.add_task('2026-09-24', 'Keep agenda')
        data = json.loads(self.path.read_text())
        for key in SOUND_DEFAULTS:
            del data['settings'][key]
        self.path.write_text(json.dumps(data))
        loaded = DesktopState(self.path)
        self.assertEqual(loaded.data['agenda'], [task])
        self.assertFalse(loaded.error)
        for key, value in SOUND_DEFAULTS.items():
            self.assertEqual(loaded.data['settings'][key], value)

    def test_corrupt_sound_preferences_are_repaired_without_resetting_timer(self):
        self.state.timer_start(120)
        data = json.loads(self.path.read_text())
        data['settings'].update(timerVolume='loud', timerMelody=[], timerRepeats=-50)
        self.path.write_text(json.dumps(data))
        loaded = DesktopState(self.path)
        self.assertEqual(loaded.data['timer'], self.state.data['timer'])
        self.assertFalse(loaded.error)
        self.assertFalse(list(self.path.parent.glob('*.corrupt-*')))
        for key, value in SOUND_DEFAULTS.items():
            self.assertEqual(loaded.data['settings'][key], value)
