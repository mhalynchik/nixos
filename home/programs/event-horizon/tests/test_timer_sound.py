import struct
import sys
import tempfile
import unittest
import wave
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'ui/runtime'))
from desktop_state import DesktopState
from desktop_backend import Session
from timer_sound import write_chime


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
            session.pending=[];session.serial=0;session.event=None
            session.store.setting('dnd',True);session.store.timer_start(1)
            with patch('desktop_backend.audio_snapshot',return_value={}),patch('desktop_backend.desktop_snapshot',return_value={}),patch.object(session,'launch') as launch:
                session.poll();launch.assert_not_called()
                clock[0]+=2;session.poll();session.poll()
                self.assertEqual(session.event,{'kind':'timer_finished'})
                launch.assert_called_once();self.assertEqual(launch.call_args.args[0][0],'paplay')
