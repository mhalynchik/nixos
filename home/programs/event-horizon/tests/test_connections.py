"""NetworkManager/BlueZ contracts from their public D-Bus APIs.

https://networkmanager.dev/docs/api/latest/spec.html
https://bluez.readthedocs.io/en/latest/agent-api/
Physical pairing/authentication still needs a radio device.
"""
import sys
import threading
import unittest
from pathlib import Path
from unittest.mock import Mock
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'ui/runtime'))
from connections import NM,NM_PATH,BLUEZ,Wifi,Bluetooth,security_name


class Bus:
    def __init__(self):
        self.calls=[]
        self.props={NM_PATH:{'Devices':['/wifi'],'WirelessEnabled':True,'WirelessHardwareEnabled':True},
            '/wifi':{'DeviceType':2,'Interface':'wlan0','State':100,'AvailableConnections':[]},
            '/wireless':{'AccessPoints':['/ap1','/ap2'],'ActiveAccessPoint':'/ap1'},
            '/ap1':{'Ssid':list('Дом'.encode()),'Strength':60,'RsnFlags':256},
            '/ap2':{'Ssid':list('Дом'.encode()),'Strength':90,'RsnFlags':256}}
    def properties(self,service,path,interface):
        return self.props['/wireless' if interface.endswith('Device.Wireless') else path]
    def variant(self,kind,value):return (kind,value)
    def call(self,*args,**kwargs):self.calls.append((args,kwargs));return ()
    def set(self,*args):self.calls.append((args,{}))


class RadioTests(unittest.TestCase):
    def test_security_flags(self):
        for props,result in [({},'open'),({'Flags':1},'wep'),({'RsnFlags':256},'wpa-psk'),({'RsnFlags':1024},'sae'),({'RsnFlags':512},'enterprise')]:
            self.assertEqual(security_name(props),result)

    def test_connected_ap_wins_over_stronger_duplicate(self):
        wifi=Wifi(Bus());rows=wifi.snapshot()['networks']
        self.assertEqual(len(rows),1);self.assertEqual(rows[0]['name'],'Дом');self.assertEqual(rows[0]['id'],'/ap1')

    def test_new_profile_password_is_only_in_dbus_settings(self):
        bus=Bus();wifi=Wifi(bus);wifi.execute({'action':'wifi_connect','id':'/ap2','password':'test password'})
        args=bus.calls[-1][0]
        self.assertEqual(args[3],'AddAndActivateConnection')
        self.assertEqual(args[4],'(a{sa{sv}}oo)')
        self.assertEqual(args[5][0]['802-11-wireless-security']['psk'],('s','test password'))
        self.assertNotIn('test password',str(wifi.snapshot()))

    def test_unknown_ap_does_not_connect(self):
        wifi=Wifi(Bus())
        with self.assertRaises(ValueError):wifi.execute({'action':'wifi_connect','id':'/missing','password':'x'})
        self.assertEqual(wifi.bus.calls,[])

    def test_agent_confirms_or_rejects_without_default_agent(self):
        bt=Bluetooth.__new__(Bluetooth);bt.lock=threading.Lock();bt.bus=Bus();bt.request={'kind':'RequestConfirmation'};bt.invocation=Mock()
        invocation=bt.invocation;bt.respond({'accept':True})
        invocation.return_value.assert_called_once_with(None)
        self.assertIsNone(bt.request)
        bt.request={'kind':'RequestPasskey'};bt.invocation=Mock()
        with self.assertRaises(ValueError):bt.respond({'accept':True,'value':'1000000'})
        self.assertIsNotNone(bt.request)
        bt.respond({'accept':False});self.assertIsNone(bt.request)

    def test_display_only_pairing_can_be_canceled(self):
        bt=Bluetooth.__new__(Bluetooth);bt.lock=threading.Lock();bt.bus=Bus();bt.request={'kind':'DisplayPasskey'};bt.invocation=None;bt.pairing={'/device'}
        bt.respond({'accept':False})
        self.assertIsNone(bt.request)
        self.assertEqual(bt.bus.calls[-1][0][3],'CancelPairing')

    def test_agent_rejects_unsolicited_authorization_without_a_dialog(self):
        for method,args in [('RequestAuthorization',('/device',)),('AuthorizeService',('/device','audio-service'))]:
            with self.subTest(method=method):
                bt=Bluetooth.__new__(Bluetooth);bt.lock=threading.Lock();bt.pairing=set();bt.request=None;bt.invocation=None
                invocation=Mock();parameters=Mock();parameters.unpack.return_value=args
                bt.agent_call(None,None,None,None,method,parameters,invocation)
                invocation.return_dbus_error.assert_called_once_with('org.bluez.Error.Rejected','Pairing was not requested')
                invocation.return_value.assert_not_called()
                self.assertIsNone(bt.request)

    def test_user_requested_pairing_still_requires_confirmation(self):
        bt=Bluetooth.__new__(Bluetooth);bt.lock=threading.Lock();bt.bus=Bus();bt.pairing={'/device'};bt.devices={'/device':{'name':'Headphones'}};bt.request=None;bt.invocation=None
        invocation=Mock();parameters=Mock();parameters.unpack.return_value=('/device',123456)
        bt.agent_call(None,None,None,None,'RequestConfirmation',parameters,invocation)
        self.assertEqual(bt.request['name'],'Headphones');self.assertEqual(bt.request['code'],'123456')
        invocation.return_value.assert_not_called();invocation.return_dbus_error.assert_not_called()
        bt.respond({'accept':True})
        invocation.return_value.assert_called_once_with(None)

    def test_power_off_cancels_pairing_before_disabling_every_adapter(self):
        bt=Bluetooth.__new__(Bluetooth);bt.lock=threading.Lock();bt.bus=Bus();bt.pairing={'/device'};bt.scanning={'/adapter1'}
        bt.adapters={'/adapter1':{},'/adapter2':{}};bt.snapshot=Mock();bt.request={'kind':'RequestConfirmation'};bt.invocation=Mock()
        invocation=bt.invocation
        bt.execute({'action':'bt_power','enabled':False})
        invocation.return_dbus_error.assert_called_once_with('org.bluez.Error.Canceled','Canceled by user')
        self.assertIsNone(bt.request)
        self.assertEqual([x[0][3] for x in bt.bus.calls],['CancelPairing','StopDiscovery','Powered','Powered'])
        self.assertEqual(bt.bus.calls[-2][0],(BLUEZ,'/adapter1',BLUEZ+'.Adapter1','Powered','b',False))
        self.assertEqual(bt.bus.calls[-1][0],(BLUEZ,'/adapter2',BLUEZ+'.Adapter1','Powered','b',False))

    def test_disabled_or_unavailable_wifi_never_requests_scan(self):
        for override in [{'WirelessEnabled':False},{'WirelessHardwareEnabled':False},{'NetworkingEnabled':False}]:
            bus=Bus();bus.props[NM_PATH].update(override);wifi=Wifi(bus)
            self.assertFalse(wifi.snapshot()['canScan'])
            with self.assertRaisesRegex(ValueError,'Wi-Fi|Сеть'):wifi.execute({'action':'wifi_scan'})
            self.assertEqual(bus.calls,[])
        bus=Bus();bus.props['/wifi']['State']=20;wifi=Wifi(bus)
        with self.assertRaisesRegex(ValueError,'не готов'):wifi.execute({'action':'wifi_scan'})
        self.assertEqual(bus.calls,[])

    def test_scan_skips_unavailable_second_adapter_and_throttles_repeats(self):
        bus=Bus();bus.props[NM_PATH]['Devices'].append('/wifi2')
        bus.props['/wifi2']={'DeviceType':2,'State':20};wifi=Wifi(bus)
        wifi.execute({'action':'wifi_scan'});wifi.execute({'action':'wifi_scan'})
        self.assertEqual(len(bus.calls),1);self.assertEqual(bus.calls[0][0][1],'/wifi')
        self.assertTrue(wifi.snapshot()['scanning'])
        bus.props['/wireless']['LastScan']=123
        self.assertFalse(wifi.snapshot()['scanning'])

    def test_hardware_block_does_not_claim_enable_success(self):
        bus=Bus();bus.props[NM_PATH]['WirelessHardwareEnabled']=False;wifi=Wifi(bus)
        with self.assertRaisesRegex(ValueError,'аппаратным'):wifi.execute({'action':'wifi_power','enabled':True})
        self.assertEqual(bus.calls,[])
