import sys
import tempfile
import unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'ui/runtime'))
from wallpapers import WallpaperSession, catalogue


class WallpaperTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.home=Path(self.temp.name);self.pictures=self.home/'pictures';self.pictures.mkdir()
        self.old=self.pictures/'old.png';self.new=self.pictures/'new.png'
        self.old.touch();self.new.touch();self.calls=[]
        self.session=WallpaperSession({'static':[str(self.pictures)]},self.home,lambda args,**kw:self.calls.append(args))
        self.session.state.mkdir(parents=True);self.session.current.symlink_to(self.old)
        self.ident=next(x['id'] for x in self.session.index()['items'] if x['path']==str(self.new))

    def test_preview_preserves_selection_and_cancel_restores_it(self):
        self.session.preview(self.ident)
        self.assertEqual(self.session.current.resolve(), self.old)
        self.assertTrue(self.session.marker.exists())
        self.session.restore()
        self.assertIn(['swww','img',str(self.old),'--transition-type','fade','--transition-duration','0.2','--transition-fps','30'],self.calls)
        self.assertFalse(self.session.marker.exists())

    def test_commit_is_the_only_call_to_wallpaper_set(self):
        self.session.preview(self.ident)
        self.assertFalse(any(x[0]=='wallpaper-set' for x in self.calls))
        self.session.commit(self.ident)
        self.assertIn(['wallpaper-set',str(self.new)], self.calls)
        self.assertFalse(self.session.marker.exists())

    def test_crash_recovery_respects_an_external_new_choice(self):
        self.session.preview(self.ident)
        self.session.current.unlink();self.session.current.symlink_to(self.new)
        recovery=WallpaperSession({},self.home,lambda args,**kw:self.calls.append(args))
        recovery.restore()
        self.assertEqual(self.calls[-1][2],str(self.new))

    def test_animation_catalogue_and_disappeared_selection(self):
        (self.pictures/'orbit.webm').touch()
        items=catalogue({'static':[str(self.pictures)],'animated':[str(self.pictures)]})
        self.assertEqual([x['kind'] for x in items].count('animated'),1)
        self.new.unlink()
        with self.assertRaises(ValueError):self.session.preview(self.ident)
        self.assertFalse(self.session.marker.exists())
