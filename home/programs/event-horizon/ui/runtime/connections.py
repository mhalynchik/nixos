"""NetworkManager and BlueZ session adapter; passwords never enter argv or state."""
import concurrent.futures
import json
import os
import select
import signal
import sys
import threading
import time

NM = 'org.freedesktop.NetworkManager'
NM_PATH = '/org/freedesktop/NetworkManager'
BLUEZ = 'org.bluez'


class SystemBus:
    def __init__(self):
        from gi.repository import Gio, GLib
        self.Gio, self.GLib = Gio, GLib
        self.connection = Gio.bus_get_sync(Gio.BusType.SYSTEM, None)

    def variant(self, kind, value):
        return self.GLib.Variant(kind, value)

    def call(self, service, path, interface, method, kind=None, args=(), timeout=5000):
        result = self.connection.call_sync(service, path, interface, method,
            self.variant(kind, args) if kind else None, None,
            self.Gio.DBusCallFlags.NONE, timeout, None)
        return result.unpack() if result else ()

    def properties(self, service, path, interface):
        return self.call(service, path, 'org.freedesktop.DBus.Properties', 'GetAll', '(s)', (interface,))[0]

    def set(self, service, path, interface, name, kind, value):
        self.call(service, path, 'org.freedesktop.DBus.Properties', 'Set', '(ssv)',
                  (interface, name, self.variant(kind, value)))

    def connection_settings(self, path):
        result = self.connection.call_sync(NM, path, NM+'.Settings.Connection', 'GetSettings',
            None, None, self.Gio.DBusCallFlags.NONE, 5000, None).get_child_value(0)
        settings = {}
        for i in range(result.n_children()):
            group = result.get_child_value(i)
            name, values = group.get_child_value(0).get_string(), group.get_child_value(1)
            settings[name] = {}
            for j in range(values.n_children()):
                entry = values.get_child_value(j)
                settings[name][entry.get_child_value(0).get_string()] = entry.get_child_value(1).get_variant()
        return settings


def security_name(props):
    flags = props.get('WpaFlags', 0) | props.get('RsnFlags', 0)
    if flags & 512:
        return 'enterprise'
    if flags & 1024:
        return 'sae'
    if flags:
        return 'wpa-psk'
    return 'wep' if props.get('Flags', 0) & 1 else 'open'


class Wifi:
    def __init__(self, bus):
        self.bus = bus
        self.aps = {}
        self.devices = {}
        self.connecting = None
        self.error = ''
        self.scan_times = {}
        self.scan_requested = {}

    def snapshot(self):
        root = self.bus.properties(NM, NM_PATH, NM)
        devices, aps, networks = {}, {}, []
        for path in root.get('Devices', []):
            device = self.bus.properties(NM, path, NM+'.Device')
            if device.get('DeviceType') != 2:
                continue
            devices[path] = device
            wireless = self.bus.properties(NM, path, NM+'.Device.Wireless')
            profiles = {}
            for candidate in device.get('AvailableConnections', []):
                settings = self.bus.call(NM, candidate, NM+'.Settings.Connection', 'GetSettings')[0]
                key = (bytes(settings.get('802-11-wireless', {}).get('ssid', [])),
                       settings.get('802-11-wireless-security', {}).get('key-mgmt', 'open'))
                profiles.setdefault(key, candidate)
            for ap in wireless.get('AccessPoints', []):
                props = self.bus.properties(NM, ap, NM+'.AccessPoint')
                ssid = bytes(props.get('Ssid', []))
                security = security_name(props)
                profile = profiles.get((ssid, {'wep': 'none', 'enterprise': 'wpa-eap'}.get(security, security)), '')
                row = {'id': ap, 'name': ssid.decode('utf-8', 'replace') or 'Скрытая сеть',
                    'hidden': not bool(ssid), 'strength': props.get('Strength', 0),
                    'security': security_name(props), 'device': path, 'interface': device.get('Interface', ''),
                    'connected': ap == wireless.get('ActiveAccessPoint') and device.get('State') == 100,
                    'saved': bool(profile)}
                aps[ap] = dict(row, ssid=ssid, profile=profile)
                networks.append(row)
        self.devices, self.aps = devices, aps
        enabled = bool(root.get('WirelessEnabled'))
        hardware = bool(root.get('WirelessHardwareEnabled'))
        networking = bool(root.get('NetworkingEnabled', True))
        ready = {path: device for path, device in devices.items()
                 if device.get('Managed', True) and 30 <= device.get('State', 0) < 110}
        blocked = ('Адаптер не найден' if not devices else
                   'Wi-Fi заблокирован аппаратным переключателем' if not hardware else
                   'Сеть отключена в NetworkManager' if not networking else
                   'Wi-Fi выключен' if not enabled else
                   'Адаптер не управляется NetworkManager' if not any(d.get('Managed', True) for d in devices.values()) else
                   'Служба Wi-Fi не готова: ошибка supplicant' if not ready and any(d.get('StateReason', [0, 0])[1] == 10 for d in devices.values()) else
                   'Адаптер Wi-Fi ещё не готов' if not ready else '')
        for path in list(self.scan_requested):
            started, previous = self.scan_requested[path]
            last_scan = self.bus.properties(NM, path, NM+'.Device.Wireless').get('LastScan', -1) if path in devices else -1
            if last_scan != previous or time.monotonic() - started > 15 or blocked:
                self.scan_requested.pop(path, None)
        if self.connecting:
            device = devices.get(self.connecting)
            if not device or device.get('State') == 120:
                self.error = 'Подключение не удалось. Проверь пароль и доступность сети.'
                self.connecting = None
            elif device.get('State') == 100:
                self.connecting = None
        # Show the strongest AP per SSID/security/interface; keep an active AP first.
        unique = {}
        for row in sorted(networks, key=lambda x: (not x['connected'], -x['strength'])):
            unique.setdefault((row['name'], row['security'], row['device']), row)
        return {'available': True, 'adapter': bool(devices), 'enabled': enabled,
            'hardwareEnabled': hardware, 'canScan': not bool(blocked), 'blockedReason': blocked,
            'scanning': bool(self.scan_requested), 'networks': list(unique.values()),
            'connecting': bool(self.connecting), 'error': self.error}

    def execute(self, message):
        action = message['action']
        self.error = ''
        state = self.snapshot()
        if action == 'wifi_power':
            if message['enabled'] and not state['hardwareEnabled']:
                raise ValueError(state['blockedReason'])
            self.bus.set(NM, NM_PATH, NM, 'WirelessEnabled', 'b', bool(message['enabled']))
            return
        if action == 'wifi_scan':
            if not state['canScan']:
                raise ValueError(state['blockedReason'])
            failures = []
            for path, device in self.devices.items():
                if not device.get('Managed', True) or not 30 <= device.get('State', 0) < 110:
                    continue
                if time.monotonic() - self.scan_times.get(path, -30) < 10:
                    continue
                previous = self.bus.properties(NM, path, NM+'.Device.Wireless').get('LastScan', -1)
                try:
                    self.bus.call(NM, path, NM+'.Device.Wireless', 'RequestScan', '(a{sv})', ({},))
                    self.scan_times[path] = time.monotonic()
                    self.scan_requested[path] = (time.monotonic(), previous)
                except Exception as error:
                    failures.append(str(error))
            if failures and not self.scan_requested:
                raise RuntimeError('Не удалось обновить сети. ' + failures[0])
            return
        row = self.aps.get(message.get('id'))
        if row is None:
            raise ValueError('Сеть больше недоступна. Обнови список.')
        if action == 'wifi_disconnect':
            self.bus.call(NM, row['device'], NM+'.Device', 'Disconnect')
            self.connecting = None
            return
        if action != 'wifi_connect':
            raise ValueError('Неизвестное действие Wi-Fi')
        password = str(message.get('password', ''))
        if row['profile']:
            if password:
                settings = self.bus.connection_settings(row['profile'])
                group = settings.setdefault('802-11-wireless-security', {})
                key = 'wep-key0' if row['security'] == 'wep' else 'psk'
                group[key] = self.bus.variant('s', password)
                self.bus.call(NM, row['profile'], NM+'.Settings.Connection', 'Update', '(a{sa{sv}})', (settings,))
            self.bus.call(NM, NM_PATH, NM, 'ActivateConnection', '(ooo)', (row['profile'], row['device'], row['id']))
        else:
            if row['security'] == 'enterprise':
                raise ValueError('Для новой сети 802.1X сначала настрой профиль и проверку сертификата в расширенных настройках.')
            ssid = row['ssid'] or str(message.get('ssid', '')).encode('utf-8')
            if not 1 <= len(ssid) <= 32:
                raise ValueError('Укажи имя скрытой сети (не более 32 байт).')
            v = self.bus.variant
            settings = {'connection': {'type': v('s', '802-11-wireless'), 'id': v('s', ssid.decode('utf-8', 'replace'))},
                '802-11-wireless': {'ssid': v('ay', ssid), 'mode': v('s', 'infrastructure')},
                'ipv4': {'method': v('s', 'auto')}, 'ipv6': {'method': v('s', 'auto')}}
            if row['security'] != 'open':
                if not password:
                    raise ValueError('Введи пароль сети.')
                settings['802-11-wireless-security'] = {'key-mgmt': v('s', 'none' if row['security']=='wep' else row['security']),
                    'wep-key0' if row['security']=='wep' else 'psk': v('s', password)}
            self.bus.call(NM, NM_PATH, NM, 'AddAndActivateConnection', '(a{sa{sv}}oo)', (settings, row['device'], row['id']))
        self.connecting = row['device']


AGENT_XML = '''<node><interface name="org.bluez.Agent1">
<method name="Release"/><method name="Cancel"/>
<method name="RequestPinCode"><arg type="o" direction="in"/><arg type="s" direction="out"/></method>
<method name="DisplayPinCode"><arg type="o" direction="in"/><arg type="s" direction="in"/></method>
<method name="RequestPasskey"><arg type="o" direction="in"/><arg type="u" direction="out"/></method>
<method name="DisplayPasskey"><arg type="o" direction="in"/><arg type="u" direction="in"/><arg type="q" direction="in"/></method>
<method name="RequestConfirmation"><arg type="o" direction="in"/><arg type="u" direction="in"/></method>
<method name="RequestAuthorization"><arg type="o" direction="in"/></method>
<method name="AuthorizeService"><arg type="o" direction="in"/><arg type="s" direction="in"/></method>
</interface></node>'''


class Bluetooth:
    def __init__(self, bus):
        self.bus, self.devices, self.adapters = bus, {}, {}
        self.scanning = set()
        self.scan_deadline = 0
        self.pairing = set()
        self.request = None
        self.invocation = None
        self.registered = False
        self.error = ''
        self.lock = threading.Lock()
        self.agent_path = '/org/eventhorizon/agent'
        info = bus.Gio.DBusNodeInfo.new_for_xml(AGENT_XML)
        self.registration = bus.connection.register_object(self.agent_path, info.interfaces[0], self.agent_call, None, None)
        self.loop = bus.GLib.MainLoop()
        threading.Thread(target=self.loop.run, daemon=True).start()

    def agent_call(self, connection, sender, path, interface, method, parameters, invocation):
        args = parameters.unpack()
        with self.lock:
            if method in ['Cancel', 'Release']:
                if method == 'Release':self.registered = False
                if self.invocation:
                    self.invocation.return_dbus_error('org.bluez.Error.Canceled', 'Canceled')
                self.request, self.invocation = None, None
                invocation.return_value(None)
                return
            if self.invocation:
                invocation.return_dbus_error('org.bluez.Error.Rejected', 'Another pairing request is active')
                return
            device = args[0]
            if device not in self.pairing:
                invocation.return_dbus_error('org.bluez.Error.Rejected', 'Pairing was not requested')
                return
            self.request = {'kind': method, 'device': device, 'name': self.devices.get(device, {}).get('name', device),
                'code': str(args[1]).zfill(6) if len(args)>1 else '', 'expires': time.monotonic()+60}
            if method.startswith('Display'):
                invocation.return_value(None)
            else:
                self.invocation = invocation

    def respond(self, message):
        if not message.get('accept') and self.request and not self.invocation:
            self.cancel_pairing()
            return
        with self.lock:
            if not self.invocation or not self.request:
                return
            invocation, request = self.invocation, self.request
            if not message.get('accept'):
                invocation.return_dbus_error('org.bluez.Error.Rejected', 'Rejected by user')
            elif request['kind'] == 'RequestPinCode':
                value = str(message.get('value', ''))
                if not 1 <= len(value) <= 16:
                    raise ValueError('PIN должен содержать от 1 до 16 символов.')
                invocation.return_value(self.bus.variant('(s)', (value,)))
            elif request['kind'] == 'RequestPasskey':
                value = str(message.get('value', ''))
                if not value.isdigit() or not 0 <= int(value) <= 999999:
                    raise ValueError('Введи цифровой код от 000000 до 999999.')
                invocation.return_value(self.bus.variant('(u)', (int(value),)))
            else:
                invocation.return_value(None)
            self.invocation, self.request = None, None

    def cancel_pairing(self):
        with self.lock:
            if self.invocation:
                self.invocation.return_dbus_error('org.bluez.Error.Canceled', 'Canceled by user')
            self.invocation, self.request = None, None
        for path in list(self.pairing):
            try:
                self.bus.call(BLUEZ, path, BLUEZ+'.Device1', 'CancelPairing')
            except Exception:
                pass

    def stop_scan(self):
        for path in list(self.scanning):
            try:
                self.bus.call(BLUEZ, path, BLUEZ+'.Adapter1', 'StopDiscovery')
            except Exception:
                pass
            self.scanning.discard(path)

    def snapshot(self):
        if self.scanning and time.monotonic() >= self.scan_deadline:
            self.stop_scan()
        objects = self.bus.call(BLUEZ, '/', 'org.freedesktop.DBus.ObjectManager', 'GetManagedObjects')[0]
        self.adapters = {p: i[BLUEZ+'.Adapter1'] for p, i in objects.items() if BLUEZ+'.Adapter1' in i}
        self.devices = {p: {'id': p, 'name': i[BLUEZ+'.Device1'].get('Alias', i[BLUEZ+'.Device1'].get('Address', 'Bluetooth')),
            'connected': i[BLUEZ+'.Device1'].get('Connected', False), 'paired': i[BLUEZ+'.Device1'].get('Paired', False),
            'trusted': i[BLUEZ+'.Device1'].get('Trusted', False), 'adapter': i[BLUEZ+'.Device1'].get('Adapter'),
            'battery': i.get(BLUEZ+'.Battery1', {}).get('Percentage', -1)}
            for p, i in objects.items() if BLUEZ+'.Device1' in i}
        if self.request and time.monotonic() > self.request['expires']:
            self.respond({'accept': False})
        return {'available': True, 'adapter': bool(self.adapters),
            'enabled': any(x.get('Powered') for x in self.adapters.values()),
            'scanning': bool(self.scanning), 'pairing': list(self.pairing), 'request': self.request,
            'devices': sorted(self.devices.values(), key=lambda x: (not x['connected'], not x['paired'], x['name'].lower())), 'error': self.error}

    def execute(self, message):
        action = message['action']
        if action == 'bt_reply':
            self.respond(message)
            return
        self.error = ''
        if action == 'radio_idle':
            self.cancel_pairing()
            self.stop_scan()
            return
        self.snapshot()
        if action == 'bt_power':
            if not message['enabled']:
                self.cancel_pairing()
                self.stop_scan()
            for path in self.adapters:
                self.bus.set(BLUEZ, path, BLUEZ+'.Adapter1', 'Powered', 'b', bool(message['enabled']))
            return
        if action == 'bt_scan':
            self.scan_deadline = time.monotonic() + 20
            for path, props in self.adapters.items():
                if props.get('Powered') and path not in self.scanning:
                    self.bus.call(BLUEZ, path, BLUEZ+'.Adapter1', 'StartDiscovery')
                    self.scanning.add(path)
            return
        row = self.devices.get(message.get('id'))
        if row is None:
            raise ValueError('Устройство больше недоступно.')
        path = row['id']
        if action == 'bt_disconnect':
            self.bus.call(BLUEZ, path, BLUEZ+'.Device1', 'Disconnect')
        elif action == 'bt_forget':
            self.bus.call(BLUEZ, row['adapter'], BLUEZ+'.Adapter1', 'RemoveDevice', '(o)', (path,))
        elif action == 'bt_connect':
            if not row['paired']:
                if not self.registered:
                    self.bus.call(BLUEZ, '/org/bluez', BLUEZ+'.AgentManager1', 'RegisterAgent', '(os)', (self.agent_path, 'KeyboardDisplay'))
                    self.registered = True
                self.pairing.add(path)
                try:
                    self.bus.call(BLUEZ, path, BLUEZ+'.Device1', 'Pair', timeout=90000)
                finally:
                    self.pairing.discard(path)
                    with self.lock:
                        if self.invocation:
                            self.invocation.return_dbus_error('org.bluez.Error.Canceled', 'Pairing finished')
                        self.request, self.invocation = None, None
                self.bus.set(BLUEZ, path, BLUEZ+'.Device1', 'Trusted', 'b', True)
            self.bus.call(BLUEZ, path, BLUEZ+'.Device1', 'Connect', timeout=30000)
        else:
            raise ValueError('Неизвестное действие Bluetooth')


def main():
    bus = SystemBus()
    wifi, bluetooth = Wifi(bus), Bluetooth(bus)
    pool = concurrent.futures.ThreadPoolExecutor(max_workers=3)
    pending, buffer = {}, b''
    alive = True
    last = 0
    def stop(*args):
        nonlocal alive
        alive = False
    signal.signal(signal.SIGTERM, stop)
    signal.signal(signal.SIGINT, stop)
    try:
        while alive:
            if select.select([sys.stdin], [], [], .2)[0]:
                chunk = os.read(sys.stdin.fileno(), 65536)
                if not chunk:
                    break
                buffer += chunk
                while b'\n' in buffer:
                    line, buffer = buffer.split(b'\n', 1)
                    try:
                        message = json.loads(line)
                        action = message['action']
                        domain = 'wifi' if action.startswith('wifi_') else 'bluetooth'
                        adapter = wifi if domain=='wifi' else bluetooth
                        if action == 'radio_idle':
                            bluetooth.execute(message)
                        elif action == 'bt_reply':
                            bluetooth.respond(message)
                        elif domain not in pending or pending[domain].done():
                            pending[domain] = pool.submit(adapter.execute, message)
                    except Exception as error:
                        print(json.dumps({'error': str(error)}), flush=True)
                    last = 0
            if time.monotonic()-last < 1:
                continue
            result = {}
            for domain, adapter in [('wifi', wifi), ('bluetooth', bluetooth)]:
                future = pending.get(domain)
                if future and future.done():
                    try:
                        future.result()
                    except Exception as error:
                        adapter.error = str(error)[:400]
                    pending.pop(domain, None)
                try:
                    result[domain] = adapter.snapshot()
                except Exception as error:
                    if domain == 'bluetooth':bluetooth.registered = False
                    result[domain] = {'available': False, 'adapter': False, 'networks': [], 'devices': [], 'error': str(error)[:400]}
                result[domain]['busy'] = domain in pending
            print(json.dumps(result, ensure_ascii=False), flush=True)
            last = time.monotonic()
    finally:
        try:
            bluetooth.execute({'action': 'radio_idle'})
        except Exception:
            pass
        pool.shutdown(wait=False, cancel_futures=True)
        bluetooth.loop.quit()


if __name__ == '__main__':
    main()
