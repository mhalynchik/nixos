"""Event Horizon integration in the ui-test VM with programs.eventHorizon=true.

Run sequentially: UI_VM_STATE=... python3 tests/event_horizon_vm.py.
Uses a disposable guest: launches apps, sends notifications, restarts the shell
and Home Manager, and temporarily changes wallpaper. Never targets the host.
"""
import json
import os
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



def confirm_power(operation):
    ipc('selectPage','power');eventually(lambda:status()['opened'] and not status()['opening'])
    panel=status()['panel'];scale=status()['scale']
    row=['lock','suspend','logout','reboot','poweroff'].index(operation)
    vm['pointer'](int(panel['x']+815*scale),int(panel['y']+(210+66*row)*scale),'left')
    if operation!='lock':
        vm['pointer'](int(panel['x']+725*scale),int(panel['y']+602*scale),'left')


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
        vm['pointer'](int(p['x']+815*scale),int(p['y']+406*scale),'left')
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
            vm['pointer'](int(p['x']+710*scale),int(p['y']+275*scale))
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
                vm['pointer'](int(controls['x']+x*scale),int(controls['y']+30*scale),'left')
            click_control(86);eventually(lambda:not status()['audio']['playing'])
            click_control(86);eventually(lambda:status()['audio']['playing'])
            click_control(150);eventually(lambda:status()['audio']['title'].startswith('Next'))
            click_control(22);eventually(lambda:status()['audio']['title'].startswith('Previous'))
            # Input regions must follow ancestor movement and scaling, not only
            # the local coordinates of the media buttons.
            layout=status()['session']['layout'];widgets=json.loads(json.dumps(layout['defaults']))
            widgets['media'].update(x=.32,y=.65,scale=.8)
            command('layout_save',monitor=status()['screen'],wallpaper=layout['wallpaper'],widgets=widgets)
            eventually(lambda:status()['layoutWidgets']['media']['scale']==.8)
            controls=status()['mediaControls'];scale=controls['scale']
            click_control(86);eventually(lambda:not status()['audio']['playing'])
            click_control(86);eventually(lambda:status()['audio']['playing'])
            bar=status()['bar']
            point=next(b for b in bar['buttons'] if b['id']=='next')
            # The tooltip must stay outside the island, including after a long
            # hover; an in-window popup used to cover and swallow this click.
            vm['pointer'](int(point['x']),int(point['y']))
            time.sleep(.65)
            vm['pointer'](int(point['x']),int(point['y']),'left')
            eventually(lambda:status()['audio']['title'].startswith('Next'))
            vm['screenshot'](self.evidence/'desktop-media-controls.png')
        finally:
            layout=status()['session']['layout']
            command('layout_reset',monitor=status()['screen'],wallpaper=layout['wallpaper'])
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


    def test_14_orbit_and_bar_navigation(self):
        ipc('selectPage','launcher');eventually(lambda:status()['opened'] and not status()['opening'])
        self.assertEqual([x['page'] for x in status()['nav']],['launcher','agenda','wallpapers','animated','settings'])
        # Real orbit clicks cross the 0/360 seam in both directions.
        for page in ['settings','launcher','agenda','wallpapers','animated']:
            before=status()['orbit']['angle']
            point=next(x['point'] for x in status()['nav'] if x['page']==page)
            vm['pointer'](int(point['x']),int(point['y']),'left')
            eventually(lambda:status()['page']==page)
            self.assertLessEqual(abs(status()['orbit']['target']-before),180.1)
            eventually(lambda:not status()['orbit']['rotating'])
            self.assertTrue(status()['opened'])
        # The top strip keeps the overlay open, including repeated tab clicks.
        self.assertLess(status()['bar']['width'],750)
        for page in ['wifi','bluetooth','media','notifications','overview','timer','system','power']:
            for _ in range(2):
                point=next(b for b in status()['bar']['buttons'] if b['id']==page)
                vm['pointer'](int(point['x']),int(point['y']),'left')
                eventually(lambda:status()['opened'] and status()['page']==page)
                self.assertFalse(status()['opening'])
        # The actual Waybar launcher also selects without collapsing the overlay.
        for _ in range(2):
            vm['pointer'](26,22,'left')
            eventually(lambda:status()['opened'] and status()['page']=='launcher')
            self.assertFalse(status()['opening'])
        ipc('selectPage','agenda');eventually(lambda:not status()['orbit']['rotating'])
        vm['screenshot'](self.evidence/'orbit-navigation.png')
        vm['key']('alt-4');eventually(lambda:status()['page']=='animated')
        vm['key']('esc');eventually(lambda:not status()['opened'])

    def test_15_lock_from_service_and_unlock(self):
        # Lock through the same service-backed command as the power panel.
        # Authentication uses the disposable VM's known password, never the host.
        ident=guest('loginctl','show-user','ui','--property=Display','--value').stdout.strip()
        self.assertEqual(guest('loginctl','show-session',ident,'--property=Class','--value').stdout.strip(),'user')
        ipc('selectPage','power');eventually(lambda:status()['opened'] and not status()['opening'])
        p=status()['panel'];scale=status()['scale']
        vm['pointer'](int(p['x']+815*scale),int(p['y']+210*scale),'left')
        eventually(lambda:guest('pgrep','-x','hyprlock',check=False).returncode==0)
        time.sleep(2)
        vm['screenshot'](self.evidence/'lock-screen.png')
        guest('systemctl','--user','restart','event-horizon');eventually(ready)
        self.assertEqual(guest('pgrep','-x','hyprlock',check=False).returncode,0)
        vm['key']('u');time.sleep(.15);vm['key']('i');time.sleep(.15);vm['key']('ret')
        eventually(lambda:guest('pgrep','-x','hyprlock',check=False).returncode!=0)
        self.assertFalse(status()['opened'])
        self.assertFalse(status()['session']['error'])

    def test_16_application_drawer_entry_points(self):
        def drawer_visible():
            outputs=json.loads(guest('ui-session','hyprctl','layers','-j').stdout)
            return any(layer.get('namespace')=='nwg-drawer' for monitor in outputs.values() for layers in monitor['levels'].values() for layer in layers)
        # Wait for a mapped window, not just a process loading app icons.
        ipc('selectPage','launcher');eventually(lambda:status()['opened'] and not status()['opening'])
        vm['key']('super-a');eventually(drawer_visible)
        self.assertFalse(status()['opened'])
        time.sleep(.4);vm['screenshot'](self.evidence/'application-drawer.png')
        vm['key']('esc');eventually(lambda:not drawer_visible())
        ipc('selectPage','launcher');eventually(lambda:status()['opened'] and not status()['opening'])
        p=status()['panel'];scale=status()['scale']
        vm['pointer'](int(p['x']+855*scale),int(p['y']+87*scale),'left')
        eventually(drawer_visible)
        self.assertFalse(status()['opened']);vm['key']('esc')
        eventually(lambda:not drawer_visible())

    def test_17_logout_returns_to_login_without_reboot(self):
        boot=guest('cat','/proc/sys/kernel/random/boot_id').stdout
        old_idle=guest('pgrep','-x','hypridle').stdout.strip()
        guest('sudo','rm','-f','/var/cache/tuigreet/lastuser')
        confirm_power('logout')
        eventually(lambda:guest('pgrep','-x','tuigreet',check=False).returncode==0)
        eventually(lambda:guest('pgrep','-f','^/run/current-system/sw/bin/Hyprland( |$)',check=False).returncode!=0)
        self.assertEqual(guest('cat','/proc/sys/kernel/random/boot_id').stdout,boot)
        # Virtio GL may have no QMP framebuffer at the text greeter.
        (self.evidence/'logged-out.txt').write_text(guest('loginctl','list-sessions','--no-pager').stdout+guest('pgrep','-a','tuigreet').stdout)
        for key in ['u','i','ret','u','i','ret']:
            vm['key'](key);time.sleep(.25)
        eventually(ready,40)
        new_idle=eventually(lambda:guest('pgrep','-x','hypridle',check=False).stdout.strip(),40)
        self.assertNotEqual(new_idle,old_idle)
        ident=guest('loginctl','show-user','ui','--property=Display','--value').stdout.strip()
        self.assertEqual(guest('loginctl','show-session',ident,'--property=Class','--value').stdout.strip(),'user')

    @unittest.skipUnless(os.environ.get('UI_VM_TEST_SUSPEND')=='1','Opt-in: QEMU and firmware must support S3 resume')
    def test_18_suspend_locks_and_resumes_same_session(self):
        compositor=guest('pgrep','-f','^/run/current-system/sw/bin/Hyprland( |$)').stdout.strip()
        def sleeping():
            with vm['QMP']() as qmp:return qmp.execute('query-status')['status']=='suspended'
        confirm_power('suspend')
        try:
            eventually(sleeping,25)
        finally:
            if sleeping():
                with vm['QMP']() as qmp:qmp.execute('system_wakeup')
        eventually(ready,40)
        self.assertEqual(guest('pgrep','-f','^/run/current-system/sw/bin/Hyprland( |$)').stdout.strip(),compositor)
        eventually(lambda:guest('pgrep','-x','hyprlock',check=False).returncode==0)
        time.sleep(1);vm['screenshot'](self.evidence/'resumed-locked.png')
        for key in ['u','i','ret']:
            vm['key'](key);time.sleep(.2)
        eventually(lambda:guest('pgrep','-x','hyprlock',check=False).returncode!=0)

    def test_20_idle_preferences_and_clock(self):
        previous=status()['session']['idle']
        runtime='/run/user/1000/event-horizon/hypridle.conf'
        try:
            ipc('selectPage','launcher');eventually(lambda:not status()['opening'])
            point=next(x['point'] for x in status()['nav'] if x['page']=='settings')
            vm['pointer'](int(point['x']),int(point['y']),'left')
            eventually(lambda:status()['page']=='settings' and not status()['orbit']['rotating'])
            panel=status()['panel'];scale=status()['scale']
            for y,value in [(204,'20'),(299,'45'),(394,'60')]:
                vm['pointer'](int(panel['x']+950*scale),int(panel['y']+y*scale),'left');time.sleep(.25)
                vm['key']('ctrl-a');time.sleep(.25)
                for key in value:
                    vm['key'](key);time.sleep(.25)
            vm['pointer'](int(panel['x']+706*scale),int(panel['y']+556*scale),'left')
            expected=dict(lockMinutes=20,screenMinutes=45,suspendMinutes=60)
            eventually(lambda:status()['session']['idle']==expected)
            guest('systemctl','--user','is-active','hypridle')
            config=guest('cat',runtime).stdout
            for seconds in [1200,2700,3600]:self.assertIn(f'timeout = {seconds}',config)
            guest('systemctl','--user','restart','event-horizon')
            eventually(ready)
            eventually(lambda:status()['session'].get('idle')==expected)
            guest('systemctl','--user','restart','hypridle')
            self.assertEqual(guest('cat',runtime).stdout,config)
            ipc('selectPage','settings');eventually(lambda:not status()['opening'])
            time.sleep(.4)
            vm['screenshot'](self.evidence/'idle-settings.png')
            command('idle_settings',lockMinutes=0,screenMinutes=0,suspendMinutes=0)
            eventually(lambda:status()['session']['idle']['lockMinutes']==0)
            config=guest('cat',runtime).stdout
            self.assertNotIn('systemctl suspend',config)
            self.assertEqual(config.count('listener {'),1)
            self.assertIn('before_sleep_cmd',config)
            command('idle_settings',lockMinutes=40,screenMinutes=5,suspendMinutes=0)
            eventually(lambda:bool(status()['session']['error']))
            self.assertEqual(status()['session']['idle'],dict(lockMinutes=0,screenMinutes=0,suspendMinutes=0))
            point=next(b for b in status()['bar']['buttons'] if b['id']=='timer')
            self.assertRegex(point['label'],r'^\d{2}:\d{2}$')
            self.assertEqual(point['icon'],'')
            vm['pointer'](int(point['x']),int(point['y']),'left')
            eventually(lambda:status()['page']=='timer')
            command('timer_start',seconds=120)
            eventually(lambda:status()['session']['timer']['status']=='running')
            self.assertRegex(next(b for b in status()['bar']['buttons'] if b['id']=='timer')['label'],r'^\d{2}:\d{2}$')
        finally:
            command('idle_settings',**previous)
            command('timer_reset')

    def test_21_microphone_icon_with_monitor_default(self):
        # A guest-only ALSA dummy card supports mute, unlike a remapped monitor.
        previous=guest('ui-session','pactl','get-default-source').stdout.strip()
        guest('sudo','modprobe','snd-dummy')
        def sources():return json.loads(guest('ui-session','pactl','-f','json','list','sources').stdout)
        microphone=eventually(lambda:next((x['name'] for x in sources() if x['name'].startswith('alsa_input.platform-snd_dummy')),None))
        monitor=next(x['name'] for x in sources() if 'snd_dummy' in x['name'] and x['name'].endswith('.monitor'))
        card=next(x for x in json.loads(guest('ui-session','pactl','-f','json','list','cards').stdout) if 'snd_dummy' in x['name'])
        try:
            guest('ui-session','pactl','set-default-source',monitor)
            eventually(lambda:status()['session']['audio']['defaultSource']==microphone)
            def button():return next(b for b in status()['bar']['buttons'] if b['id']=='microphone')
            for muted,icon in [('0','microphone'),('1','mic-muted'),('0','microphone')]:
                guest('ui-session','pactl','set-source-mute',microphone,muted)
                eventually(lambda:button()['icon']==icon)
                self.assertEqual(button()['selected'],muted=='0')
            monitor_mute=guest('ui-session','pactl','get-source-mute',monitor).stdout
            point=button();vm['pointer'](int(point['x']),int(point['y']),'left')
            eventually(lambda:button()['icon']=='mic-muted')
            self.assertIn('yes',guest('env','LC_ALL=C','pactl','get-source-mute',microphone).stdout)
            self.assertEqual(guest('ui-session','pactl','get-source-mute',monitor).stdout,monitor_mute)
            guest('ui-session','pactl','set-card-profile',card['name'],'off')
            eventually(lambda:not status()['session']['audio']['defaultSource'])
            self.assertEqual(button()['icon'],'mic-muted')
            self.assertFalse(button()['selected'])
            serial=status()['session']['serial']
            point=button();vm['pointer'](int(point['x']),int(point['y']),'left');time.sleep(.4)
            self.assertEqual(status()['session']['serial'],serial)
            self.assertFalse(status()['session']['error'])
            vm['screenshot'](self.evidence/'microphone-disconnected.png')
        finally:
            guest('ui-session','pactl','set-card-profile',card['name'],card['active_profile'])
            eventually(lambda:any(x['name']==microphone for x in sources()))
            guest('ui-session','pactl','set-source-mute',microphone,'0')
            eventually(lambda:next(b for b in status()['bar']['buttons'] if b['id']=='microphone')['icon']=='microphone')
            if any(x['name']==previous for x in sources()):
                guest('ui-session','pactl','set-default-source',previous)

    def test_23_clock_outline_tracks_timer(self):
        def button():return next(b for b in status()['bar']['buttons'] if b['id']=='timer')
        try:
            command('timer_reset');eventually(lambda:button()['progress']==-1)
            command('timer_start',seconds=12)
            eventually(lambda:button()['progress']>.7)
            self.assertRegex(button()['label'],r'^\d{2}:\d{2}$')
            eventually(lambda:0<button()['progress']<.7)
            command('timer_pause');eventually(lambda:status()['session']['timer']['status']=='paused')
            progress=button()['progress'];time.sleep(1.2)
            self.assertEqual(button()['progress'],progress)
            vm['screenshot'](self.evidence/'clock-timer-outline.png')
            point=button();vm['pointer'](int(point['x']),int(point['y']),'left')
            eventually(lambda:status()['page']=='timer' and not status()['opening'])
            self.assertEqual(button()['progress'],progress)
            command('timer_resume')
            eventually(lambda:status()['session']['timer']['status']=='finished',20)
            self.assertEqual(button()['progress'],-1)
            command('timer_start',seconds=300);eventually(lambda:button()['progress']>.95)
            command('timer_reset');eventually(lambda:button()['progress']==-1)
        finally:
            command('timer_reset')

    def test_24_radio_highlights_reflect_power_not_open_page(self):
        for page in ['wifi','bluetooth']:
            ipc('selectPage',page);eventually(lambda:status()['page']==page and not status()['opening'])
            current=status();radio=current['radios'][page]
            expected=bool(radio.get('enabled')) if page=='bluetooth' else bool(radio.get('adapter') and radio.get('enabled') and radio.get('hardwareEnabled'))
            self.assertEqual(next(b for b in current['bar']['buttons'] if b['id']==page)['selected'],expected)

    def test_25_wifi_power_highlight_with_simulated_radio(self):
        # Kernel radio simulation is guest-only; no host adapter is changed.
        guest('sudo','modprobe','mac80211_hwsim')
        eventually(lambda:status()['radios']['wifi']['adapter'])
        previous=status()['radios']['wifi']['enabled']
        try:
            guest('ui-session','nmcli','radio','wifi','on')
            eventually(lambda:status()['radios']['wifi']['enabled'])
            ipc('selectPage','wifi');eventually(lambda:not status()['opening'])
            panel=status()['panel'];scale=status()['scale']
            for enabled in [False,True]:
                vm['pointer'](int(panel['x']+833*scale),int(panel['y']+145*scale),'left')
                eventually(lambda:status()['radios']['wifi']['enabled']==enabled)
                current=status()
                self.assertEqual(next(b for b in current['bar']['buttons'] if b['id']=='wifi')['selected'],enabled)
                self.assertTrue(current['opened'])
        finally:
            guest('ui-session','nmcli','radio','wifi','on' if previous else 'off')

    def test_22_configured_idle_timeout_locks_and_unlocks(self):
        previous=status()['session']['idle']
        try:
            command('idle_settings',lockMinutes=1,screenMinutes=0,suspendMinutes=0)
            eventually(lambda:status()['session']['idle']['lockMinutes']==1)
            ipc('close');vm['pointer'](1000,900)
            time.sleep(3)
            self.assertNotEqual(guest('pgrep','-x','hyprlock',check=False).returncode,0)
            eventually(lambda:guest('pgrep','-x','hyprlock',check=False).returncode==0,75)
            time.sleep(2)
            for key in ['u','i','ret']:
                vm['key'](key);time.sleep(.25)
            eventually(lambda:guest('pgrep','-x','hyprlock',check=False).returncode!=0)
        finally:
            command('idle_settings',**previous)

    def test_19_before_sleep_locks_from_user_service(self):
        # Exercise the actual Hypridle hook without a hardware suspend cycle.
        config=guest('cat','/home/ui/.config/hypr/hypridle.conf').stdout
        hook=next(line.split('=',1)[1].strip() for line in config.splitlines() if line.strip().startswith('before_sleep_cmd='))
        guest('systemd-run','--user','--wait','--collect','--unit=eh-test-before-sleep','/bin/sh','-c',hook)
        eventually(lambda:guest('pgrep','-x','hyprlock',check=False).returncode==0)
        time.sleep(2)  # Wait for Hyprlock's initial animation/input readiness.
        for key in ['u','i','ret']:
            vm['key'](key);time.sleep(.2)
        eventually(lambda:guest('pgrep','-x','hyprlock',check=False).returncode!=0)


    def test_26_fullscreen_bar_and_maximized_recovery(self):
        ipc('close');eventually(lambda:not status()['closing'])
        guest('ui-session','hyprctl','dispatch','workspace','9')
        guest('ui-session','hyprctl','dispatch','exec','kitty --class eh-fullscreen-test')
        address=eventually(lambda:next((c['address'] for c in clients() if c['class']=='eh-fullscreen-test'),None))
        try:
            guest('ui-session','hyprctl','dispatch','focuswindow','address:'+address)
            for cycle in range(3):
                guest('ui-session','hyprctl','dispatch','fullscreen','0')
                eventually(lambda:status()['animation']['fullscreen'])
                if cycle==0:vm['screenshot'](self.evidence/'fullscreen-bar-hidden.png')
                guest('ui-session','hyprctl','dispatch','workspace','8')
                eventually(lambda:not status()['animation']['fullscreen'])
                guest('ui-session','hyprctl','dispatch','workspace','9')
                eventually(lambda:status()['animation']['fullscreen'])
                guest('ui-session','hyprctl','dispatch','fullscreen','0')
                eventually(lambda:not status()['animation']['fullscreen'])
            vm['screenshot'](self.evidence/'fullscreen-bar-restored.png')
            guest('ui-session','hyprctl','dispatch','fullscreen','1')
            eventually(lambda:next(c for c in clients() if c['address']==address)['fullscreen']==1)
            self.assertFalse(status()['animation']['fullscreen'])
            vm['screenshot'](self.evidence/'maximized-bar-visible.png')
        finally:
            guest('ui-session','hyprctl','dispatch','closewindow','address:'+address)

    def test_27_escape_from_controls_and_flush_menu(self):
        for page in ['launcher','media','timer','settings','power','wifi','bluetooth','notifications','agenda','system']:
            ipc('selectPage',page);eventually(lambda:status()['opened'] and not status()['opening'])
            self.assertEqual(status()['panel']['y'],40)
            # Focus a real child control; it is not a child of overlayFocus.
            vm['key']('tab');time.sleep(.2);vm['key']('esc')
            eventually(lambda:not status()['opened'] and not status()['closing'])
        ipc('selectPage','system');eventually(lambda:not status()['opening'])
        vm['screenshot'](self.evidence/'system-gpu-verified.png')

    def test_28_timer_sound_settings_and_preview(self):
        old=status()['session']['preferences']
        try:
            for key,value in [('timerVolume',41),('timerMelody','orbit'),('timerRepeats',1)]:command('setting',key=key,value=value)
            ipc('selectPage','timer');eventually(lambda:not status()['opening'])
            state=status();p=state['panel'];scale=state['scale']
            vm['pointer'](int(p['x']+810*scale),int(p['y']+643*scale),'left')
            time.sleep(.4);vm['screenshot'](self.evidence/'timer-sound-settings.png')
            command('timer_sound_preview')
            eventually(lambda:status()['session']['timerSoundPlaying'])
            command('timer_sound_stop')
            eventually(lambda:not status()['session']['timerSoundPlaying'])
            saved=json.loads(guest('cat','/home/ui/.local/state/event-horizon/desktop.json').stdout)
            self.assertEqual(saved['settings']['timerVolume'],41)
            self.assertEqual(saved['settings']['timerMelody'],'orbit')
            self.assertEqual(saved['settings']['timerRepeats'],1)
            vm['key']('tab');time.sleep(.2);vm['key']('esc');eventually(lambda:not status()['opened'])
        finally:
            command('timer_sound_stop')
            for key in ['timerVolume','timerMelody','timerRepeats']:command('setting',key=key,value=old[key])

    def test_29_blueman_authorization_lease_lifecycle(self):
        import ast
        key='/org/blueman/general/plugin-list'
        def plugins():
            raw=guest('dconf','read',key).stdout.strip()
            return ast.literal_eval(raw.removeprefix('@as ')) if raw else []
        self.assertIn('!AuthAgent',plugins())
        try:
            guest('systemctl','--user','stop','event-horizon')
            self.assertNotIn('!AuthAgent',plugins())
            guest('dconf','write',key,"['!ConnectionNotifier']")
            guest('systemctl','--user','start','event-horizon');eventually(ready)
            self.assertEqual(plugins(),['!ConnectionNotifier','!AuthAgent'])
            guest('systemctl','--user','stop','event-horizon')
            self.assertEqual(plugins(),['!ConnectionNotifier'])
        finally:
            guest('systemctl','--user','stop','event-horizon')
            guest('dconf','reset',key)
            guest('systemctl','--user','start','event-horizon');eventually(ready)

    def test_30_expansion_pages_and_notification_groups(self):
        for page in ['tools','clipboard','capture','profiles','layout']:
            ipc('selectPage',page);eventually(lambda:status()['opened'] and not status()['opening'])
            self.assertFalse(status()['session']['error'])
            vm['screenshot'](self.evidence/(page+'-expanded.png'))
            vm['key']('esc');eventually(lambda:not status()['opened'])
        command('setting',key='dnd',value=False)
        for number in range(3):
            guest('ui-session','notify-send','-a','Spotify','Track '+str(number),'Artist · Album')
        eventually(lambda:len([n for n in status()['session']['notifications'] if n['app']=='Spotify'])==1)
        for number in range(3):
            guest('ui-session','notify-send','-a','Telegram Test','Project chat','Message '+str(number))
        ipc('selectPage','notifications');eventually(lambda:not status()['opening'])
        vm['screenshot'](self.evidence/'notification-groups.png')
        command('notification_policy',app='Telegram Test',days=3,limit=20)
        self.assertEqual(status()['session']['notificationPolicies']['Telegram Test'],{'days':3,'limit':20})

    def test_31_clipboard_live_watch_pause_pin_clear(self):
        command('clipboard_clear');command('clipboard_pause',value=False)
        guest('ui-session','sh','-c',"printf 'clipboard integration alpha' | wl-copy >/dev/null 2>&1")
        item=eventually(lambda:next((n for n in status()['session']['clipboard']['items'] if n['preview']=='clipboard integration alpha'),None))
        command('clipboard_pin',id=item['id'])
        self.assertTrue(status()['session']['clipboard']['items'][0]['pinned'])
        command('clipboard_pause',value=True)
        guest('ui-session','sh','-c',"printf 'do not remember beta' | wl-copy >/dev/null 2>&1")
        time.sleep(2)
        self.assertFalse(any('beta' in n['preview'] for n in status()['session']['clipboard']['items']))
        command('clipboard_copy',id=item['id'])
        self.assertEqual(guest('ui-session','wl-paste','--no-newline').stdout,'clipboard integration alpha')
        command('clipboard_pause',value=False)
        ipc('selectPage','clipboard');eventually(lambda:not status()['opening'])
        vm['screenshot'](self.evidence/'clipboard-live.png')
        command('clipboard_clear');self.assertEqual(status()['session']['clipboard']['items'],[])

    def test_32_capture_screenshot_recording_and_cancel(self):
        outputs=[]
        try:
            command('capture_start',kind='screenshot',target='monitor',destination='file',delay=0)
            eventually(lambda:status()['session']['capture']['status']=='preparing')
            done=eventually(lambda:status()['session']['capture']['status'] in ['finished','failed'])
            cap=status()['session']['capture'];self.assertEqual(cap['status'],'finished',cap)
            outputs.append(cap['path']);self.assertGreater(int(guest('stat','-c','%s',cap['path']).stdout),1000)
            command('capture_start',kind='screenshot',target='monitor',destination='clipboard',delay=0)
            eventually(lambda:status()['session']['capture']['status']=='preparing')
            eventually(lambda:status()['session']['capture']['status'] in ['finished','failed'])
            self.assertEqual(status()['session']['capture']['status'],'finished')
            self.assertIn('image/png',guest('ui-session','wl-paste','--list-types').stdout)
            eventually(lambda:any(n['mime']=='image/png' for n in status()['session']['clipboard']['items']))
            command('capture_start',kind='recording',target='monitor',destination='file',delay=0)
            eventually(lambda:status()['session']['capture']['status'] in ['recording','failed'])
            self.assertEqual(status()['session']['capture']['status'],'recording')
            time.sleep(3);vm['screenshot'](self.evidence/'recording-indicator.png');command('capture_stop')
            eventually(lambda:status()['session']['capture']['status'] in ['finished','failed'])
            cap=status()['session']['capture'];self.assertEqual(cap['status'],'finished',cap)
            outputs.append(cap['path']);self.assertGreater(int(guest('stat','-c','%s',cap['path']).stdout),1000)
            video=json.loads(guest('ffprobe','-v','error','-show_entries','stream=codec_type,width,height','-of','json',cap['path']).stdout)
            self.assertTrue(any(x['codec_type']=='video' and x['width']>0 and x['height']>0 for x in video['streams']))
            command('capture_start',kind='screenshot',target='monitor',destination='file',delay=5);command('capture_stop')
            eventually(lambda:status()['session']['capture']['status']=='cancelled')
        finally:
            command('capture_stop')
            for path in outputs:guest('rm','-f',path)
            command('clipboard_clear')

    def test_33_layout_editor_and_persistence(self):
        ipc('selectPage','layout');eventually(lambda:not status()['opening'])
        p=status()['panel'];scale=status()['scale']
        vm['pointer'](int(p['x']+810*scale),int(p['y']+478*scale),'left')
        eventually(lambda:status()['layoutEditing']);time.sleep(1)
        vm['screenshot'](self.evidence/'widget-editor.png')
        vm['key']('esc');eventually(lambda:not status()['layoutEditing'])
        old=status()['session']['layout'];monitor=status()['screen'];wallpaper=old['wallpaper']
        widgets=json.loads(json.dumps(old['defaults']));widgets['clock']['x']=.22;widgets['media']['scale']=.8
        try:
            command('layout_save',monitor=monitor,wallpaper=wallpaper,widgets=widgets)
            eventually(lambda:status()['layoutWidgets']['clock']['x']==.22)
            guest('systemctl','--user','restart','event-horizon');eventually(ready)
            eventually(lambda:status()['layoutWidgets']['media']['scale']==.8)
        finally:command('layout_reset',monitor=monitor,wallpaper=wallpaper)

    def test_34_profiles_restore_and_cosmic_osd(self):
        command('profile_restore')
        old=status()['session'];dnd=old['preferences']['dnd']
        try:
            command('profile_apply',name='work')
            eventually(lambda:status()['session']['profiles']['active']=='work')
            self.assertTrue(status()['session']['preferences']['dnd'])
            self.assertFalse(status()['session']['profiles']['activeWidgets']['media'])
            command('profile_restore');eventually(lambda:status()['session']['profiles']['active']=='')
            self.assertEqual(status()['session']['preferences']['dnd'],dnd)
            command('quick_volume',delta=-5);eventually(lambda:status()['osd']['visible'])
            vm['screenshot'](self.evidence/'cosmic-osd.png')
        finally:
            command('profile_restore')
            sink=next((x for x in old['audio']['sinks'] if x['name']==old['audio']['defaultSink']),None)
            if sink:command('volume',group='sinks',id=sink['id'],value=min(100,sink['volume']))

    def test_35_native_notification_default_action(self):
        command('setting',key='dnd',value=False);ipc('close');eventually(lambda:not status()['closing'])
        guest('rm','-f','/tmp/eh-notification-action')
        guest('systemd-run','--user','--unit=eh-notification-action','--collect','ui-session','sh','-c',
              'notify-send --wait --expire-time=0 --app-name=ActionTest --action=default=Open "Open conversation" "Native application action" > /tmp/eh-notification-action')
        try:
            eventually(lambda:status()['toast'] and any(n['app']=='ActionTest' for n in status()['session']['notifications']))
            vm['screenshot'](self.evidence/'notification-interactive.png')
            vm['pointer'](2330,122,'left')
            eventually(lambda:'default' in guest('cat','/tmp/eh-notification-action',check=False).stdout)
        finally:
            guest('systemctl','--user','stop','eh-notification-action',check=False)

    def test_36_capture_and_timer_notification_actions(self):
        command('setting',key='dnd',value=False)
        ipc('close');eventually(lambda:not status()['closing'])
        before={c['address'] for c in clients()};path=''
        try:
            vm['pointer'](1600,800)
            command('capture_start',kind='screenshot',target='monitor',destination='file',delay=0)
            eventually(lambda:status()['session']['capture']['status']=='preparing')
            eventually(lambda:status()['session']['capture']['status']=='finished' and status()['toast'])
            path=status()['session']['capture']['path']
            time.sleep(.3)
            vm['pointer'](2330,100,'left')
            eventually(lambda:any(c['address'] not in before for c in clients()))
            ipc('close');eventually(lambda:not status()['closing'])
            vm['pointer'](1600,800)
            command('timer_start',seconds=3)
            eventually(lambda:status()['session']['timer']['status']=='running')
            eventually(lambda:status()['session']['timer']['status']=='finished' and status()['toast'])
            time.sleep(.3)
            vm['screenshot'](self.evidence/'timer-notification-action.png')
            vm['pointer'](2330,100,'left')
            eventually(lambda:status()['opened'] and status()['page']=='timer')
        finally:
            command('timer_reset');command('capture_stop')
            for c in clients():
                if c['address'] not in before:guest('ui-session','hyprctl','dispatch','closewindow','address:'+c['address'])
            if path:guest('rm','-f',path)


if __name__ == '__main__':
    unittest.main(verbosity=2)
