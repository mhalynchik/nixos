"""Desktop regressions in the disposable VM: python tests/desktop_vm.py.

Requires a freshly built/running bin/ui-vm, its default 1280x800 display and
30-second popup timeout. Sends real keyboard/pointer input. Do not use the VM
interactively while this runs. It changes the guest clipboard and saves a PNG.
"""

import json
from pathlib import Path
import runpy
import struct
import subprocess
import time
import unittest

vm = runpy.run_path(str(Path(__file__).resolve().parents[1] / "bin/ui-vm"))


def guest(*args, check=True, binary=False):
    result = vm["guest"](list(args), capture_output=True, text=not binary, timeout=15)
    if check and result.returncode:
        raise AssertionError(f"{args}: {result.stderr}")
    return result


def eventually(predicate, timeout=10):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        value = predicate()
        if value:
            return value
        time.sleep(0.3)
    raise AssertionError("Guest state did not reach the expected value")


def key(chord):
    vm["key"](chord)
    time.sleep(0.3)


def ags(expression):
    # AGS prints the expression's return value (undefined) after print().
    return json.loads(guest("ui-session", "ags", "-r", expression).stdout.splitlines()[0])


def visible_popups():
    return ags('print(JSON.stringify(App.windows.filter(w => w.visible && w.name.endsWith("-popup")).map(w => w.name)));')


LABELS = "function labels(w){let a=[];if(w.get_text)a.push(w.get_text());if(w.get_children)for(const c of w.get_children())a.push(...labels(c));return a};"


def select_area():
    eventually(lambda: guest("pgrep", "-x", "slurp", check=False).returncode == 0)
    time.sleep(0.3)
    with vm["QMP"]() as qmp:
        def events(items):
            qmp.execute("input-send-event", {"events": items})

        def position(x, y):
            events([{"type": "abs", "data": {"axis": axis, "value": round(value * 32767 / limit)}}
                    for axis, value, limit in [("x", x, 1279), ("y", y, 799)]])

        position(200, 200)
        events([{"type": "btn", "data": {"down": True, "button": "left"}}])
        time.sleep(0.2)
        position(600, 500)
        time.sleep(0.2)
        events([{"type": "btn", "data": {"down": False, "button": "left"}}])


class DesktopRegressions(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if guest("hostname").stdout.strip() != "ui-test":
            raise RuntimeError("These tests must only run in ui-test")

    def tearDown(self):
        key("esc")
        guest("ui-session", "ags", "-r", 'App.windows.filter(w => w.visible && w.name.endsWith("-popup")).forEach(w => App.closeWindow(w.name));')

    def assert_desktop_unlocked(self):
        before = {c["address"] for c in vm["hypr_json"]("clients")}
        key("super-enter")
        opened = eventually(lambda: [c for c in vm["hypr_json"]("clients") if c["address"] not in before and c["class"] == "kitty"])
        for client in opened:
            guest("ui-session", "hyprctl", "dispatch", "closewindow", "address:" + client["address"])

    def test_screenshot_cancel_preserves_clipboard(self):
        sentinel = "Screenshot cancellation: Привет\nunchanged"
        for chord in ["print", "super-f12", "shift-print", "super-ctrl-s"]:
            with self.subTest(chord=chord):
                guest("bash", "-c", 'exec ui-session wl-copy -- "$1" </dev/null >/dev/null 2>&1', "clipboard", sentinel)
                key(chord)
                eventually(lambda: guest("pgrep", "-x", "slurp", check=False).returncode == 0)
                key("esc")
                eventually(lambda: guest("pgrep", "-x", "slurp", check=False).returncode != 0)
                self.assertEqual(guest("ui-session", "wl-paste", "--no-newline").stdout, sentinel)
                self.assertNotEqual(guest("pgrep", "-x", "swappy", check=False).returncode, 0)

    def test_screenshot_file_and_clipboard(self):
        # Remove only an empty destination to exercise first-use creation.
        guest("rmdir", "/home/ui/Pictures/Screenshots", check=False)
        listing = 'find /home/ui/Pictures/Screenshots -maxdepth 1 -name "*.png" 2>/dev/null || true'
        before = set(guest("bash", "-c", listing).stdout.splitlines())
        key("shift-print")
        select_area()
        created = eventually(lambda: set(guest("bash", "-c", listing).stdout.splitlines()) - before)
        self.assertEqual(len(created), 1)
        png = guest("cat", created.pop(), binary=True).stdout
        self.assertEqual(png[:8], b"\x89PNG\r\n\x1a\n")
        width, height = struct.unpack(">II", png[16:24])
        self.assertTrue(395 <= width <= 405 and 295 <= height <= 305, (width, height))
        key("print")
        select_area()
        eventually(lambda: "image/png" in guest("ui-session", "wl-paste", "--list-types").stdout)
        self.assertEqual(guest("ui-session", "wl-paste", "--type", "image/png", binary=True).stdout[:8], png[:8])

    def test_popups_exclusive_and_timeout(self):
        vm["pointer"](500, 600)
        names = ["audio-popup", "network-popup", "bluetooth-popup", "keyboard-popup", "system-stats-popup", "calendar-popup"]
        for name in names:
            guest("ui-session", "ags", "-t", name)
            eventually(lambda: visible_popups() == [name])
        eventually(lambda: not visible_popups(), timeout=35)
        log = guest("journalctl", "--user", "-b", "-u", "ags", "--no-pager").stdout
        self.assertNotIn("Expected an object of type GdkMonitor", log)

    def test_cpu_responds_to_load_and_idle(self):
        def cpu():
            labels = ags(LABELS + 'print(JSON.stringify(labels(App.getWindow("system-stats-popup"))));')
            return int(labels[labels.index("CPU") + 1].rstrip("%"))

        eventually(lambda: cpu() < 35, timeout=15)
        load = ["bash", "-c", "for i in 1 2 3 4; do timeout 9 yes >/dev/null 2>&1 & done; wait"]
        process = subprocess.Popen(vm["ssh_command"](load), stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        try:
            eventually(lambda: cpu() > 80, timeout=8)
        finally:
            process.communicate(timeout=15)
        eventually(lambda: cpu() < 35, timeout=10)

    def test_audio_default_indicator_tracks_switches(self):
        modules = []
        original = guest("ui-session", "pactl", "get-default-sink").stdout.strip()
        try:
            for name in ["vm_regression_a", "vm_regression_b"]:
                modules.append(guest("ui-session", "pactl", "load-module", "module-null-sink", f"sink_name={name}", f"sink_properties=device.description={name}").stdout.strip())
            guest("ui-session", "ags", "-t", "audio-popup")
            for name in ["vm_regression_a", "vm_regression_b", "vm_regression_a"]:
                guest("ui-session", "pactl", "set-default-sink", name)
                def selected():
                    return ags(LABELS + 'function rows(w){let a=[];if(w.get_style_context().has_class("sink-item") && w.get_style_context().has_class("default"))a.push(labels(w));if(w.get_children)for(const c of w.get_children())a.push(...rows(c));return a};print(JSON.stringify(rows(App.getWindow("audio-popup"))));')
                rows = eventually(lambda: (r := selected()) and len(r) == 1 and any(name in label for label in r[0]) and r)
                self.assertIn("󰄬", rows[0])
        finally:
            guest("ui-session", "pactl", "set-default-sink", original, check=False)
            for module in reversed(modules):
                guest("ui-session", "pactl", "unload-module", module, check=False)

    def test_idle_daemon_receives_lock_request(self):
        self.assertEqual(guest("systemctl", "--user", "is-active", "hypridle").stdout.strip(), "active")
        sessions = json.loads(guest("loginctl", "list-sessions", "--json=short").stdout)
        session = next(s["session"] for s in sessions if s["seat"] == "seat0" and s["user"] == "ui")
        guest("loginctl", "lock-session", session)
        eventually(lambda: guest("pgrep", "-x", "hyprlock", check=False).returncode == 0)
        guest("systemctl", "--user", "restart", "hypridle")
        time.sleep(1)
        self.assertEqual(guest("pgrep", "-x", "hyprlock", check=False).returncode, 0)
        key("u")
        key("i")
        key("ret")
        eventually(lambda: guest("pgrep", "-x", "hyprlock", check=False).returncode != 0)
        self.assert_desktop_unlocked()

    def test_idle_timer_locks_session(self):
        # Use the deployed lock hook and production timeout command, shortening
        # only the wait. Run in the user manager, just like the normal service.
        config = guest("cat", "/home/ui/.config/hypr/hypridle.conf").stdout.split("listener {")[0]
        config += "\nlistener {\n timeout = 3\n on-timeout = loginctl lock-session\n}\n"
        path = guest("mktemp", "/tmp/ui-idle-regression.XXXXXX").stdout.strip()
        guest("bash", "-c", 'printf "%s" "$2" > "$1"', "idle-config", path, config)
        guest("systemctl", "--user", "stop", "hypridle")
        try:
            guest("systemd-run", "--user", "--unit=ui-idle-regression", "--collect", "/etc/profiles/per-user/ui/bin/hypridle", "-c", path)
            vm["pointer"](400, 700)
            eventually(lambda: guest("pgrep", "-x", "hyprlock", check=False).returncode == 0)
            time.sleep(1)
            key("u")
            key("i")
            key("ret")
            eventually(lambda: guest("pgrep", "-x", "hyprlock", check=False).returncode != 0)
            # Stop before another three seconds of inactivity can relock it.
            guest("systemctl", "--user", "stop", "ui-idle-regression")
            self.assert_desktop_unlocked()
        finally:
            guest("systemctl", "--user", "stop", "ui-idle-regression", check=False)
            guest("rm", "-f", path)
            guest("systemctl", "--user", "start", "hypridle")


if __name__ == "__main__":
    unittest.main(verbosity=2)
