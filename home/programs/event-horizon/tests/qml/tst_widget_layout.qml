import QtQuick
import QtTest
import "../../ui" as Shell
Item {
 id:host;width:1280;height:720
 QtObject{id:api
  property var session:({layout:{profiles:{},wallpaper:'/sky.png'},profiles:{activeWidgets:{}},timer:{status:'idle',duration:1500,remaining:1500},agenda:[]})
  property var selectedScreen:({name:'DP-1'})
  property bool layoutEditing:false
  property bool opened:false
  property date now:new Date(2026,8,24)
  property real desktopPhase:0
  property real timerPulse:0
  property color accent:'#72e7bc'
  property bool reducedMotion:true
  property var audio:({title:'Music',bands:[],playing:false})
  property string mediaArtist:''
  property bool mediaAvailable:true
  property var desktopWidgets:widgets
  property var lastCommand:null
  property string selectedDate:''
  function send(action){}
  function open(page){}
  function command(action,values){lastCommand={action:action,values:values}}
 }
 Shell.DesktopWidgets{id:widgets;anchors.fill:parent;api:api}
 Shell.LayoutPanel{visible:false;width:430;height:650;api:api}
 TestCase{name:'WidgetLayout';when:windowShown
  function init(){widgets.cancel();api.lastCommand=null;widgets.wallpaperSpecific=true;api.selectedScreen={name:'DP-1'}}
  function test_edit_cancel_and_save(){
   widgets.beginEditing();verify(api.layoutEditing);verify(!api.opened)
   widgets.toggle('media');verify(!widgets.widgets.media.visible);verify(widgets.dirty)
   widgets.cancel();verify(widgets.widgets.media.visible);verify(!widgets.dirty)
   widgets.beginEditing();widgets.update('clock',{x:.3,scale:1.25});widgets.save()
   compare(api.lastCommand.action,'layout_save');compare(api.lastCommand.values.monitor,'DP-1')
   compare(api.lastCommand.values.wallpaper,'/sky.png');compare(api.lastCommand.values.widgets.clock.x,.3)
   verify(!api.layoutEditing)
  }
  function test_profile_switch_discards_draft(){
   widgets.toggle('media');verify(widgets.dirty);api.selectedScreen={name:'DP-2'}
   verify(!widgets.dirty);verify(widgets.widgets.media.visible)
   widgets.wallpaperSpecific=false;widgets.toggle('calendar');widgets.save()
   compare(api.lastCommand.values.wallpaper,'')
  }
  function test_controls_coordinate_scales_with_display(){
   verify(widgets.mediaControls.x>0);verify(widgets.mediaControls.y>0)
   compare(widgets.mediaControls.scale,.5)
   widgets.update('media',{scale:1.2});compare(widgets.mediaControls.scale,.6)
   widgets.update('media',{x:.3});compare(widgets.mediaControls.x,1280*.3+190*.6)
  }
  function test_drag_snap_and_resize(){
   widgets.beginEditing()
   let frame=findChild(widgets,'widget-clock'), drag=findChild(widgets,'drag-clock')
   verify(frame!==null);verify(drag!==null)
   let before=frame.x
   mousePress(drag,40,30);mouseMove(drag,104,62,30);mouseRelease(drag,104,62)
   verify(frame.x>before);compare(Math.round(frame.x)%16,0)
   let resize=findChild(widgets,'resize-clock'), initial=widgets.widgets.clock.scale
   mousePress(resize,14,14);mouseMove(resize,64,44,30);mouseRelease(resize,64,44)
   verify(widgets.widgets.clock.scale>initial)
   widgets.cancel()
  }
  function test_reset_is_reversible(){
   widgets.update('clock',{x:.6});widgets.reset();compare(widgets.widgets.clock.x,105/2560)
   widgets.cancel();verify(!widgets.dirty)
  }
 }
}
