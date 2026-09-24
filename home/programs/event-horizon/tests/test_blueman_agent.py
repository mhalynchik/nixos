"""Authorization lease behavior; Blueman's plugin-list uses !Name to disable."""
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'ui/runtime'))
from blueman_agent import DconfPlugins, KEY, reserve, restore


class Plugins:
    def __init__(self, value): self.value = value
    def read(self): return None if self.value is None else list(self.value)
    def write(self, value): self.value = value


class BluemanAuthorizationTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.path = Path(self.directory.name) / 'lease.json'

    def test_reserves_only_agent_and_restores_prior_enabled_state(self):
        settings = Plugins(['!ConnectionNotifier', 'AuthAgent', 'Other'])
        reserve(self.path, settings)
        self.assertEqual(settings.value, ['!ConnectionNotifier', 'Other', '!AuthAgent'])
        restore(self.path, settings)
        self.assertEqual(settings.value, ['!ConnectionNotifier', 'Other', 'AuthAgent'])
        self.assertFalse(self.path.exists())

    def test_other_preferences_changed_while_running_are_kept(self):
        settings = Plugins(['!ConnectionNotifier'])
        reserve(self.path, settings)
        settings.value = ['ConnectionNotifier', 'NewPlugin', '!AuthAgent']
        restore(self.path, settings)
        self.assertEqual(settings.value, ['ConnectionNotifier', 'NewPlugin'])

    def test_repeat_reserve_after_crash_keeps_original_preference(self):
        settings = Plugins(['AuthAgent'])
        reserve(self.path, settings)
        reserve(self.path, settings)
        self.assertEqual(json.loads(self.path.read_text())['agent'], ['AuthAgent'])
        restore(self.path, settings)
        self.assertEqual(settings.value, ['AuthAgent'])

    def test_preexisting_disabled_agent_stays_disabled(self):
        settings = Plugins(['!AuthAgent'])
        reserve(self.path, settings)
        restore(self.path, settings)
        self.assertEqual(settings.value, ['!AuthAgent'])

    def test_unset_and_explicit_empty_are_distinct_after_restore(self):
        for initial in [None, []]:
            with self.subTest(initial=initial):
                settings = Plugins(initial)
                reserve(self.path, settings)
                restore(self.path, settings)
                self.assertEqual(settings.value, initial)

    def test_new_preferences_do_not_get_reset_when_original_was_unset(self):
        settings = Plugins(None)
        reserve(self.path, settings)
        settings.value.append('!ConnectionNotifier')
        restore(self.path, settings)
        self.assertEqual(settings.value, ['!ConnectionNotifier'])

    def test_explicit_user_agent_change_is_not_overwritten_on_stop(self):
        settings = Plugins([])
        reserve(self.path, settings)
        settings.value = ['AuthAgent']
        restore(self.path, settings)
        self.assertEqual(settings.value, ['AuthAgent'])

    def test_failed_write_keeps_recovery_journal(self):
        settings = Plugins(['AuthAgent'])
        with patch.object(settings, 'write', side_effect=RuntimeError('unavailable')):
            with self.assertRaises(RuntimeError): reserve(self.path, settings)
        self.assertTrue(self.path.exists())
        restore(self.path, settings)
        self.assertEqual(settings.value, ['AuthAgent'])

    def test_restore_failure_can_be_retried(self):
        settings = Plugins([])
        reserve(self.path, settings)
        with patch.object(settings, 'write', side_effect=RuntimeError('unavailable')):
            with self.assertRaises(RuntimeError): restore(self.path, settings)
        self.assertTrue(self.path.exists())
        restore(self.path, settings)
        self.assertEqual(settings.value, [])

    def test_dconf_read_write_contract(self):
        settings = DconfPlugins()
        for raw, expected in [('', None), ('@as []', []), ("['!ConnectionNotifier']", ['!ConnectionNotifier'])]:
            with patch('blueman_agent.subprocess.run', return_value=Mock(stdout=raw)) as run:
                self.assertEqual(settings.read(), expected)
                self.assertEqual(run.call_args.args[0], ['dconf', 'read', KEY])
        for value, tail in [(None, ['reset', KEY]), ([], ['write', KEY, '@as []']), (['!AuthAgent'], ['write', KEY, "['!AuthAgent']"])]:
            with patch('blueman_agent.subprocess.run') as run:
                settings.write(value)
                self.assertEqual(run.call_args.args[0], ['dconf'] + tail)


if __name__ == '__main__':
    unittest.main()
