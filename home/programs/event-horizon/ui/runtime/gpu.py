"""Best-effort GPU telemetry; missing drivers/permissions never break the shell."""
import csv
import math
import re
import shutil
import subprocess
import time
from pathlib import Path

VENDORS = {'0x1002': 'AMD', '0x10de': 'NVIDIA', '0x8086': 'Intel'}


def read_text(path):
    try:
        return path.read_text().strip()
    except (OSError, UnicodeError):
        return ''


def number(value, maximum=None):
    try:
        value = float(value)
        if not math.isfinite(value) or value < 0 or (maximum is not None and value > maximum):
            return None
        return round(value, 1)
    except (ValueError, TypeError):
        return None


def command(args):
    try:
        result = subprocess.run(args, capture_output=True, text=True, timeout=.8,
                                check=False, env={'PATH': '/run/current-system/sw/bin', 'LC_ALL': 'C'})
        return result.stdout if result.returncode == 0 else ''
    except (OSError, subprocess.TimeoutExpired, UnicodeError):
        return ''


class GpuTelemetry:
    def __init__(self, sysfs=Path('/sys'), runner=command, clock=time.monotonic, which=shutil.which):
        self.sysfs, self.runner, self.clock, self.which = Path(sysfs), runner, clock, which
        self.devices = []
        self.discover_at = 0
        self.nvidia_retry_at = 0

    def discover(self):
        names = {}
        lspci = self.which('lspci')
        if lspci:
            for line in self.runner([lspci, '-D', '-nn']).splitlines():
                match = re.match(r'^(\S+) (?:VGA compatible controller|3D controller|Display controller) \[[^]]+\]: (.+)$', line)
                if match:
                    names[match[1].lower()] = re.sub(r' \[[0-9a-f]{4}:[0-9a-f]{4}\](?: \(rev [^)]+\))?$', '', match[2])
        devices = []
        try:
            candidates = sorted((self.sysfs / 'bus/pci/devices').iterdir())
        except OSError:
            candidates = []
        for path in candidates:
            if not read_text(path / 'class').lower().startswith('0x03'):
                continue
            vendor = VENDORS.get(read_text(path / 'vendor').lower(), 'GPU')
            try:
                driver = (path / 'driver').resolve(strict=True).name
            except (OSError, RuntimeError):
                driver = ''
            device_id = read_text(path / 'device').removeprefix('0x')
            label = read_text(path / 'product_name') or read_text(path / 'label')
            name = names.get(path.name.lower()) or label or f'{vendor} {device_id or path.name}'
            devices.append((path, {'id': path.name, 'vendor': vendor, 'name': name, 'driver': driver}))
        self.devices = devices
        self.discover_at = self.clock() + 30

    @staticmethod
    def temperature(path):
        try:
            sensors = sorted((path / 'hwmon').glob('hwmon*/temp*_input'))
            # Prefer edge/package temperature over memory/hotspot where labelled.
            sensors.sort(key=lambda p: read_text(p.with_name(p.name.replace('_input', '_label'))).lower() not in ('edge', 'gpu', 'package id 0'))
            for sensor in sensors:
                raw = number(read_text(sensor))
                if raw is not None and raw <= 200000:
                    return round(raw / 1000, 1)
        except OSError:
            pass
        return None

    def nvidia(self):
        if not any(info['vendor'] == 'NVIDIA' for _, info in self.devices) or self.clock() < self.nvidia_retry_at:
            return {}
        binary = self.which('nvidia-smi')
        if not binary:
            candidate = Path('/run/opengl-driver/bin/nvidia-smi')
            if candidate.is_file():
                binary = str(candidate)
        if not binary:
            self.nvidia_retry_at = self.clock() + 30
            return {}
        output = self.runner([binary, '--query-gpu=pci.bus_id,name,utilization.gpu,memory.used,memory.total,temperature.gpu', '--format=csv,noheader,nounits'])
        if not output:
            self.nvidia_retry_at = self.clock() + 30
            return {}
        result = {}
        for row in csv.reader(output.splitlines(), skipinitialspace=True):
            if len(row) != 6:
                continue
            # NVIDIA uses an eight-digit PCI domain; sysfs uses four digits.
            bus = row[0].lower().strip()
            parts = bus.split(':')
            if len(parts) != 3:
                continue
            bus = ':'.join([parts[0][-4:], *parts[1:]])
            result[bus] = {'name': row[1].strip(), 'utilization': number(row[2], 100),
                           'memoryUsedMiB': number(row[3]), 'memoryTotalMiB': number(row[4]),
                           'temperatureC': number(row[5], 200)}
        return result

    def read(self):
        if self.clock() >= self.discover_at:
            self.discover()
        nvidia = self.nvidia()
        output = []
        for path, info in self.devices:
            if not path.exists():
                continue
            utilization = number(read_text(path / 'gpu_busy_percent'), 100)
            if utilization is None:
                utilization = number(read_text(path / 'gt_busy_percent'), 100)
            used = number(read_text(path / 'mem_info_vram_used'))
            total = number(read_text(path / 'mem_info_vram_total'))
            # Integrated GPUs often report a zero-sized dedicated VRAM region.
            dedicated = total is not None and total > 0
            item = dict(info, utilization=utilization,
                        memoryUsedMiB=round(used / 1048576, 1) if dedicated and used is not None else None,
                        memoryTotalMiB=round(total / 1048576, 1) if dedicated else None,
                        temperatureC=self.temperature(path))
            item.update(nvidia.get(info['id'].lower(), {}))
            output.append(item)
        return output
