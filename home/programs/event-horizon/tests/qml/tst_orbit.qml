import QtQuick
import QtTest
import "../../ui" as Shell
Item {
 width:620;height:700
 Shell.OrbitNavigation{id:orbit;opened:true}
 TestCase {
  name:'OrbitNavigation';when:windowShown
  function init(){orbit.reducedMotion=true;orbit.currentPage='launcher';orbit.angle=0;orbit.destinationAngle=0;orbit.reducedMotion=false}
  function test_wrap_uses_shortest_path(){
   orbit.currentPage='settings';compare(orbit.destinationAngle,72)
   tryCompare(orbit,'rotating',false)
   orbit.currentPage='launcher';compare(orbit.destinationAngle,0)
   tryCompare(orbit,'rotating',false)
   orbit.currentPage='agenda';compare(orbit.destinationAngle,-72)
  }
  function test_retarget_during_animation_has_no_jump(){
   orbit.currentPage='wallpapers';wait(140)
   let before=orbit.angle
   orbit.currentPage='agenda'
   verify(Math.abs(orbit.angle-before)<1)
   verify(Math.abs(orbit.destinationAngle-before)<=180)
   tryCompare(orbit,'rotating',false)
   let held=orbit.angle;orbit.currentPage='wifi';wait(100)
   compare(orbit.angle,held)
  }
  function test_motion_preference_snaps_to_selected_page(){
   orbit.currentPage='settings';wait(70);orbit.reducedMotion=true
   compare(orbit.rotating,false);compare(orbit.angle,72)
  }
 }
}
