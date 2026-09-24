import os
import sys
import unittest
from pathlib import Path
from unittest.mock import Mock,patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'ui/runtime'))
from desktop_backend import Session


class LockTests(unittest.TestCase):
    def session(self):
        session=Session.__new__(Session);session.event=None;session.serial=0
        return session

    def properties(self,**overrides):
        fields=dict(User=str(os.getuid()),Active='yes',Remote='no',Type='wayland');fields.update(overrides)
        return '\n'.join(k+'='+v for k,v in fields.items())

    def test_user_service_locks_explicit_graphical_session(self):
        session=self.session()
        with patch.dict(os.environ,{},clear=True),patch('desktop_backend.run',side_effect=['c7',self.properties(),'active','']) as run:
            session.execute({'action':'power','operation':'lock'})
        self.assertEqual(run.call_args.args[0],['loginctl','lock-session','c7'])
        self.assertEqual(session.event,{'kind':'close'})

    def test_never_locks_another_user_remote_or_inactive_session(self):
        for overrides in [dict(User=str(os.getuid()+1)),dict(Active='no'),dict(Remote='yes'),dict(Type='tty'),dict(Class='greeter')]:
            session=self.session()
            with patch('desktop_backend.run',side_effect=['3',self.properties(**overrides)]) as run:
                with self.assertRaises(RuntimeError):session.lock_screen()
            self.assertEqual(run.call_count,2)
            self.assertIsNone(session.event)

    def test_missing_session_or_failed_request_does_not_close_menu(self):
        for responses in [[''],['2',self.properties(),'active',RuntimeError('Lock request rejected')],['2',self.properties(),RuntimeError('Hypridle inactive')]]:
            session=self.session()
            with patch('desktop_backend.run',side_effect=responses):
                with self.assertRaises(RuntimeError):session.lock_screen()
            self.assertIsNone(session.event)

    def test_search_and_power_use_same_lock_path(self):
        session=self.session();session.index=Mock();session.store=Mock();session.lock_screen=Mock()
        session.index.resolve.return_value={'id':'command:lock','kind':'command','command':'lock'}
        session.execute({'action':'launch','id':'command:lock'})
        session.lock_screen.assert_called_once()
