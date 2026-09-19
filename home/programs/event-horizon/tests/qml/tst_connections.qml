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
 }
}
