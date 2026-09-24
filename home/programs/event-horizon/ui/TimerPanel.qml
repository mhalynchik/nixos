import QtQuick
import QtQuick.Controls
Item{
 id:p;required property var api
 property bool soundSettings:false
 property var timer:api.session.timer||{status:'idle',remaining:1500,duration:1500}
 function focusFirst(){if(soundSettings)soundOptions.focusFirst();else minutes.forceActiveFocus()}
 UiText{text:api.t('timer');font.family:'ForestSmooth';font.pixelSize:35}
 UiButton{x:260;y:4;width:140;visible:!!api.session.timerSoundPlaying;text:api.t('timer_sound_stop');onClicked:api.command('timer_sound_stop')}
 Item{width:parent.width;height:parent.height;visible:!p.soundSettings
 Pulsar{x:80;y:70;width:260;height:260;phase:api.menuPhase;surge:p.timer.status==='finished'?api.timerPulse:0}
 Canvas{x:70;y:60;width:280;height:280;property real fraction:p.timer.remaining/Math.max(1,p.timer.duration);onFractionChanged:requestPaint();Component.onCompleted:requestPaint();onPaint:{let c=getContext('2d');c.reset();c.lineWidth=3;c.strokeStyle='#294c3f';c.beginPath();c.arc(140,140,133,0,Math.PI*2);c.stroke();c.strokeStyle='#9cf9c8';c.beginPath();c.arc(140,140,133,-Math.PI/2,-Math.PI/2+Math.PI*2*fraction);c.stroke()}}
 UiText{y:345;width:parent.width;text:api.durationText(p.timer.remaining);font.pixelSize:52;horizontalAlignment:Text.AlignHCenter}
 UiText{y:410;width:parent.width;text:api.t(p.timer.status==='finished'?'finished':'timer_'+p.timer.status);horizontalAlignment:Text.AlignHCenter;color:'#9cbea9'}
 Row{y:455;spacing:8;Repeater{model:[5,25,50];UiButton{required property int modelData;width:126;text:modelData+' '+api.t('minutes');onClicked:api.command('timer_start',{seconds:modelData*60})}}}
 UiField{id:minutes;y:505;width:106;text:'25';validator:IntValidator{bottom:1;top:720}
 inputMethodHints:Qt.ImhDigitsOnly}
 UiButton{x:116;y:507;width:136;text:api.t(p.timer.status==='running'?'pause':p.timer.status==='paused'?'resume':'start');onClicked:api.command(p.timer.status==='running'?'timer_pause':p.timer.status==='paused'?'timer_resume':'timer_start',{seconds:Number(minutes.text)*60})}
 UiButton{x:263;y:507;width:136;text:api.t('reset');onClicked:api.command('timer_reset')}
 UiButton{y:557;width:400;text:api.t('timer_sound_settings');onClicked:{p.soundSettings=true;soundOptions.focusFirst()}}
 UiButton{y:603;width:400;text:api.t('reduced_motion');selected:(api.session.preferences||{}).reducedMotion===true;onClicked:api.command('setting',{key:'reducedMotion',value:!selected})}
 }
 TimerSoundSettings{id:soundOptions;y:65;width:parent.width;height:570;api:p.api;visible:p.soundSettings;onBack:{p.soundSettings=false;minutes.forceActiveFocus()}}
}
