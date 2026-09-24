import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parents[1] / 'ui/runtime'))
from desktop_state import DesktopState
import notification_history as history


class NotificationHistoryTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.now = 1000000
        self.state = DesktopState(Path(self.tmp.name) / 'state.json', lambda: self.now)

    def tearDown(self):
        self.tmp.cleanup()

    def notify(self, ident, app='Telegram', **kwargs):
        return self.state.notify(dict(sourceId=ident, app=app, session='session', summary='Title', **kwargs))

    def test_spotify_replaces_track_without_affecting_other_sources(self):
        self.notify(1)
        self.notify(2, 'Spotify')
        latest = self.notify(3, 'Spotify')
        self.assertEqual(len(self.state.data['notifications']), 2)
        self.assertEqual(self.state.data['notifications'][-1]['id'], latest['id'])

    def test_spotify_desktop_identity_and_translated_name(self):
        self.notify(1, 'Музыка', desktopEntry='com.spotify.Client')
        self.notify(2, 'Музыка', desktopEntry='com.spotify.Client')
        self.assertEqual(len(self.state.data['notifications']), 1)

    def test_retention_limit_is_per_source_and_policy_persists(self):
        self.state.notification_policy('Telegram', 3, 20)
        for i in range(30):
            self.notify(i)
        self.notify(100, 'Mail')
        self.assertEqual(len(self.state.data['notifications']), 21)
        loaded = DesktopState(self.state.path, lambda: self.now)
        self.assertEqual(loaded.data['notificationPolicies']['Telegram'], {'days': 3, 'limit': 20})
        self.assertEqual(loaded.data['notifications'][0]['sourceId'], 10)

    def test_old_entries_expire_even_without_new_notifications(self):
        self.state.notification_policy('Telegram', 1, 20)
        self.notify(1)
        self.notify(2, 'Mail')
        self.now += 86401
        self.state.prune_notifications()
        self.assertEqual([n['app'] for n in self.state.data['notifications']], ['Mail'])

    def test_chat_read_and_delete_do_not_touch_neighbours(self):
        self.notify(1, conversation='Project', conversationId='chat1')
        self.notify(2, conversation='Project', conversationId='chat2')
        self.state.read_group('Telegram', 'chat1')
        self.assertEqual([n['read'] for n in self.state.data['notifications']], [True, False])
        self.state.remove_notification_group('Telegram', 'chat1')
        self.assertEqual(self.state.data['notifications'][0]['conversationId'], 'chat2')

    def test_read_single_and_remove_entire_application(self):
        a = self.notify(1)
        self.notify(2)
        self.notify(3, 'Mail')
        self.state.read_notification(a['id'])
        self.assertEqual([n['read'] for n in self.state.data['notifications']], [True, False, False])
        self.state.remove_notification_group('Telegram')
        self.assertEqual([n['app'] for n in self.state.data['notifications']], ['Mail'])

    def test_action_token_is_persisted_but_not_derived_from_notification_id(self):
        a = self.notify(4, actionToken='session:1')
        b = self.notify(4, actionToken='session:2')
        self.assertNotEqual(a['id'], b['id'])
        self.assertEqual(len(self.state.data['notifications']), 1)
        self.assertEqual(self.state.data['notifications'][0]['actionToken'], 'session:2')

    def test_markup_is_plain_and_bounded(self):
        item = self.notify(1, body='<b>Title</b> &amp; details <img src="https://example.org/">')
        self.assertEqual(item['body'], 'Title & details ')
        self.assertEqual(len(self.notify(2, body='x' * 9000)['body']), 4096)

    def test_plain_titles_and_technical_body_survive(self):
        item = self.state.notify({'app': 'Tool <literal>', 'summary': 'std::vector<int> &amp; <b>literal</b>',
                                  'conversation': '<thread>', 'body': 'std::vector<int> <literal> <b>bold</b> &lt;b&gt;escaped&lt;/b&gt;'})
        self.assertEqual(item['app'], 'Tool <literal>')
        self.assertEqual(item['summary'], 'std::vector<int> &amp; <b>literal</b>')
        self.assertEqual(item['conversation'], '<thread>')
        self.assertEqual(item['body'], 'std::vector<int> <literal> bold <b>escaped</b>')

    def test_history_cap_applies_across_many_sources(self):
        items = [history.notification({'id': n, 'app': f'App {n}'}, self.now) for n in range(800)]
        retained = history.prune(items, {}, self.now)
        self.assertEqual(len(retained), 500)
        self.assertEqual(retained[0]['sourceId'], 300)

    def test_invalid_policy_never_changes_history(self):
        self.notify(1)
        for days, limit in [(0, 20), (True, 20), (7, 99999), (7, '20'), (float('nan'), 50)]:
            with self.assertRaises(ValueError):
                self.state.notification_policy('Telegram', days, limit)
        self.assertEqual(len(self.state.data['notifications']), 1)
        self.assertEqual(self.state.data['notificationPolicies'], {})

    def test_legacy_state_migrates_without_loss(self):
        self.notify(1)
        data = self.state.data.copy()
        data.pop('notificationPolicies')
        self.state.path.write_text(json.dumps(data))
        loaded = DesktopState(self.state.path, lambda: self.now)
        self.assertEqual(loaded.data['notificationPolicies'], {})
        self.assertEqual(len(loaded.data['notifications']), 1)
        self.assertFalse(loaded.error)


if __name__ == '__main__':
    unittest.main()
