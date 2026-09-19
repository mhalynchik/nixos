import QtQuick
import QtTest
import "../../ui" as Shell
Item {
 width:450;height:650
 QtObject {
  id:testApi
  property string page:'wifi'
  property var radios:({wifi:{adapter:true,enabled:true,networks:[{id:'/ap',name:'Test network',strength:50,security:'wpa-psk',saved:false,connected:false,hidden:false}]},bluetooth:{}})
  function radioCommand(a,b){}
  function command(a,b){}
 }
 Shell.ConnectionPanel {id:panel;anchors.fill:parent;api:testApi}
 TestCase {
  name:'ConnectionInput';when:windowShown
  function test_password_survives_signal_updates() {
   panel.visible=true;
   panel.selectedId='/ap';wait(300)
   let password=findChild(panel,'wifiPassword')
   verify(password!==null)
   password.text='user typing'
   testApi.radios={wifi:{adapter:true,enabled:true,networks:[{id:'/ap',name:'Test network',strength:60,security:'wpa-psk',saved:false,connected:false,hidden:false}]},bluetooth:{}}
   wait(300)
   compare(findChild(panel,'wifiPassword'),password)
   compare(password.text,'user typing')
   panel.visible=false;wait(50)
   compare(password.text,'')
  }
  function test_radio_controls_follow_confirmed_state() {
   panel.visible=true
   testApi.radios={wifi:{adapter:true,enabled:false,hardwareEnabled:true,canScan:false,blockedReason:'Wi-Fi выключен',networks:[]},bluetooth:{}}
   wait(20)
   compare(findChild(panel,'radioPower').text,'Включить')
   compare(findChild(panel,'radioStatus').text,'Wi-Fi выключен')
   compare(findChild(panel,'radioRefresh').enabled,false)
   testApi.radios={wifi:{adapter:true,enabled:true,hardwareEnabled:true,canScan:true,networks:[]},bluetooth:{}}
   wait(20)
   compare(findChild(panel,'radioPower').text,'Выключить')
   compare(findChild(panel,'radioRefresh').enabled,true)
   testApi.radios={wifi:{adapter:true,enabled:true,hardwareEnabled:false,canScan:false,blockedReason:'Wi-Fi заблокирован аппаратным переключателем',networks:[]},bluetooth:{}}
   wait(20)
   compare(findChild(panel,'radioPower').enabled,false)
   compare(findChild(panel,'radioRefresh').enabled,false)
  }

 }
}
