import copy
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import Mock, patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'ui/runtime'))
from desktop_profiles import DesktopProfiles, DEFAULTS


class ProfilesTests(unittest.TestCase):
    def setUp(self):
        self.directory=tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.path=Path(self.directory.name)/'profiles.json'
        self.profiles=DesktopProfiles(self.path)

    def test_apply_switch_restart_restore_original(self):
        original=dict(dnd=False,volume=42,brightness=None,widgets=dict(clock=True,calendar=True,media=True))
        apply=Mock()
        self.profiles.apply('work',lambda:original,apply)
        self.assertEqual(self.profiles.snapshot()['activeWidgets']['media'],False)
        self.profiles.apply('evening',lambda:DEFAULTS['work'],apply)
        restored=DesktopProfiles(self.path)
        self.assertEqual(restored.active,'evening')
        restored.restore(apply)
        self.assertEqual(apply.call_args.args[0],original)
        self.assertEqual(DesktopProfiles(self.path).active,'')

    def test_failed_external_action_restores_previous_and_does_not_select(self):
        original=dict(DEFAULTS['music'])
        apply=Mock(side_effect=[RuntimeError('device disappeared'),None])
        with self.assertRaises(RuntimeError):self.profiles.apply('work',lambda:original,apply)
        self.assertEqual(apply.call_args.args[0],original)
        self.assertEqual(self.profiles.active,'')

    def test_invalid_save_leaves_disk_untouched(self):
        self.profiles.save('work',DEFAULTS['work'])
        before=self.path.read_bytes()
        for bad in [dict(DEFAULTS['work'],volume=101),dict(DEFAULTS['work'],brightness=True),dict(DEFAULTS['work'],widgets={})]:
            with self.assertRaises(ValueError):self.profiles.save('work',bad)
        self.assertEqual(self.path.read_bytes(),before)

    def test_nullable_controls_and_corrupt_storage(self):
        self.profiles.save('music',dict(DEFAULTS['music'],volume=None,brightness=None))
        self.assertIsNone(DesktopProfiles(self.path).presets['music']['volume'])
        self.path.write_text('{broken')
        self.assertEqual(DesktopProfiles(self.path).presets,DEFAULTS)

    def test_original_device_and_above_nominal_level_survive_restart(self):
        original=dict(DEFAULTS['music'],volume=120,outputName='usb.headset',brightnessDevice='intel_backlight')
        self.profiles.apply('work',lambda:original,Mock())
        restored=DesktopProfiles(self.path)
        self.assertEqual(restored.previous['volume'],120)
        self.assertEqual(restored.previous['outputName'],'usb.headset')

    def test_save_failure_rolls_back_external_changes(self):
        original=dict(DEFAULTS['music'])
        apply=Mock()
        with patch.object(self.profiles,'persist',side_effect=OSError('read only')):
            with self.assertRaises(OSError):self.profiles.apply('work',lambda:original,apply)
        self.assertEqual(self.profiles.active,'')
        self.assertEqual(apply.call_args.args[0],original)
