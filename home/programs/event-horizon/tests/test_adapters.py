import json,sys,tempfile,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'ui/runtime'))
from desktop_state import DesktopState
from desktop_backend import volume,index_apps
class AdapterContractTests(unittest.TestCase):
 def test_native_notification_source_ids_do_not_collapse(self):
  with tempfile.TemporaryDirectory() as d:
   state=DesktopState(Path(d)/'state.json')
   state.notify({'sourceId':7,'session':'a','summary':'one'})
   state.notify({'sourceId':8,'session':'a','summary':'two'})
   state.notify({'sourceId':7,'session':'a','summary':'replacement'})
   self.assertEqual([n['summary'] for n in state.data['notifications']],['two','replacement'])
 def test_pactl_channel_volume_contract(self):
  self.assertEqual(volume({'volume':{'front-left':{'value':32768},'front-right':{'value':65536}}}),75)
 def test_volume_above_nominal_is_not_clamped_in_display(self):
  self.assertEqual(volume({'volume':{'front-left':{'value':78643},'front-right':{'value':78643}}}),120)
 def test_invalid_persisted_timer_recovers_without_data_loss(self):
  with tempfile.TemporaryDirectory() as d:
   path=Path(d)/'state.json';state=DesktopState(path);state.save();value=json.loads(path.read_text());value['timer']={'status':'running'};path.write_text(json.dumps(value))
   state=DesktopState(path);self.assertEqual(state.error,'state_recovered');self.assertEqual(state.timer_snapshot()['status'],'idle');self.assertEqual(len(list(Path(d).glob('*.corrupt-*'))),1)
 def test_async_launcher_reports_exit_failure(self):
  import time,types
  from unittest.mock import patch,Mock
  from desktop_backend import Session
  session=Session.__new__(Session);session.timer_sound=Mock();session.pending=[];session.serial=0;session.error='';session.store=types.SimpleNamespace(timer_tick=lambda:False,prune_notifications=lambda:None)
  session.launch([sys.executable,'-c','import sys;sys.stderr.write("launch failure");sys.exit(23)'])
  with patch('desktop_backend.audio_snapshot',return_value={}),patch('desktop_backend.desktop_snapshot',return_value={}):
   for _ in range(50):
    session.poll()
    if not session.pending:break
    time.sleep(.02)
  self.assertEqual(session.error,'launch failure');self.assertEqual(session.pending,[])

 def test_microphone_switch_preserves_monitor_capture_streams(self):
  from unittest.mock import patch
  from desktop_backend import Session
  session=Session.__new__(Session);session.serial=0
  snapshot={'defaultSource':'mic_old','sources':[{'id':10,'name':'mic_old'},{'id':11,'name':'mic_new'}]}
  streams=[{'index':21,'source':10},{'index':22,'source':99}]
  with patch('desktop_backend.audio_snapshot',return_value=snapshot),patch('desktop_backend.data',return_value=streams),patch('desktop_backend.run') as calls:
   session.execute({'action':'default_device','group':'sources','id':11})
   actual=[call.args[0] for call in calls.call_args_list]
  self.assertIn(['pactl','move-source-output','21','mic_new'],actual)
  self.assertNotIn(['pactl','move-source-output','22','mic_new'],actual)

 def test_command_burst_is_drained_without_more_input(self):
  import os,select,subprocess,time
  runtime=str(Path(__file__).resolve().parents[1]/'ui/runtime')
  script='import desktop_backend as b; b.audio_snapshot=lambda:{}; b.desktop_snapshot=lambda:{}; b.index_apps=lambda:[]; b.index_files=lambda:[]; b.main()'
  with tempfile.TemporaryDirectory() as d:
   env=dict(os.environ,PYTHONPATH=runtime,EVENT_HORIZON_STATE_DIR=d,XDG_RUNTIME_DIR=d)
   process=subprocess.Popen([sys.executable,'-u','-c',script],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,env=env)
   try:
    messages=[{'action':'search','query':'first'},{'action':'search','query':'second'}]
    process.stdin.write(b''.join(json.dumps(m).encode()+b'\n' for m in messages));process.stdin.flush()
    pending=b'';queries=[];deadline=time.monotonic()+5
    while time.monotonic()<deadline and 'second' not in queries:
     if select.select([process.stdout],[],[],.2)[0]:
      pending+=os.read(process.stdout.fileno(),65536)
      while b'\n' in pending:
       line,pending=pending.split(b'\n',1);queries.append(json.loads(line)['query'])
    self.assertIn('first',queries)
    self.assertIn('second',queries)
   finally:
    process.terminate();process.communicate(timeout=5)
