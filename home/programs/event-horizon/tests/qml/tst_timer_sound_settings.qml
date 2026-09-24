import QtQuick
import QtTest
import "../../ui" as Shell
Item {
 width:430;height:650
 QtObject {
  id:testApi
  property var session:({preferences:{timerVolume:85,timerMelody:'signal',timerRepeats:3},timerSoundPlaying:false})
  property var sent:null
  function t(key){return key}
  function command(action,args){sent={action:action,args:args}}
 }
 Shell.TimerSoundSettings{id:panel;anchors.fill:parent;api:testApi}
 TestCase {
  name:'TimerSoundSettings';when:windowShown
  function init(){testApi.session={preferences:{timerVolume:85,timerMelody:'signal',timerRepeats:3},timerSoundPlaying:false};testApi.sent=null}
  function test_melody_repeat_preview_and_stop(){
   mouseClick(findChild(panel,'timer-melody-orbit'))
   compare(testApi.sent.action,'setting');compare(testApi.sent.args,{key:'timerMelody',value:'orbit'})
   mouseClick(findChild(panel,'timer-repeat-5'))
   compare(testApi.sent.args,{key:'timerRepeats',value:5})
   mouseClick(findChild(panel,'timer-sound-preview'))
   compare(testApi.sent.action,'timer_sound_preview')
   compare(findChild(panel,'timer-sound-stop').enabled,false)
   testApi.session={preferences:{timerVolume:85,timerMelody:'orbit',timerRepeats:5},timerSoundPlaying:true}
   compare(findChild(panel,'timer-melody-orbit').selected,true)
   compare(findChild(panel,'timer-repeat-5').selected,true)
   mouseClick(findChild(panel,'timer-sound-stop'))
   compare(testApi.sent.action,'timer_sound_stop')
  }
  function test_volume_keyboard_and_silent_preview(){
   let slider=findChild(panel,'timer-sound-volume')
   slider.forceActiveFocus();keyClick(Qt.Key_Left)
   compare(testApi.sent.action,'setting');compare(testApi.sent.args,{key:'timerVolume',value:84})
   testApi.session={preferences:{timerVolume:0,timerMelody:'signal',timerRepeats:1}}
   compare(slider.value,0);compare(findChild(panel,'timer-sound-preview').enabled,false)
  }
 }
}
