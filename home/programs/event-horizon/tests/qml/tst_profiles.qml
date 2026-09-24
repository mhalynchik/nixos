import QtQuick
import QtTest
import "../../ui" as Shell
Item {
 width:440;height:650
 QtObject {
  id:api
  property var sent:[]
  property var session:({profiles:{presets:{work:{dnd:true,volume:30,brightness:null,widgets:{clock:true,calendar:true,media:false}}}},brightness:{available:false}})
  function t(key){return key}
  function command(action,args){sent=sent.concat([{action:action,args:args}])}
  function showPage(page){sent=[page]}
 }
 Shell.ProfilesPanel{id:profiles;anchors.fill:parent;api:api}
 Shell.ToolsPanel{id:tools;api:api;visible:false;width:430;height:650}
 Shell.CosmicOsd{id:osd;visible:false}
 TestCase {
  name:'DesktopProfiles';when:windowShown
  function test_load_and_unsupported_brightness(){profiles.focusFirst();compare(profiles.draftDnd,true);compare(profiles.widgets.media,false)}
  function test_osd_motion_preference(){osd.reducedMotion=true;osd.value=73;compare(osd.shownValue,73);osd.muted=true;compare(osd.muted,true)}
 }
}
