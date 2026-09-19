"""Control protocol failure handling without booting a guest. Run with unittest."""

from contextlib import contextmanager
import importlib.machinery
import importlib.util
import json
import os
from pathlib import Path
import shlex
import socket
import subprocess
import tempfile
import threading
import sys
import unittest
from unittest.mock import patch


loader = importlib.machinery.SourceFileLoader("ui_vm", str(Path(__file__).resolve().parents[1] / "bin/ui-vm"))
spec = importlib.util.spec_from_loader(loader.name, loader)
vm = importlib.util.module_from_spec(spec)
loader.exec_module(vm)


@contextmanager
def server(reply):
    with tempfile.TemporaryDirectory(prefix="ui-vm-test-") as directory:
        state = Path(directory)
        listener = socket.socket(socket.AF_UNIX)
        listener.bind(str(state / "qmp.sock"))
        listener.listen(1)
        listener.settimeout(5)
        requests = []
        errors = []

        def serve():
            try:
                connection, _ = listener.accept()
                with connection, connection.makefile("rwb") as stream:
                    stream.write(b'{"QMP": {"version": {}}}\n')
                    stream.flush()
                    requests.append(json.loads(stream.readline()))
                    stream.write(b'{"return": {}, "id": "ui-vm"}\n')
                    stream.flush()
                    requests.append(json.loads(stream.readline()))
                    stream.write(reply)
                    stream.flush()
            except Exception as error:
                errors.append(error)

        thread = threading.Thread(target=serve, daemon=True)
        thread.start()
        try:
            with patch.object(vm, "STATE", state):
                yield requests
        finally:
            thread.join(timeout=6)
            listener.close()
            if thread.is_alive():
                raise AssertionError("QMP test server did not finish")
            if errors:
                raise errors[0]


class QMPTests(unittest.TestCase):
    def test_async_events_do_not_replace_command_response(self):
        reply = b'{"event":"RESET"}\n{"return":{"running":true},"id":"ui-vm"}\n'
        with server(reply) as requests:
            with vm.QMP() as qmp:
                self.assertEqual(qmp.execute("query-status"), {"running": True})
        self.assertEqual([r["execute"] for r in requests], ["qmp_capabilities", "query-status"])

    def test_qemu_error_reaches_caller(self):
        with server(b'{"error":{"class":"GenericError","desc":"bad key"},"id":"ui-vm"}\n'):
            with vm.QMP() as qmp:
                with self.assertRaisesRegex(RuntimeError, "bad key"):
                    qmp.execute("send-key")

    def test_disconnect_is_an_error(self):
        with server(b""):
            with vm.QMP() as qmp:
                with self.assertRaisesRegex(RuntimeError, "closed"):
                    qmp.execute("query-status")

    def test_super_enter_uses_qemu_key_names(self):
        with server(b'{"return":{},"id":"ui-vm"}\n') as requests:
            vm.key("super-enter")
        self.assertEqual(requests[1]["arguments"]["keys"], [
            {"type": "qcode", "data": "meta_l"}, {"type": "qcode", "data": "ret"},
        ])

    def test_stopped_vm_has_no_status(self):
        with tempfile.TemporaryDirectory() as directory:
            with patch.object(vm, "STATE", Path(directory)):
                self.assertIsNone(vm.running())

    def test_remote_arguments_remain_literal(self):
        arguments = ["printf", "%s", "a b; $(touch /tmp/unwanted)\n'quoted'"]
        command = vm.ssh_command(arguments)
        self.assertEqual(shlex.split(command[-1]), arguments)
        self.assertIn("BatchMode=yes", command)
        self.assertIn("ui@127.0.0.1", command)

    def test_virgl_screenshot_falls_back_to_guest(self):
        reply = b'{"error":{"class":"GenericError","desc":"no surface"},"id":"ui-vm"}\n'
        png = b"\x89PNG\r\n\x1a\n" + bytes(16)
        with server(reply):
            destination = vm.STATE / "screen.png"
            with patch.object(vm, "guest", return_value=subprocess.CompletedProcess([], 0, png)):
                self.assertEqual(vm.screenshot(destination).read_bytes(), png)

    def test_failed_screenshot_does_not_replace_existing_image(self):
        reply = b'{"error":{"class":"GenericError","desc":"no surface"},"id":"ui-vm"}\n'
        with server(reply):
            destination = vm.STATE / "screen.png"
            destination.write_bytes(b"previous image")
            with patch.object(vm, "guest", return_value=subprocess.CompletedProcess([], 0, b"not PNG")):
                with self.assertRaisesRegex(RuntimeError, "PNG"):
                    vm.screenshot(destination)
            self.assertEqual(destination.read_bytes(), b"previous image")

    def test_refuses_to_take_over_an_unrelated_state_directory(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "important.txt").write_text("keep")
            before = path.stat().st_mode
            result = subprocess.run([sys.executable, str(vm.REPO / "bin/ui-vm"), "paths"],
                                    env={**os.environ, "UI_VM_STATE": directory}, capture_output=True)
            self.assertEqual(result.returncode, 2)
            self.assertEqual(path.stat().st_mode, before)
            self.assertEqual((path / "important.txt").read_text(), "keep")

    def test_new_state_is_private_and_reusable(self):
        with tempfile.TemporaryDirectory() as directory:
            state = Path(directory) / "vm"
            for _ in range(2):
                subprocess.run([sys.executable, str(vm.REPO / "bin/ui-vm"), "paths"],
                               env={**os.environ, "UI_VM_STATE": str(state)},
                               check=True, capture_output=True)
            self.assertEqual(state.stat().st_mode & 0o777, 0o700)


if __name__ == "__main__":
    unittest.main()
