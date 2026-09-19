import sys
import unittest
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).resolve().parents[1]/'ui/runtime'))
from desktop_backend import audio_rows, Session


class AudioTests(unittest.TestCase):
    def test_broken_device_description_uses_pipewire_nickname(self):
        rows=audio_rows([{'index':1,'description':'(null)','name':'alsa.card',
            'properties':{'node.nick':'Audeze Maxwell'}}], 'sinks')
        self.assertEqual(rows[0]['label'], 'Audeze Maxwell')

    def test_unicode_description_is_preserved(self):
        self.assertEqual(audio_rows([{'index':1,'description':'Встроенное аудио'}], 'sinks')[0]['label'], 'Встроенное аудио')

    def test_floorp_streams_group_by_real_binary_and_process(self):
        def stream(index, binary, pid):
            return {'index':index,'properties':{'application.name':'Firefox','application.process.binary':binary,'application.process.id':pid}}
        rows=audio_rows([stream(1,'floorp','10'),stream(2,'floorp','10'),stream(3,'firefox','11')], 'sink-inputs')
        self.assertEqual([(x['label'],x['ids']) for x in rows], [('Floorp',[1,2]),('Firefox',[3])])

    def test_application_volume_updates_all_current_streams(self):
        session=Session.__new__(Session);session.serial=0
        with patch('desktop_backend.audio_snapshot',return_value={'streams':[{'id':1,'ids':[1,2],'mute':False}]}),patch('desktop_backend.run') as run:
            session.execute({'action':'volume','group':'streams','id':1,'value':35})
        self.assertEqual([x.args[0] for x in run.call_args_list],[['pactl','set-sink-input-volume','1','35%'],['pactl','set-sink-input-volume','2','35%']])

    def test_monitor_is_not_offered_as_microphone(self):
        self.assertEqual(audio_rows([{'index':1,'name':'output.monitor','monitor_of_sink':3}], 'sources'),[])
