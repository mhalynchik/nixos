import struct
import sys
import tempfile
import unittest
import wave
from pathlib import Path
from unittest.mock import Mock, patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'ui/runtime'))
from desktop_state import DesktopState
from desktop_backend import Session
from timer_sound import MELODIES, TimerSoundPlayer, write_chime


class TimerSoundTests(unittest.TestCase):
    def test_chime_is_finite_non_silent_pcm_without_clipping(self):
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'timer.wav';write_chime(path)
            with wave.open(str(path)) as sound:
                self.assertEqual(sound.getnchannels(),1)
                self.assertAlmostEqual(sound.getnframes()/sound.getframerate(),3.2)
                samples=struct.unpack('<'+'h'*sound.getnframes(),sound.readframes(sound.getnframes()))
                self.assertGreater(max(samples),5000);self.assertLess(max(map(abs,samples)),32767)
                self.assertEqual(samples[0],0);self.assertLess(abs(samples[-1]),5)

    def test_finish_plays_once_even_with_dnd_and_still_emits_notification(self):
        with tempfile.TemporaryDirectory() as directory:
            clock=[100.0]
            session=Session.__new__(Session);session.store=DesktopState(Path(directory)/'state.json',lambda:clock[0])
            session.pending=[];session.serial=0;session.event=None;session.timer_sound=Mock()
            session.store.setting('dnd',True);session.store.timer_start(1)
            with patch('desktop_backend.audio_snapshot',return_value={}),patch('desktop_backend.desktop_snapshot',return_value={}):
                session.poll();session.timer_sound.start.assert_not_called()
                clock[0]+=2;session.poll();session.poll()
                self.assertEqual(session.event,{'kind':'timer_finished'})
                session.timer_sound.start.assert_called_once_with(session.store.data['settings'])


class TimerPlaybackTests(unittest.TestCase):
    def setUp(self):
        self.now = 100
        self.children = []
        def spawn(*args, **kwargs):
            child = Mock()
            child.poll.return_value = None
            self.children.append(child)
            return child
        self.spawn = Mock(side_effect=spawn)
        self.player = TimerSoundPlayer('/sounds', clock=lambda: self.now, spawn=self.spawn)

    def tearDown(self):
        self.player.stop()

    def finish(self):
        self.children[-1].poll.return_value = 0
        self.player.poll()
        self.now += 1
        self.player.poll()

    def test_repeats_are_bounded_and_volume_is_per_stream(self):
        self.player.start({'timerVolume': 75, 'timerMelody': 'signal', 'timerRepeats': 3})
        self.assertIn('--volume=49152', self.spawn.call_args.args[0])
        self.assertEqual(self.spawn.call_args.args[0][-1], '/sounds/timer-signal.wav')
        for _ in range(3):
            self.finish()
        self.assertEqual(self.spawn.call_count, 3)
        self.assertFalse(self.player.active)

    def test_preview_plays_once_and_new_preview_cancels_existing(self):
        self.player.start({'timerRepeats': 5})
        old = self.children[-1]
        self.player.start({'timerRepeats': 5, 'timerMelody': 'orbit'}, preview=True)
        old.terminate.assert_called_once()
        self.assertEqual(self.spawn.call_args.args[0][-1], '/sounds/timer-orbit.wav')
        self.finish()
        self.assertEqual(self.spawn.call_count, 2)
        self.assertFalse(self.player.active)

    def test_zero_volume_is_silent_and_stop_cancels_pending_repeat(self):
        self.player.start({'timerVolume': 0})
        self.spawn.assert_not_called()
        self.player.start({})
        self.children[-1].poll.return_value = 0
        self.player.poll()
        self.player.stop()
        self.now += 10
        self.player.poll()
        self.assertEqual(self.spawn.call_count, 1)
        self.assertFalse(self.player.active)

    def test_failure_does_not_repeat_and_hung_playback_is_bounded(self):
        self.player.start({})
        self.children[-1].poll.return_value = 1
        with self.assertRaises(RuntimeError):
            self.player.poll()
        self.assertFalse(self.player.active)
        self.player.start({})
        self.now += 11
        with self.assertRaisesRegex(RuntimeError, 'timer_sound_timeout'):
            self.player.poll()
        self.children[-1].terminate.assert_called_once()
        self.assertFalse(self.player.active)

    def test_missing_player_does_not_leave_alarm_active(self):
        self.spawn.side_effect = FileNotFoundError('paplay')
        with self.assertRaises(FileNotFoundError):
            self.player.start({})
        self.assertFalse(self.player.active)

    def test_every_melody_has_distinct_finite_non_clipping_audio(self):
        sounds = []
        with tempfile.TemporaryDirectory() as directory:
            for melody in MELODIES:
                path = Path(directory) / (melody + '.wav')
                write_chime(path, melody)
                with wave.open(str(path)) as sound:
                    data = sound.readframes(sound.getnframes())
                    samples = struct.unpack('<' + 'h' * sound.getnframes(), data)
                    self.assertGreater(max(map(abs, samples)), 25000)
                    self.assertLess(max(map(abs, samples)), 30000)
                    self.assertEqual(samples[0], 0)
                    self.assertLess(abs(samples[-1]), 5)
                    sounds.append(data)
        self.assertEqual(len(set(sounds)), len(MELODIES))
