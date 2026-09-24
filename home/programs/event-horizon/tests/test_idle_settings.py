import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'ui/runtime'))
from idle_settings import DEFAULTS, IdleSettings, LOCK_COMMAND, main, render_config, validate
from desktop_backend import Session


class IdleSettingsTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.path = Path(self.directory.name) / 'state/idle.json'

    def test_existing_install_without_preferences_keeps_original_timeouts(self):
        settings = IdleSettings(self.path)
        self.assertEqual(settings.values, DEFAULTS)
        self.assertFalse(self.path.exists())
        self.assertEqual(settings.error, '')

    def test_unversioned_preferences_migrate_without_resetting_choices(self):
        self.path.parent.mkdir()
        self.path.write_text(json.dumps({'screenMinutes': 20}))
        settings = IdleSettings(self.path)
        self.assertEqual(settings.values, dict(DEFAULTS, screenMinutes=20))
        settings.apply(settings.values, restart=Mock())
        self.assertEqual(json.loads(self.path.read_text())['version'], 1)

    def test_successful_apply_persists_across_restart(self):
        settings = IdleSettings(self.path)
        restart = Mock()
        choice = dict(lockMinutes=30, screenMinutes=40, suspendMinutes=0)
        settings.apply(choice, restart=restart)
        restart.assert_called_once_with()
        self.assertEqual(IdleSettings(self.path).values, choice)
        self.assertEqual(self.path.stat().st_mode & 0o777, 0o600)

    def test_invalid_values_never_change_file_or_restart(self):
        settings = IdleSettings(self.path)
        settings.apply(DEFAULTS, restart=Mock())
        original = self.path.read_bytes()
        invalid = [dict(DEFAULTS, lockMinutes=value) for value in (-1, 241, 1.5, True, '5', None)]
        invalid += [{}, dict(DEFAULTS, other=10), dict(DEFAULTS, lockMinutes=16), dict(DEFAULTS, suspendMinutes=9)]
        restart = Mock()
        for values in invalid:
            with self.subTest(values=values), self.assertRaises(ValueError):
                settings.apply(values, restart=restart)
            self.assertEqual(self.path.read_bytes(), original)
        restart.assert_not_called()

    def test_equal_timeouts_and_disabled_actions_are_valid(self):
        for values in (dict(lockMinutes=10, screenMinutes=10, suspendMinutes=10),
                       dict(lockMinutes=0, screenMinutes=1, suspendMinutes=2),
                       dict(lockMinutes=240, screenMinutes=0, suspendMinutes=0)):
            self.assertEqual(validate(values), values)

    def test_failed_apply_restores_persistent_choice_and_daemon(self):
        settings = IdleSettings(self.path)
        settings.apply(DEFAULTS, restart=Mock())
        original = self.path.read_bytes()
        restart = Mock(side_effect=[RuntimeError('service failed'), None])
        with self.assertRaisesRegex(RuntimeError, 'сохранён прежний выбор'):
            settings.apply(dict(lockMinutes=0, screenMinutes=0, suspendMinutes=0), restart=restart)
        self.assertEqual(restart.call_count, 2)
        self.assertEqual(self.path.read_bytes(), original)
        self.assertEqual(settings.values, DEFAULTS)

    def test_failed_first_apply_does_not_leave_new_preferences(self):
        settings = IdleSettings(self.path)
        with self.assertRaises(RuntimeError):
            settings.apply(DEFAULTS, restart=Mock(side_effect=[subprocess.TimeoutExpired('systemctl', 15), None]))
        self.assertFalse(self.path.exists())

    def test_failed_recovery_reports_daemon_problem(self):
        settings = IdleSettings(self.path)
        with self.assertRaisesRegex(RuntimeError, 'Hypridle не удалось восстановить'):
            settings.apply(DEFAULTS, restart=Mock(side_effect=RuntimeError('failed')))

    def test_bad_state_uses_defaults_without_overwriting_file(self):
        self.path.parent.mkdir()
        for data in ('invalid JSON', '[]', '{"version":2}', '{"version":1,"lockMinutes":0}'):
            self.path.write_text(data)
            settings = IdleSettings(self.path)
            self.assertEqual(settings.values, DEFAULTS)
            self.assertTrue(settings.error)
            self.assertEqual(self.path.read_text(), data)

    def test_render_preserves_dimming_and_manual_lock_with_all_timeouts_disabled(self):
        base = 'general {\n    lock_cmd = ' + LOCK_COMMAND + '\n    before_sleep_cmd = ' + LOCK_COMMAND + '\n}\nlistener {\n    timeout = 300\n    on-timeout = brightnessctl -s set 30\n    on-resume = brightnessctl -r\n}\n'
        config = render_config(base, dict.fromkeys(DEFAULTS, 0))
        self.assertEqual(config.count('listener {'), 1)
        self.assertIn(base.rstrip(), config)
        self.assertNotIn('systemctl suspend', config)

    def test_render_applies_selected_minutes_once(self):
        config = render_config('general {}', dict(lockMinutes=20, screenMinutes=25, suspendMinutes=40))
        self.assertIn('timeout = 1200', config)
        self.assertIn('timeout = 1500', config)
        self.assertIn('timeout = 2400', config)
        self.assertEqual(config.count('listener {'), 3)
        self.assertIn('on-resume = hyprctl dispatch dpms on', config)

    def test_launcher_execs_hypridle_with_generated_config(self):
        base = Path(self.directory.name) / 'base.conf'
        base.write_text('general {}')
        runtime = Path(self.directory.name) / 'runtime'
        env = dict(EVENT_HORIZON_STATE_DIR=str(self.path.parent), XDG_RUNTIME_DIR=str(runtime))
        with patch.dict(os.environ, env), patch.object(sys, 'argv', ['idle', '--hypridle', '/test/hypridle', '--base', str(base)]), patch('idle_settings.os.execv') as execute:
            main()
        generated = runtime / 'event-horizon/hypridle.conf'
        self.assertIn('timeout = 600', generated.read_text())
        execute.assert_called_once_with('/test/hypridle', ['/test/hypridle', '--config', str(generated)])

    def test_backend_passes_complete_values_to_idle_domain(self):
        session = Session.__new__(Session)
        session.idle = Mock()
        session.serial = 0
        session.execute(dict(action='idle_settings', **DEFAULTS))
        session.idle.apply.assert_called_once_with(DEFAULTS)


if __name__ == '__main__':
    unittest.main()
