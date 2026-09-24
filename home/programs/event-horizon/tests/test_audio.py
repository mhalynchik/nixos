import sys
import json
import unittest
from pathlib import Path
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).resolve().parents[1]/'ui/runtime'))
from desktop_backend import audio_rows, audio_snapshot, Session


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

    def test_monitor_default_uses_real_microphone_and_its_mute_state(self):
        sources=[{'index':1,'name':'output.monitor','monitor_of_sink':3,'mute':False},
                 {'index':2,'name':'input.usb','monitor_of_sink':4294967295,'mute':True}]
        with patch('desktop_backend.run',side_effect=['output','output.monitor','[]',json.dumps(sources),'[]']):
            result=audio_snapshot()
        self.assertEqual(result['defaultSource'],'input.usb')
        self.assertTrue(result['sources'][0]['mute'])

    def test_explicit_real_default_is_preserved(self):
        sources=[{'index':1,'name':'input.internal'},{'index':2,'name':'input.usb'}]
        with patch('desktop_backend.run',side_effect=['output','input.usb','[]',json.dumps(sources),'[]']):
            self.assertEqual(audio_snapshot()['defaultSource'],'input.usb')

    def test_disconnected_default_jack_falls_back_to_connected_headset(self):
        sources=[{'index':1,'name':'input.analog','active_port':'front',
                  'ports':[{'name':'front','availability':'not available'}]},
                 {'index':2,'name':'input.usb','active_port':'mic',
                  'ports':[{'name':'mic','availability':'unknown'}]}]
        with patch('desktop_backend.run',side_effect=['output','input.analog','[]',json.dumps(sources),'[]']):
            result=audio_snapshot()
        self.assertEqual(result['defaultSource'],'input.usb')
        self.assertFalse(result['sources'][0]['available'])
        self.assertTrue(result['sources'][1]['available'])

    def test_disconnected_jack_is_not_an_available_microphone(self):
        sources=[{'index':1,'name':'input.analog','mute':False,'active_port':'front',
                  'ports':[{'name':'front','availability':'not available'}]}]
        with patch('desktop_backend.run',side_effect=['output','output.monitor','[]',json.dumps(sources),'[]']):
            result=audio_snapshot()
        self.assertEqual(result['defaultSource'],'')
        self.assertFalse(result['sources'][0]['available'])

    def test_only_active_port_availability_matters(self):
        row=audio_rows([{'index':1,'active_port':'rear','ports':[
            {'name':'front','availability':'not available'},
            {'name':'rear','availability':'available'}]}], 'sources')[0]
        self.assertTrue(row['available'])

    def test_unknown_or_missing_port_state_is_not_a_disconnected_device(self):
        for ports in [[],[{'name':'mic','availability':'unknown'}],[{'name':'mic'}]]:
            with self.subTest(ports=ports):
                self.assertTrue(audio_rows([{'index':1,'active_port':'mic','ports':ports}], 'sources')[0]['available'])

    def test_mute_targets_resolved_microphone(self):
        session=Session.__new__(Session);session.serial=0
        state={'defaultSource':'input.usb','sources':[{'id':2,'name':'input.usb','mute':False}]}
        with patch('desktop_backend.audio_snapshot',return_value=state),patch('desktop_backend.run') as run:
            session.execute({'action':'mic_mute'})
        run.assert_called_once_with(['pactl','set-source-mute','input.usb','toggle'])

    def test_no_microphone_never_mutes_output_monitor(self):
        session=Session.__new__(Session);session.serial=0
        with patch('desktop_backend.audio_snapshot',return_value={'defaultSource':'','sources':[]}),patch('desktop_backend.run') as run:
            with self.assertRaisesRegex(ValueError,'device_disappeared'):
                session.execute({'action':'mic_mute'})
        run.assert_not_called()
