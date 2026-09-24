import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'ui/runtime'))
from gpu import GpuTelemetry, command


class GpuTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.now = 1
        self.calls = []
        self.responses = {}
        self.probe = GpuTelemetry(self.root, self.run_command, lambda: self.now, lambda name: '/bin/' + name)

    def run_command(self, args):
        self.calls.append(args)
        return self.responses.get(Path(args[0]).name, '')

    def device(self, slot, vendor, **files):
        path = self.root / 'bus/pci/devices' / slot
        for name, value in {'vendor': vendor, 'class': '0x030000', 'device': '0x1234', **files}.items():
            dest = path / name
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_text(str(value))
        return path

    def test_no_gpu_and_unavailable_sysfs(self):
        self.assertEqual([], self.probe.read())
        self.assertFalse(any('nvidia-smi' in a[0] for a in self.calls))

    def test_amd_metrics_and_model_name(self):
        self.device('0000:03:00.0', '0x1002', gpu_busy_percent=42, mem_info_vram_used=1073741824,
                    mem_info_vram_total=8589934592, **{'hwmon/hwmon4/temp1_input': 55500})
        self.responses['lspci'] = '0000:03:00.0 VGA compatible controller [0300]: AMD Radeon RX 6600 [1002:73ff] (rev c7)\n'
        item, = self.probe.read()
        self.assertEqual('AMD Radeon RX 6600', item['name'])
        self.assertEqual((42, 1024, 8192, 55.5), tuple(item[k] for k in ('utilization', 'memoryUsedMiB', 'memoryTotalMiB', 'temperatureC')))

    def test_intel_arc_and_integrated_missing_vram(self):
        self.device('0000:00:02.0', '0x8086', gt_busy_percent=18, mem_info_vram_total=0)
        item, = self.probe.read()
        self.assertEqual('Intel', item['vendor'])
        self.assertEqual(18, item['utilization'])
        self.assertIsNone(item['memoryTotalMiB'])
        self.assertIsNone(item['memoryUsedMiB'])
        self.assertIsNone(item['temperatureC'])

    def test_multiple_gpus_and_nvidia_unsupported_sensors(self):
        self.device('0000:00:02.0', '0x8086')
        self.device('0000:01:00.0', '0x10de')
        self.responses['nvidia-smi'] = '00000000:01:00.0, NVIDIA GeForce RTX 4070, 23, 1034, 12282, [N/A]\ninvalid,row\n'
        intel, nvidia = self.probe.read()
        self.assertEqual('Intel', intel['vendor'])
        self.assertEqual('NVIDIA GeForce RTX 4070', nvidia['name'])
        self.assertEqual(23, nvidia['utilization'])
        self.assertEqual(12282, nvidia['memoryTotalMiB'])
        self.assertIsNone(nvidia['temperatureC'])

    def test_unknown_vendor_bad_data_not_fake_zero(self):
        self.device('0000:03:00.0', '0xabcd', gpu_busy_percent=101, mem_info_vram_used='NaN', mem_info_vram_total=-1,
                    **{'hwmon/hwmon0/temp1_input': 'not supported'})
        item, = self.probe.read()
        self.assertEqual('GPU 1234', item['name'])
        for key in ('utilization', 'memoryUsedMiB', 'memoryTotalMiB', 'temperatureC'):
            self.assertIsNone(item[key])

    def test_discovery_cached_and_removed_gpu_ignored(self):
        self.device('0000:03:00.0', '0x1002')
        self.probe.read()
        self.probe.read()
        self.assertEqual(1, sum(a[0].endswith('lspci') for a in self.calls))
        self.tmp.cleanup()
        self.assertEqual([], self.probe.read())

    def test_failed_nvidia_poll_backs_off(self):
        self.device('0000:01:00.0', '0x10de')
        self.probe.read()
        self.now = 5
        self.probe.read()
        self.assertEqual(1, sum(a[0].endswith('nvidia-smi') for a in self.calls))
        self.now = 32
        self.probe.read()
        self.assertEqual(2, sum(a[0].endswith('nvidia-smi') for a in self.calls))

    def test_command_timeout_missing_tool_and_nonzero_are_silent(self):
        for failure in (FileNotFoundError(), subprocess.TimeoutExpired('tool', .8)):
            with patch('gpu.subprocess.run', side_effect=failure):
                self.assertEqual('', command(['tool']))
        with patch('gpu.subprocess.run', return_value=subprocess.CompletedProcess(['tool'], 1, '', 'denied')):
            self.assertEqual('', command(['tool']))


if __name__ == '__main__':
    unittest.main()
