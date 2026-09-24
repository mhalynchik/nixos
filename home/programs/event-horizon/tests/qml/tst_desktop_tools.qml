import QtQuick
import QtTest
import "../../ui" as Shell
Item {
 width:840;height:660
 QtObject{id:api;property var session:({clipboard:{items:[],paused:false},capture:{status:'idle'}});property bool opened:true;property var calls:[]
  function t(key){return key}
  function command(name,args){calls=calls.concat([{name:name,args:args||{}}])}
  function durationText(seconds){return Math.floor(seconds/60)+':'+('0'+seconds%60).slice(-2)}
 }
 Shell.ClipboardPanel{id:clipboard;width:410;height:650;api:api}
 Shell.CapturePanel{id:capture;x:430;width:410;height:650;api:api}
 TestCase {
  name:'DesktopTools';when:windowShown
  function init(){api.calls=[];api.opened=true;api.session={clipboard:{items:[],paused:false},capture:{status:'idle'}};capture.kind='screenshot';capture.target='region';capture.delay=0;capture.destination='file'}
  function test_clipboard_pause_and_copy(){
   mouseClick(clipboard,60,70);compare(api.calls[0].name,'clipboard_pause');compare(api.calls[0].args.value,true)
   api.session={clipboard:{items:[{id:'one',mime:'text/plain',preview:'Hello',time:10,pinned:false}],paused:false},capture:{status:'idle'}}
   tryCompare(clipboard,'filtered',api.session.clipboard.items)
   clipboard.copy(clipboard.filtered[0]);compare(api.calls[1].name,'clipboard_copy');compare(api.calls[1].args.id,'one')
  }
  function test_capture_hides_menu_and_sends_selected_options(){
   capture.kind='recording';capture.target='monitor';capture.delay=3;capture.start()
   compare(api.opened,false);compare(api.calls[0].name,'capture_start');compare(api.calls[0].args.kind,'recording');compare(api.calls[0].args.target,'monitor');compare(api.calls[0].args.delay,3)
  }
  function test_recording_button_stops_instead_of_restarting(){
   api.session={clipboard:{items:[],paused:false},capture:{status:'recording',elapsed:65}}
   tryCompare(capture,'busy',true);mouseClick(capture,100,432)
   compare(api.calls[0].name,'capture_stop');compare(api.opened,true)
  }
 }
}
