import QtQuick
import QtQuick.Controls
Item {
 id:p
 required property var api
 property string tab:'media'
 function focusFirst(){tabs.itemAt(0).forceActiveFocus()}
 UiText{text:api.t('sound');font.family:'ForestSmooth';font.pixelSize:35}
 Row{y:55;spacing:6
  Repeater{id:tabs;model:['media','output','input','applications'];UiButton{required property string modelData;width:100;padding:4;font.pixelSize:12;text:api.t(modelData);selected:p.tab===modelData;onClicked:p.tab=modelData}}
 }
 Item{y:110;width:parent.width;height:530;visible:p.tab==='media'
  UiText{width:parent.width;text:api.audio.title;font.family:'ForestSmooth';font.pixelSize:30;wrapMode:Text.Wrap;maximumLineCount:2;elide:Text.ElideRight}
  UiText{y:72;width:parent.width;text:api.mediaArtist;color:'#9cc7b3';elide:Text.ElideRight}
  Row{y:115;spacing:10
   UiButton{width:70;text:'⏮';enabled:api.mediaAvailable&&(!api.nativePlayer||api.nativePlayer.canGoPrevious);onClicked:api.send('previous')}
   UiButton{width:100;text:api.t(api.audio.playing?'pause':'start');selected:api.audio.playing;enabled:api.mediaAvailable&&(!api.nativePlayer||api.nativePlayer.canTogglePlaying);onClicked:api.send('play')}
   UiButton{width:70;text:'■';enabled:api.mediaAvailable;onClicked:api.send('stop')}
   UiButton{width:70;text:'⏭';enabled:api.mediaAvailable&&(!api.nativePlayer||api.nativePlayer.canGoNext);onClicked:api.send('next')}
  }
  UiSlider{id:seek;y:172;width:400;from:0;to:Math.max(1,api.audio.duration);value:api.audio.position;enabled:api.mediaAvailable&&(!api.nativePlayer||(api.nativePlayer.canSeek&&api.nativePlayer.positionSupported));onPressedChanged:if(!pressed)api.send('seek',{value:value})}
  UiText{y:210;text:api.durationText(api.audio.position)+' / '+api.durationText(api.audio.duration);font.pixelSize:12}
  UiComboBox{y:247;width:400;visible:api.playerChoices.length>1;model:api.playerChoices;textRole:'name';onActivated:api.selectPlayer(currentIndex)}
  Equalizer{y:290;width:418;height:190;visible:api.previewAudio&&!api.nativePlayer;family:'ForestSmooth';gains:api.audio.gains;bands:api.audio.bands;onChanged:(band,value)=>api.send('eq',{band:band,value:value});onPreset:name=>api.send('preset',{name:name})}
  Item{y:296;width:400;height:157;visible:!api.previewAudio||!!api.nativePlayer
   UiText{text:api.t('spectrum');color:'#a7ccb9';font.pixelSize:13}
   Row{y:36;spacing:3;Repeater{model:48;Rectangle{required property int index;width:5;height:Math.max(2,(api.audio.bands[index]||0)*100);y:100-height;radius:2;color:index%3===0?'#b3f7ce':'#66cea3';opacity:.85}}}
   Rectangle{y:137;width:parent.width;height:1;color:'#3866a186'}
  }
  UiButton{y:455;width:230;visible:!api.previewAudio||!!api.nativePlayer;text:api.t('audio_settings');onClicked:api.command('open_audio_settings')}
 }
 Flickable{y:110;width:parent.width;height:490;clip:true;visible:p.tab!=='media';contentHeight:devices.height
  ScrollBar.vertical:ScrollBar{}
  Column{id:devices;width:parent.width;spacing:12
   Repeater{id:deviceList;model:(p.api.session.audio||{})[p.tab==='output'?'sinks':p.tab==='input'?'sources':'streams']||[]
    Rectangle{
     id:device
     required property var modelData
     property string group:p.tab==='output'?'sinks':p.tab==='input'?'sources':'streams'
     width:devices.width-12;height:132;radius:16;color:'#29112c23';border.width:1;border.color:'#466ba087'
     UiText{x:14;y:12;width:parent.width-110;text:device.modelData.label;elide:Text.ElideRight;font.pixelSize:15}
     UiButton{x:parent.width-94;y:8;width:82;height:29;text:device.modelData.mute?'×':'●';selected:device.modelData.mute;onClicked:api.command('mute',{group:device.group,id:device.modelData.id})}
     UiSlider{x:10;y:48;width:parent.width-75;from:0;to:100;stepSize:1;value:device.modelData.volume;onPressedChanged:if(!pressed)api.command('volume',{group:device.group,id:device.modelData.id,value:value});Keys.onReleased:event=>{if([Qt.Key_Left,Qt.Key_Right,Qt.Key_Up,Qt.Key_Down].includes(event.key))api.command('volume',{group:device.group,id:device.modelData.id,value:value})}}
     UiText{x:parent.width-65;y:60;text:device.modelData.volume+'%';font.pixelSize:12}
     UiText{x:14;y:98;visible:device.group==='streams';text:api.t('audio_stream_count')+': '+(device.modelData.ids||[]).length;color:'#99b9aa';font.pixelSize:12}
     UiButton{x:14;y:92;width:190;height:28;visible:device.group!=='streams';selected:device.modelData.name===(device.group==='sinks'?api.session.audio.defaultSink:api.session.audio.defaultSource);text:selected?api.t('selected'):api.t('devices');onClicked:api.command('default_device',{group:device.group,id:device.modelData.id})}
    }
   }
   UiText{width:parent.width;text:api.t(p.tab==='applications'?'no_streams':'no_devices');wrapMode:Text.Wrap;visible:deviceList.count===0;color:'#99b9aa'}
  }
 }
}
