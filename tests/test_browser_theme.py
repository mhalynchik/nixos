"""Profile theme updates must preserve browser state and custom profiles."""

import configparser
from pathlib import Path
import runpy
import tempfile
import unittest

theme_module = runpy.run_path(str(Path(__file__).resolve().parents[1] / "lib/apply-browser-theme.py"))


class BrowserThemeTests(unittest.TestCase):
    def test_switch_updates_named_and_external_profiles_preserving_state(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory) / ".librewolf"
            root.mkdir()
            external = Path(directory) / "external profile"
            profiles = [root / "work-profile", external]
            registry = root / "profiles.ini"
            registry.write_text(
                "[Profile0]\nName=Work\nIsRelative=1\nPath=work-profile\nDefault=1\n"
                f"[Profile1]\nName=Other\nIsRelative=0\nPath={external}\n"
            )
            original_registry = registry.read_bytes()
            for profile in profiles:
                profile.mkdir()
                (profile / "sessionstore.jsonlz4").write_bytes(b"session sentinel")
                (profile / "places.sqlite").write_bytes(b"history sentinel")
                (profile / "user.js").write_text(
                    'user_pref("custom.preference", 42);\n'
                    'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", false);\n'
                )
            theme = Path(directory) / "theme"
            theme.mkdir()
            for palette in ["catppuccin", "crimson", "gallery"]:
                for name in ["userChrome.css", "userContent.css", "user.js"]:
                    (theme / name).write_text(palette)
                theme_module["apply_theme"](root, theme, "/must/not/create/a/profile")
                for profile in profiles:
                    self.assertEqual((profile / "chrome/userChrome.css").read_text(), palette)
                    self.assertEqual((profile / "chrome/userContent.css").read_text(), palette)
                    self.assertEqual((profile / "sessionstore.jsonlz4").read_bytes(), b"session sentinel")
                    self.assertEqual((profile / "places.sqlite").read_bytes(), b"history sentinel")
                    prefs = (profile / "user.js").read_text()
                    self.assertIn('user_pref("custom.preference", 42);', prefs)
                    self.assertNotIn("false", prefs)
                    theme_module["apply_theme"](root, theme, "/unused")
                    self.assertEqual((profile / "user.js").read_text(), prefs)
                self.assertEqual(registry.read_bytes(), original_registry)

    def test_commented_preference_does_not_disable_theme(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            profile = root / "old.default"
            profile.mkdir()
            (profile / "user.js").write_text('// user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", false);\n')
            for name in ["userChrome.css", "userContent.css"]:
                (root / name).write_text("new palette")
            theme_module["apply_theme"](root, root, "/unused")
            self.assertEqual((profile / "user.js").read_text().splitlines()[-1],
                             'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);')

    def test_invalid_registry_is_not_replaced(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            registry = root / "profiles.ini"
            registry.write_text("invalid registry\n")
            with self.assertRaises(configparser.Error):
                theme_module["apply_theme"](root, root, "/unused")
            self.assertEqual(registry.read_text(), "invalid registry\n")

    def test_registered_missing_profile_does_not_create_new_default(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            registry = root / "profiles.ini"
            registry.write_text("[Profile0]\nPath=missing\nIsRelative=1\n")
            with self.assertRaises(RuntimeError):
                theme_module["apply_theme"](root, root, "/unused")
            self.assertFalse((root / "themed.default").exists())


if __name__ == "__main__":
    unittest.main()
