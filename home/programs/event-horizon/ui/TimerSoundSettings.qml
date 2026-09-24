import QtQuick
import QtQuick.Controls
Item {
 id:p
 required property var api
 signal back()
 property var preferences:api.session.preferences||{}
 property int volume:preferences.timerVolume===undefined?85:preferences.timerVolume
 property string melody:preferences.timerMelody||'signal'
 property int repeats:preferences.timerRepeats||3
 function focusFirst(){backButton.forceActiveFocus()}
 UiButton{id:backButton;objectName:'timer-sound-back';width:160;text:'‹  '+api.t('timer');onClicked:p.back()}
 UiText{y:59;text:api.t('timer_sound_settings');font.pixelSize:23}
 UiText{y:103;text:api.t('timer_sound_volume')}
 UiText{x:320;y:103;width:80;text:Math.round(volumeSlider.value)+'%';horizontalAlignment:Text.AlignRight}
 UiSlider{
  id:volumeSlider;objectName:'timer-sound-volume';y:126;width:400;from:0;to:100;stepSize:1;value:p.volume
  Accessible.name:api.t('timer_sound_volume')
  onPressedChanged:if(!pressed)api.command('setting',{key:'timerVolume',value:Math.round(value)})
  Keys.onReleased:event=>{if([Qt.Key_Left,Qt.Key_Right,Qt.Key_Up,Qt.Key_Down,Qt.Key_Home,Qt.Key_End].includes(event.key))api.command('setting',{key:'timerVolume',value:Math.round(value)})}
 }
 UiText{y:177;width:400;text:api.t('timer_sound_volume_hint');wrapMode:Text.Wrap;color:'#9cbea9';font.pixelSize:12}
 UiText{y:233;text:api.t('timer_sound_melody')}
 Row{y:268;spacing:8
  Repeater{model:['signal','orbit','chime'];UiButton{
   required property string modelData;objectName:'timer-melody-'+modelData;width:128
   text:api.t('timer_melody_'+modelData);selected:p.melody===modelData
   onClicked:api.command('setting',{key:'timerMelody',value:modelData})
  }}
 }
 UiText{y:327;text:api.t('timer_sound_repeats')}
 Row{y:362;spacing:8
  Repeater{model:[1,3,5];UiButton{
   required property int modelData;objectName:'timer-repeat-'+modelData;width:128
   text:String(modelData)+' ×';selected:p.repeats===modelData
   onClicked:api.command('setting',{key:'timerRepeats',value:modelData})
  }}
 }
 Row{y:427;spacing:8
  UiButton{objectName:'timer-sound-preview';width:196;text:api.t('timer_sound_preview');enabled:p.volume>0;onClicked:api.command('timer_sound_preview')}
  UiButton{objectName:'timer-sound-stop';width:196;text:api.t('timer_sound_stop');enabled:!!api.session.timerSoundPlaying;onClicked:api.command('timer_sound_stop')}
 }
 UiText{y:488;width:400;text:api.t('timer_sound_saved');wrapMode:Text.Wrap;color:'#9cbea9';font.pixelSize:12}
}
