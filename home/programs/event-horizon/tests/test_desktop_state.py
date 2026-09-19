import unittest,tempfile,sys,json
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parents[1]/'ui/runtime'))
from desktop_state import DesktopState, SearchIndex
class StateTests(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.path=Path(self.tmp.name)/'state.json';self.now=1000.;self.s=DesktopState(self.path,lambda:self.now)
 def tearDown(self):self.tmp.cleanup()
 def test_sc01_notifications_replace_group_read_and_keep_unread(self):
  self.s.notify({'id':1,'session':'s','app':'Mail','summary':'First','body':'body'})
  self.s.notify({'id':1,'session':'s','app':'Mail','summary':'Updated'})
  self.s.notify({'id':2,'session':'s','app':'Music','summary':'Track'})
  self.assertEqual(len(self.s.data['notifications']),2)
  self.s.read_group('Mail');self.s.clear_read()
  self.assertEqual([x['app'] for x in self.s.data['notifications']],['Music'])
  self.assertEqual(DesktopState(self.path).data['notifications'],self.s.data['notifications'])
 def test_sc01_dnd_retains_history_and_history_is_bounded(self):
  self.s.setting('dnd',True)
  for n in range(205):self.s.notify({'id':n,'session':'s','summary':str(n)})
  self.assertEqual(len(self.s.data['notifications']),200);self.assertTrue(self.s.data['settings']['dnd'])
 def test_sc05_task_roundtrip_toggle_delete(self):
  item=self.s.add_task('2026-09-19','Read paper','09:30','event');self.s.toggle_task(item['id'])
  self.assertTrue(DesktopState(self.path).data['agenda'][0]['done']);self.s.delete_task(item['id']);self.assertEqual(self.s.data['agenda'],[])
 def test_sc05_invalid_dates_times_and_empty_titles(self):
  for args in [('2026-02-30','x','','task'),('2026-09-19','','','task'),('2026-09-19','x','25:00','event')]:
   with self.assertRaises(ValueError):self.s.add_task(*args)
  self.assertEqual(self.s.data['agenda'],[])
 def test_sc06_pause_resume_complete_once(self):
  self.s.timer_start(60);self.now+=20;self.s.timer_pause();self.now+=100
  self.assertEqual(self.s.timer_snapshot()['remaining'],40)
  self.s.timer_resume();self.now+=41;self.assertTrue(self.s.timer_tick());self.assertFalse(self.s.timer_tick())
  self.assertEqual(self.s.timer_snapshot()['status'],'finished')
  self.s.timer_reset();self.assertEqual(self.s.timer_snapshot()['status'],'idle')
 def test_sc06_deadline_survives_restart_and_invalid_duration(self):
  self.s.timer_start(60);self.now+=15;self.s=DesktopState(self.path,lambda:self.now)
  self.assertEqual(self.s.timer_snapshot()['remaining'],45)
  for value in [0,-1,50000,float('nan')]:
   with self.assertRaises(ValueError):self.s.timer_start(value)
 def test_corrupt_state_preserved(self):
  self.path.write_text('broken');s=DesktopState(self.path)
  self.assertTrue(s.error);self.assertTrue(list(self.path.parent.glob('state.json.corrupt-*')))
 def test_preferences_persist_and_unknown_key_rejected(self):
  self.s.setting('reducedMotion',True)
  self.assertTrue(DesktopState(self.path).data['settings']['reducedMotion'])
  with self.assertRaises(ValueError):self.s.setting('shellCommand','rm')
class SearchTests(unittest.TestCase):
 def test_sc03_unicode_search_and_recent_order(self):
  index=SearchIndex([{'id':'app:a','name':'Терминал','kind':'app'}],[{'id':'file:b','name':'Заметки.txt','kind':'file'}],[])
  self.assertEqual(index.search('зам')[0]['id'],'file:b')
  self.assertEqual(index.search('', ['app:a'])[0]['id'],'app:a')
 def test_sc03_shell_text_is_only_a_query(self):
  index=SearchIndex([],[],[]);self.assertEqual(index.search('$(touch /tmp/no)'),[])
  with self.assertRaises(ValueError):index.resolve('command:arbitrary')
if __name__=='__main__':unittest.main()
