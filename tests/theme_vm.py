"""Theme integration checks: UI_VM_STATE=... python tests/theme_vm.py.

Run after each theme switch, including the first boot on a fresh VM disk.
Uses real GTK and Hyprlock; never run against the host desktop.
"""

import re
import time
import unittest

from desktop_vm import ags, eventually, guest, key


class ThemeIntegration(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if guest("hostname").stdout.strip() != "ui-test":
            raise RuntimeError("These tests must only run in ui-test")
        text = guest("cat", "/home/ui/.config/btop/themes/stylix.theme").stdout
        cls.base = re.search(r'theme\[main_bg\]="(#[0-9a-fA-F]+)"', text)[1]
        cls.accent = re.search(r'theme\[hi_fg\]="(#[0-9a-fA-F]+)"', text)[1]

    def test_browser_uses_current_generation(self):
        guest("bash", "-lc", r'''set -euo pipefail
found=0
for css in "$HOME"/.librewolf/*/chrome/userChrome.css; do
    test -f "$css" || continue
    found=1
    cmp "$css" "$HOME/.config/librewolf-theme/userChrome.css"
    cmp "${css%/*}/userContent.css" "$HOME/.config/librewolf-theme/userContent.css"
    grep -q 'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);' "${css%/chrome/*}/user.js"
done
test "$found" = 1
''')

    def test_terminal_programs_have_active_theme(self):
        self.assertIn('color_theme = "stylix"', guest("cat", "/home/ui/.config/btop/btop.conf").stdout)
        self.assertIn("base16-stylix", guest("cat", "/home/ui/.config/bat/config").stdout)
        self.assertIn(self.accent.lower(), guest("cat", "/home/ui/.config/lazygit/config.yml").stdout.lower())
        normal = guest("nvim", "--headless", "+lua print(vim.api.nvim_get_hl(0, {name='Normal'}).bg)", "+q")
        self.assertIn(str(int(self.base[1:], 16)), normal.stdout + normal.stderr)
        guest("vim", "-X", "-es", "-c", "call writefile([synIDattr(hlID('Normal'), 'bg#')], '/tmp/vim-theme-name')", "-c", "qa!")
        self.assertEqual(self.base.lower(), guest("cat", "/tmp/vim-theme-name").stdout.strip().lower())

    def test_gtk_accent_matches_terminal_and_desktop_palette(self):
        color = ags('const Gtk=imports.gi.Gtk;let w=new Gtk.Window();let [ok,c]=w.get_style_context().lookup_color("accent_bg_color");print(JSON.stringify({ok,r:Math.round(c.red*255),g:Math.round(c.green*255),b:Math.round(c.blue*255)}));w.destroy();')
        self.assertTrue(color["ok"])
        self.assertEqual("#{r:02x}{g:02x}{b:02x}".format(**color), self.accent.lower())

    def test_lock_parses_theme_and_authenticates(self):
        guest("ui-session", "hyprctl", "dispatch", "exec", "hyprlock > /tmp/theme-integration-lock.log 2>&1")
        eventually(lambda: guest("pgrep", "-x", "hyprlock", check=False).returncode == 0)
        time.sleep(2)
        key("u")
        key("i")
        key("ret")
        eventually(lambda: guest("pgrep", "-x", "hyprlock", check=False).returncode != 0)
        log = guest("cat", "/tmp/theme-integration-lock.log").stdout
        self.assertNotIn("[ERR]", log)
        self.assertNotIn("Error parsing", log)
        self.assertIn("auth: authenticated for hyprlock", log)


if __name__ == "__main__":
    unittest.main(verbosity=2)
