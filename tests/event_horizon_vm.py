"""Event Horizon integration in the ui-test VM with programs.eventHorizon=true.

Run sequentially: UI_VM_STATE=... python3 tests/event_horizon_vm.py.
Uses a disposable guest: launches apps, sends notifications, restarts the shell
and Home Manager, and temporarily changes wallpaper. Never targets the host.
"""
import json
import shutil
import re
from pathlib import Path
import runpy
import time
import unittest

vm = runpy.run_path(str(Path(__file__).resolve().parents[1] / 'bin/ui-vm'))


def guest(*args, check=True):
    result = vm['guest'](list(args), capture_output=True, text=True, timeout=45)
    if check and result.returncode:
        raise AssertionError(f'{args}: {result.stderr}')
    return result


def ipc(method, *args):
    return guest('ui-session', 'event-horizon', 'ipc', 'call', 'design', method, *args).stdout


def command(action, **args):
    ipc('command', json.dumps(dict(action=action, **args)))


def status():
    return json.loads(ipc('status'))


def eventually(predicate, timeout=15):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        result = predicate()
        if result:
            return result
        time.sleep(.3)
    raise AssertionError('Guest did not reach expected state')


def clients():
    return json.loads(guest('ui-session', 'hyprctl', 'clients', '-j').stdout)


def ready():
    return guest('ui-session', 'event-horizon', 'ipc', 'call', 'design', 'status', check=False).returncode == 0


class EventHorizonIntegration(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        eventually(lambda: guest('hostname', check=False).stdout.strip() == 'ui-test', 180)
        eventually(ready, 60)
        cls.evidence = vm['STATE'] / 'evidence'
        cls.evidence.mkdir(exist_ok=True)

    def tearDown(self):
        ipc('close')
        eventually(lambda: not status()['closing'])

    def test_01_session_services_and_wallpaper(self):
        guest('systemctl', '--user', 'is-active', 'event-horizon', 'waybar', 'swayosd')
        for service in ['ags', 'swaync']:
            self.assertNotEqual(guest('systemctl', '--user', 'is-active', service, check=False).returncode, 0)
        self.assertEqual(guest('ui-session', 'hyprctl', 'configerrors').stdout.strip(), '')
        self.assertEqual(guest('pgrep', '-x', 'mpv', check=False).returncode, 1)
        target = guest('readlink', '-f', '/home/ui/.local/state/current-wallpaper').stdout.strip()
        self.assertTrue(target.endswith('/event-horizon.png'), target)
        for family in ['Sansation', 'ForestSmooth']:
            self.assertIn(family.lower(), guest('fc-match', '-f', '%{family}', family).stdout.lower())

    def test_02_keyboard_open_and_escape(self):
        vm['key']('super-r')
        eventually(lambda: status()['opened'] and not status()['opening'])
        self.assertEqual(status()['page'], 'launcher')
        self.assertEqual(status()['timing'], {'open': 1200, 'close': 700})
        vm['screenshot'](self.evidence / 'launcher-verified.png')
        vm['key']('esc')
        eventually(lambda: not status()['opened'] and not status()['closing'])

    def test_03_notification_server_and_shortcuts(self):
        guest('ui-session', 'notify-send', '-a', 'EventHorizonTest', 'Integration notification', 'Real session bus')
        eventually(lambda: any(n['app'] == 'EventHorizonTest' for n in status()['session']['notifications']))
        vm['key']('super-n')
        eventually(lambda: status()['opened'] and not status()['opening'])
        self.assertEqual(status()['page'], 'notifications')
        vm['screenshot'](self.evidence / 'notifications-verified.png')
        # Close exclusive keyboard focus before invoking the compositor shortcut.
        ipc('close')
        eventually(lambda: not status()['closing'])
        vm['key']('super-shift-n')
        eventually(lambda: not status()['session']['notifications'])

    def test_04_launcher_app_survives_shell_restart(self):
        previous = {c['address'] for c in clients()}
        opened = None
        try:
            vm['key']('super-r')
            eventually(lambda: status()['opened'] and not status()['opening'])
            vm['type_text']('kitty')
            eventually(lambda: status()['session']['query'] == 'kitty' and status()['session']['search'])
            vm['key']('ret')
            opened = eventually(lambda: next((c['address'] for c in clients() if c['class'] == 'kitty' and c['address'] not in previous), None))
            guest('systemctl', '--user', 'restart', 'event-horizon')
            eventually(ready)
            self.assertIn(opened, {c['address'] for c in clients()})
        finally:
            if opened:
                guest('ui-session', 'hyprctl', 'dispatch', 'closewindow', 'address:' + opened)

    def test_05_native_connection_panels(self):
        previous = {c['address'] for c in clients()}
        for kind in ['wifi', 'bluetooth']:
            ipc('open', kind)
            eventually(lambda: status()['opened'] and not status()['opening'])
            state = eventually(lambda: (value if (value := status()['radios'][kind]).get('available') else None))
            self.assertTrue(state['available'], state)
            self.assertIn('adapter', state)
            # Unrelated autostart apps may appear while the VM finishes booting.
            external_settings = [c for c in clients() if c['address'] not in previous and
                any(name in c['class'].lower() for name in ['blueman', 'nm-connection-editor', 'nm-applet'])]
            self.assertEqual(external_settings, [])
            vm['screenshot'](self.evidence / (kind + '-verified.png'))

    def test_06_wallpaper_choice_survives_activation(self):
        original = guest('readlink', '-f', '/home/ui/.local/state/current-wallpaper').stdout.strip()
        alternate = '/home/ui/Pictures/static/default.png'
        try:
            guest('ui-session', 'wallpaper-set', alternate)
            guest('sudo', 'systemctl', 'restart', 'home-manager-ui.service')
            self.assertEqual(guest('readlink', '-f', '/home/ui/.local/state/current-wallpaper').stdout.strip(), alternate)
        finally:
            guest('ui-session', 'wallpaper-set', original)

    def test_07_bar_toggle(self):
        def bar_visible():
            return vm['layer_visible']('emerald-bar')
        self.assertTrue(bar_visible())
        vm['key']('super-b')
        eventually(lambda: not bar_visible())
        vm['key']('super-b')
        eventually(bar_visible)
        self.assertEqual(guest('systemctl', '--user', 'show', 'event-horizon', '-p', 'NRestarts', '--value').stdout.strip(), '0')

    def test_08_power_menu_and_super_w(self):
        vm['key']('super-w')
        eventually(lambda: status()['opened'] and not status()['opening'])
        self.assertEqual(status()['page'], 'launcher')
        ipc('open','power')
        eventually(lambda: not status()['opening'])
        p=status()['panel']; scale=status()['scale']
        vm['pointer'](int(p['x']+815*scale),int(p['y']+454*scale),'left')
        vm['screenshot'](self.evidence/'power-confirmation.png')
        # Escape leaves the confirmation without issuing any power command.
        vm['key']('esc');eventually(lambda:not status()['opened'])
        self.assertEqual(guest('hostname').stdout.strip(),'ui-test')

    def test_09_wallpaper_hover_cancel_enter_and_animation(self):
        original=guest('readlink','-f','/home/ui/.local/state/current-wallpaper').stdout.strip()
        old_lock=guest('readlink','-f','/home/ui/.local/state/current-lock-wallpaper').stdout.strip()
        def open_gallery(kind):
            ipc('open',kind)
            eventually(lambda:status()['opened'] and not status()['opening'])
            eventually(lambda:len(status()['wallpapers']['items'])>0)
        def hover_first():
            p=status()['panel'];scale=status()['scale']
            vm['pointer'](int(p['x']+710*scale),int(p['y']+323*scale))
            return eventually(lambda:status()['wallpapers'].get('preview'))
        try:
            # The fixture is a real video, decoded by mpvpaper in the guest.
            guest('sh','-c','mkdir -p ~/Pictures/animated; ffmpeg -v error -y -f lavfi -i color=c=0x153b2c:s=640x360:r=15 -t 2 -threads 1 ~/Pictures/animated/test-orbit.mp4')
            open_gallery('wallpapers');hover_first()
            self.assertEqual(guest('readlink','-f','/home/ui/.local/state/current-wallpaper').stdout.strip(),original)
            self.assertEqual(guest('readlink','-f','/home/ui/.local/state/current-lock-wallpaper').stdout.strip(),old_lock)
            vm['key']('esc');eventually(lambda:not status()['wallpapers'].get('preview'))
            self.assertEqual(guest('test','-e','/home/ui/.local/state/event-horizon/wallpaper-preview.json',check=False).returncode,1)
            open_gallery('wallpapers');hover_first();vm['key']('ret')
            eventually(lambda:not status()['opened'])
            self.assertTrue(guest('readlink','-f','/home/ui/.local/state/current-wallpaper').stdout.strip().endswith('/default.png'))
            open_gallery('animated');hover_first()
            self.assertTrue(guest('pgrep','-f','mpvpaper.*test-orbit.mp4',check=False).stdout.strip())
            vm['key']('esc');eventually(lambda:not status()['wallpapers'].get('preview'))
            self.assertTrue(guest('readlink','-f','/home/ui/.local/state/current-wallpaper').stdout.strip().endswith('/default.png'))
            open_gallery('animated');hover_first();vm['key']('ret')
            eventually(lambda:not status()['opened'])
            self.assertTrue(guest('readlink','-f','/home/ui/.local/state/current-wallpaper').stdout.strip().endswith('/test-orbit.mp4'))
            guest('systemctl','--user','is-active','animated-wallpaper')
        finally:
            ipc('close');guest('ui-session','wallpaper-set',original)
            guest('rm','-f','/home/ui/Pictures/animated/test-orbit.mp4')

    def test_10_user_bus_notifications_mpris_and_application_palette(self):
        wrapper=guest('sh','-c','cat $(readlink -f /etc/profiles/per-user/ui/bin/event-horizon)').stdout
        python=re.search(r'/nix/store/[a-z0-9-]+-python3-[0-9.]+-env/bin',wrapper).group()+'/python3'
        typelib=re.search(r'/nix/store/[a-z0-9-]+-glib-[0-9.]+/lib/girepository-1.0',wrapper).group()
        manager=guest('systemctl','--user','show-environment').stdout
        self.assertIn('DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus',manager)
        # A service launched from a desktop terminal and the shell see the same bus.
        guest('ui-session','notify-send','-a','BusTest','Unified session bus')
        eventually(lambda:any(n['app']=='BusTest' for n in status()['session']['notifications']))
        gtk=guest('cat','/home/ui/.config/gtk-3.0/settings.ini').stdout
        self.assertIn('Sansation',gtk)
        browser=guest('sh','-c','cat ~/.floorp/*/chrome/userChrome.css 2>/dev/null || cat ~/.librewolf/*/chrome/userChrome.css').stdout
        self.assertIn('66cea3',browser.lower())
        fixture=vm['STATE']/'control/mpris-fixture.py'
        shutil.copyfile(Path(__file__).parent/'fixtures/event_horizon_mpris.py',fixture)
        guest('systemd-run','--user','--unit=eh-mpris-test','--property=Type=exec',
            'ui-session','env','GI_TYPELIB_PATH='+typelib,python,'/mnt/ui-vm-control/mpris-fixture.py')
        try:
            eventually(lambda:status().get('nativePlayer')=='MPRIS integration')
            self.assertTrue(status()['audio']['playing'])
            self.assertIn('Emerald',status()['audio']['title'])
            ipc('close');eventually(lambda:not status()['closing'])
            guest('ui-session','hyprctl','dispatch','workspace','9')
            eventually(lambda:status()['animation']['desktopVisible'])
            controls=status()['mediaControls'];scale=controls['scale']
            def click_control(x):
                vm['pointer'](int((controls['x']+x)*scale),int((controls['y']+30)*scale),'left')
            click_control(86);eventually(lambda:not status()['audio']['playing'])
            click_control(86);eventually(lambda:status()['audio']['playing'])
            click_control(206);eventually(lambda:status()['audio']['title'].startswith('Next'))
            click_control(22);eventually(lambda:status()['audio']['title'].startswith('Previous'))
            click_control(150);eventually(lambda:not status()['audio']['playing'])
            click_control(86);eventually(lambda:status()['audio']['playing'])
            bar=status()['bar']
            vm['pointer'](int(2560-6-bar['width']+8+57*bar['scale']),int(8+14*bar['scale']),'left')
            eventually(lambda:status()['audio']['title'].startswith('Next'))
            vm['screenshot'](self.evidence/'desktop-media-controls.png')
        finally:
            guest('systemctl','--user','stop','eh-mpris-test')
        eventually(lambda:status().get('nativePlayer') is None)

    def test_11_kitty_clipboard_paste(self):
        previous={c['address'] for c in clients()};opened=None
        try:
            guest('ui-session','sh','-c',"printf 'clipboard-test-кириллица' | wl-copy >/dev/null 2>&1")
            guest('systemd-run','--user','--unit=eh-clipboard-test','--property=Type=exec','ui-session','kitty','--hold','sh','-c',
                'IFS= read -r line; printf "%s" "$line" > /tmp/eh-clipboard-result')
            opened=eventually(lambda:next((c['address'] for c in clients() if c['class']=='kitty' and c['address'] not in previous),None))
            guest('ui-session','hyprctl','dispatch','focuswindow','address:'+opened)
            vm['key']('ctrl-shift-v');vm['key']('ret')
            eventually(lambda:guest('cat','/tmp/eh-clipboard-result',check=False).stdout=='clipboard-test-кириллица')
        finally:
            if opened:guest('ui-session','hyprctl','dispatch','closewindow','address:'+opened)
            guest('rm','-f','/tmp/eh-clipboard-result')


    def test_12_long_wallpaper_selection_and_enter(self):
        original=guest('readlink','-f','/home/ui/.local/state/current-wallpaper').stdout.strip()
        try:
            guest('sh','-c','mkdir -p ~/Pictures/animated; ffmpeg -v error -y -f lavfi -i color=c=0x153b2c:s=640x360:r=15 -t 2 -threads 1 ~/Pictures/animated/stress-a.mp4; cp ~/Pictures/animated/stress-a.mp4 ~/Pictures/animated/stress-b.mp4')
            guest('ui-session','hyprctl','dispatch','workspace','9')
            for kind in ['wallpapers','animated']:
                ipc('open',kind);eventually(lambda:status()['opened'] and not status()['opening'])
                eventually(lambda:len([x for x in status()['wallpapers']['items'] if x['kind']==('static' if kind=='wallpapers' else 'animated')])>=2)
                # Move the pointer outside the gallery so keyboard focus stays put.
                vm['pointer'](1900,1100)
                for i in range(80):
                    vm['key']('right' if i%2==0 else 'left');time.sleep(.30)
                vm['key']('right');time.sleep(.6)
                preview=eventually(lambda:status()['wallpapers'].get('preview'))
                chosen=next(x['path'] for x in status()['wallpapers']['items'] if x['id']==preview)
                vm['key']('ret')
                eventually(lambda:not status()['opened'],30)
                self.assertEqual(guest('readlink','-f','/home/ui/.local/state/current-wallpaper').stdout.strip(),chosen)
                self.assertFalse(status()['wallpapers'].get('error'))
                eventually(lambda:not status()['closing'])
            self.assertEqual(guest('systemctl','--user','show','event-horizon','-p','NRestarts','--value').stdout.strip(),'0')
        finally:
            ipc('close');guest('ui-session','wallpaper-set',original)
            guest('rm','-f','/home/ui/Pictures/animated/stress-a.mp4','/home/ui/Pictures/animated/stress-b.mp4')

    def test_13_timer_sound_reaches_audio_output(self):
        import struct
        import wave
        capture=vm['STATE']/'control/timer-capture.wav'
        guest('systemd-run','--user','--unit=eh-timer-capture','ui-session','parec','--device=@DEFAULT_MONITOR@','--format=s16le','--rate=24000','--channels=1','--file-format=wav','/mnt/ui-vm-control/timer-capture.wav')
        try:
            time.sleep(.5);command('timer_start',seconds=1)
            eventually(lambda:status()['session']['timer']['status']=='finished')
            time.sleep(4)
        finally:
            guest('systemctl','--user','stop','eh-timer-capture')
            command('timer_reset')
        with wave.open(str(capture)) as sound:
            samples=struct.unpack('<'+'h'*sound.getnframes(),sound.readframes(sound.getnframes()))
            self.assertGreater(max(map(abs,samples)),500)
        shutil.copyfile(capture,self.evidence/'timer-output.wav')


if __name__ == '__main__':
    unittest.main(verbosity=2)
