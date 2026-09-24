import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Mpris
ShellRoot {
 id:root
 property bool opened:false
 property bool barHidden:false
 property bool layoutEditing:false
 property alias desktopWidgets:desktopWidgetsItem
 property var calendar:desktopWidgetsItem.calendar
 property var toastItem:({})
 property bool osdVisible:false
 property string osdKind:'volume'
 property string osdTitle:''
 property real osdValue:0
 property bool osdMuted:false
 property real profilePulse:0
 property string profileName:''
 property string page:'media'
 property var pages:orbit.pages
 readonly property var builtInPages:['media','wifi','bluetooth','system']
 property real birth:0
 property real death:0
 property bool opening:false
 property bool closing:false
 function localPath(path){return decodeURIComponent(Qt.resolvedUrl(path).toString().replace(/^file:\/\//,''))}
 function durationText(value){let seconds=Math.max(0,Math.floor(Number(value)||0));return Math.floor(seconds/60)+':'+(seconds%60).toString().padStart(2,'0')}
 function clamp(v){return Math.max(0,Math.min(1,v))}
 function smooth(v){let t=clamp(v);return t*t*(3-2*t)}
 property real reveal:opening?smooth((birth-.56)/.44):closing?1-smooth(death/.58):opened?1:0
 property real hole:opening?smooth((birth-.19)/.16):closing?1-smooth((death-.74)/.26):opened?1:0
 onOpenedChanged:{
  if(opened){collapse.stop();closing=false;death=0;opening=true;birth=0;supernova.restart()}
  else {supernova.stop();opening=false;birth=1;closing=true;death=0;collapse.restart();wallpaperCommand('cancel');if(radios.bluetooth?.scanning||radios.bluetooth?.request||radios.bluetooth?.pairing?.length)radioCommand('radio_idle')}
 }
 NumberAnimation{id:supernova;target:root;property:'birth';from:0;to:1;duration:root.reducedMotion?1:1200;easing.type:Easing.Linear;onFinished:root.opening=false}
 NumberAnimation{id:collapse;target:root;property:'death';from:0;to:1;duration:root.reducedMotion?1:700;easing.type:Easing.Linear;onFinished:root.closing=false}
 property real arrival:1
 property real orbitAngle:orbit.angle
 property real phase:0
 property real warp:0
 property string currentTrack:audio.title
 onCurrentTrackChanged:jump.restart()
 NumberAnimation{id:jump;target:root;property:"warp";from:1;to:0;duration:1400;easing.type:Easing.OutCubic}
 property date now:new Date()
 property var previewState:({track:0,title:'Emerald Signals',playing:false,stopped:false,position:0,duration:48,bands:[],gains:[0,0,0,0,0]})
 property var telemetry:({cpu:0,ram:0,processCount:0,top:[],history:[]})
 property color accent:'#72e7bc'
 onPageChanged:{arrive.restart();focusPage();if(page==='wifi'&&radios.wifi?.canScan)radioCommand('wifi_scan');if(page==='bluetooth'&&radios.bluetooth?.enabled)radioCommand('bt_scan');if(page!=='bluetooth'&&(radios.bluetooth?.scanning||radios.bluetooth?.pairing?.length))radioCommand('radio_idle');if(page!=='wallpapers'&&page!=='animated')wallpaperCommand('cancel')}
 NumberAnimation{id:arrive;target:root;property:'arrival';from:0;to:1;duration:280;easing.type:Easing.OutCubic}
 FontLoader{source:'fonts/forestsmooth.ttf'}
 FontLoader{source:'fonts/sansation.ttf'}
 FontLoader{source:'fonts/sansation-bold.ttf'}
 FontLoader{source:'fonts/sansation-light.ttf'}
 Timer{interval:33;running:!root.reducedMotion&&(root.opened||root.opening||root.closing);repeat:true;onTriggered:root.phase+=.033}
 Timer{interval:50;running:!root.reducedMotion&&(root.desktopVisible||root.layoutEditing);repeat:true;onTriggered:root.desktopPhase+=.05}
 Timer{interval:1000;running:true;repeat:true;onTriggered:root.now=new Date()}
 Process{id:engine;command:['python3',root.localPath('preview/audio.py')];running:root.previewAudio;stdinEnabled:true;stdout:SplitParser{onRead:data=>{try{root.previewState=JSON.parse(data)}catch(e){console.log(e)}}}stderr:SplitParser{onRead:data=>console.log(data)}}
 Process{command:['python3',root.localPath('runtime/telemetry.py')];running:true;stdout:SplitParser{onRead:data=>{try{root.telemetry=JSON.parse(data)}catch(e){console.log(e)}}}}
 property bool ownWallpaper:Quickshell.env('EVENT_HORIZON_PREVIEW_AUDIO')==='1'
 signal taskAdded()
 property bool previewAudio:Quickshell.env('EVENT_HORIZON_PREVIEW_AUDIO')==='1'
 property var session:({labels:{},audio:{},desktop:{},notifications:[],agenda:[],preferences:{},timer:{status:'idle',remaining:1500,duration:1500},search:[]})
 property bool reducedMotion:(session.preferences||{}).reducedMotion===true
 property real menuPhase:phase
 property real desktopPhase:0
 property real timerPulse:0
 property real notificationPulse:0
 property string selectedDate:Qt.formatDate(new Date(),'yyyy-MM-dd')
 property string chosenPlayer:''
 property var nativePlayer:Mpris.players.values.find(p=>p.dbusName===chosenPlayer)||Mpris.players.values.find(p=>p.isPlaying)||Mpris.players.values[0]||null
 property var playerChoices:Mpris.players.values.map(p=>({name:p.identity,id:p.dbusName}))
 property bool mediaAvailable:!!nativePlayer||previewAudio
 property string mediaArtist:nativePlayer?nativePlayer.trackArtist:''
 property var spectrum:[]
 property var audio:nativePlayer?({title:nativePlayer.trackTitle||nativePlayer.identity,playing:nativePlayer.isPlaying,position:nativePlayer.position,duration:nativePlayer.length,bands:spectrum,gains:[]}):previewAudio?previewState:({title:t('no_player'),playing:false,position:0,duration:1,bands:spectrum,gains:[]})
 property string heldScreen:''
 property var selectedScreen:Quickshell.screens.find(s=>s.name===(opened||closing?heldScreen:Hyprland.focusedMonitor?.name))||Quickshell.screens[0]
 property var currentMonitor:(session.desktop.monitors||[]).find(m=>m.name===selectedScreen?.name)
 property var liveMonitor:Hyprland.monitors.values.find(m=>m.name===selectedScreen?.name)
 property bool desktopVisible:!((session.desktop.windows||[]).some(w=>w.monitor===currentMonitor?.id&&w.workspace===currentMonitor?.activeWorkspace?.id))
 property bool fullscreen:liveMonitor?.activeWorkspace?(liveMonitor.activeWorkspace.toplevels.values||[]).some(w=>w.wayland?w.wayland.fullscreen:((w.lastIpcObject.fullscreen||0)&2)!==0):(session.desktop.windows||[]).some(w=>w.monitor===currentMonitor?.id&&w.workspace===currentMonitor?.activeWorkspace?.id&&(w.fullscreen&2)!==0)
 property int unread:(session.notifications||[]).filter(n=>!n.read).length
 property var defaultSource:(session.audio.sources||[]).find(x=>x.name===session.audio.defaultSource)||({mute:false,available:false})
 property var defaultSink:(session.audio.sinks||[]).find(x=>x.name===session.audio.defaultSink)||({volume:0})
 property string toastTitle:''
 property string toastBody:''
 property bool toastVisible:false
 function t(key){return session.labels[key]||key||''}
 function command(action,extra){if(['remove_notification','remove_notification_group','clear_read'].includes(action)){for(let n of session.notifications){if((action==='remove_notification'&&n.id===extra.id)||(action==='clear_read'&&n.read)||(action==='remove_notification_group'&&n.app===extra.app&&(extra.conversation===undefined||(n.conversationId||'')===extra.conversation)))notifications.dismiss(n)}}let v=Object.assign({},extra||{},{action:action});backend.write(JSON.stringify(v)+'\n')}
 function receive(value){
  let oldError=session.error;
  for(let key of Object.keys(value)){if(JSON.stringify(value[key])===JSON.stringify(session[key]))value[key]=session[key]}
  let previousSink=(session.audio?.sinks||[]).find(x=>x.name===session.audio.defaultSink),nextSink=(value.audio?.sinks||[]).find(x=>x.name===value.audio.defaultSink);
  let previousSource=(session.audio?.sources||[]).find(x=>x.name===session.audio.defaultSource),nextSource=(value.audio?.sources||[]).find(x=>x.name===value.audio.defaultSource);
  if(previousSink&&nextSink&&previousSink.name===nextSink.name&&(previousSink.volume!==nextSink.volume||previousSink.mute!==nextSink.mute))showOsd('volume',t('system_volume'),nextSink.volume,nextSink.mute);
  if(previousSource&&nextSource&&previousSource.name===nextSource.name&&previousSource.mute!==nextSource.mute)showOsd(nextSource.mute?'mic-muted':'microphone',t('microphone'),nextSource.volume,nextSource.mute);
  if(session.brightness?.available&&value.brightness?.available&&session.brightness.value!==value.brightness.value)showOsd('brightness',t('brightness'),value.brightness.value,false);
  let oldCapture=session.capture;
  session=value;
  if(oldCapture&&['preparing','recording'].includes(oldCapture.status)&&['finished','failed'].includes(value.capture?.status))showToast(t(value.capture.status==='finished'?'capture_finished':'capture_failed'),value.capture.path||t(value.capture.error||'capture_finished'),{kind:'capture',path:value.capture.path});
  if(value.event?.kind==='profile'){profileName=value.event.name;profileTransition.restart()}
  if(value.event?.kind==='task_added')taskAdded();
  if(value.event?.kind==='wallpaper'){ownWallpaper=false;opened=false}
  if(value.event?.kind==='close')opened=false;
  if(value.event?.kind==='page'){page=value.event.page;if(!opened)open(page);else focusPage()}
  if(value.event?.kind==='timer_finished'){finishedPulse.restart();command('notify',{sourceId:0,session:'timer-'+Date.now(),app:t('timer'),summary:t('finished'),body:t('timer_body')});showToast(t('finished'),t('timer_body'),{kind:'timer'})}
  if(value.error&&value.error!==oldError)showToast(t('error'),t(value.error));
 }
 Process{id:backend;command:['python3',root.localPath('runtime/desktop_backend.py')];running:true;stdinEnabled:true;stdout:SplitParser{onRead:data=>{try{root.receive(JSON.parse(data))}catch(e){console.log('backend',e)}}}stderr:SplitParser{onRead:data=>console.log('backend',data)}}
 property var radios:({wifi:{},bluetooth:{}})
 property var wallpapers:({items:[],directories:{},error:''})
 function radioCommand(action,extra){radioEngine.write(JSON.stringify(Object.assign({},extra||{},{action:action}))+'\n')}
 function wallpaperCommand(action,extra){if(wallpapers.error)wallpapers=Object.assign({},wallpapers,{error:''});wallpaperEngine.write(JSON.stringify(Object.assign({},extra||{},{action:action}))+'\n')}
 Process{id:radioEngine;command:['python3',root.localPath('runtime/connections.py')];running:true;stdinEnabled:true;stdout:SplitParser{onRead:data=>{try{let v=JSON.parse(data);if(v.error)root.showToast(root.t('error'),v.error);else root.radios=v}catch(e){console.log('radios',e)}}}stderr:SplitParser{onRead:data=>console.log('radios',data)}}
 Process{id:wallpaperEngine;command:['python3',root.localPath('runtime/wallpapers.py')];running:true;stdinEnabled:true;stdout:SplitParser{onRead:data=>{try{let v=JSON.parse(data);if(v.thumbnail){v.items=root.wallpapers.items.map(x=>x.id===v.thumbnail.id?Object.assign({},x,{thumbnail:v.thumbnail.url}):x)}root.wallpapers=Object.assign({},root.wallpapers,v);if(v.committed)root.opened=false}catch(e){console.log('wallpapers',e)}}}stderr:SplitParser{onRead:data=>console.log('wallpapers',data)}}
 Process{id:spectrumEngine;command:['python3',root.localPath('runtime/spectrum.py')];running:(!root.previewAudio||!!root.nativePlayer)&&!root.fullscreen&&(root.opened||root.desktopVisible)&&!root.reducedMotion;stdout:SplitParser{onRead:data=>{try{root.spectrum=JSON.parse(data)}catch(e){}}}}
 NotificationHub{id:notifications;api:root}
 function notificationActions(item){if(item.kind==='capture'&&item.path&&item.path===session.capture?.path)return [{identifier:'capture-folder',text:t('capture_open_folder')}];if(item.kind==='timer')return [{identifier:'timer-open',text:t('timer')}].concat(session.timerSoundPlaying?[{identifier:'timer-stop',text:t('timer_sound_stop')}]:[]);return notifications.actions(item)}
 function invokeNotification(item,identifier){if(item.kind==='capture'&&identifier==='capture-folder'&&item.path===session.capture?.path){command('capture_open_folder');return true}if(item.kind==='timer'){if(identifier==='timer-open'){showPage('timer');return true}if(identifier==='timer-stop'){command('timer_sound_stop');return true}}let done=notifications.invoke(item,identifier);if(done){let n=session.notifications.find(x=>x.actionToken===item.actionToken&&x.session===item.session);if(n)command('read_notification',{id:n.id});if(identifier==='default')opened=false}return done}
 function activateNotification(item){return invokeNotification(item,item.kind==='capture'?'capture-folder':item.kind==='timer'?'timer-open':'default')}
 function notificationCanReply(item){return notifications.canReply(item)}
 function replyNotification(item,text){return notifications.reply(item,text)}
 function showToast(title,body,item){if((session.preferences||{}).dnd)return;toastTitle=title;toastBody=body;toastItem=item||({});toastVisible=true;toastTimeout.restart();incomingPulse.restart()}
 Timer{id:toastTimeout;interval:6000;running:root.toastVisible&&!toastCard.hovered;onTriggered:root.toastVisible=false}
 function showOsd(kind,title,value,muted){osdKind=kind;osdTitle=title;osdValue=value;osdMuted=muted;osdVisible=true;osdTimeout.restart()}
 Timer{id:osdTimeout;interval:1800;onTriggered:root.osdVisible=false}
 NumberAnimation{id:profileTransition;target:root;property:'profilePulse';from:1;to:0;duration:root.reducedMotion?600:1400}
 NumberAnimation{id:incomingPulse;target:root;property:'notificationPulse';from:1;to:0;duration:900}
 NumberAnimation{id:finishedPulse;target:root;property:'timerPulse';from:1;to:0;duration:1800}
 Timer{interval:500;running:!!root.nativePlayer&&root.nativePlayer.isPlaying;repeat:true;onTriggered:root.nativePlayer.positionChanged()}
 function selectPlayer(i){chosenPlayer=playerChoices[i].id}
 function send(action,extra){
  let p=nativePlayer;
  if(p){if(action==='play'&&p.canTogglePlaying)p.togglePlaying();else if(action==='stop'&&p.canControl)p.stop();else if(action==='next'&&p.canGoNext)p.next();else if(action==='previous'&&p.canGoPrevious)p.previous();else if(action==='seek'&&p.canSeek&&p.positionSupported)p.position=Math.max(0,Math.min(p.length,extra.value));return}
  if(previewAudio)engine.write(JSON.stringify(Object.assign({},extra||{},{action:action}))+'\n');
 }
 function focusPage(){Qt.callLater(()=>{overlayFocus.forceActiveFocus();if(extraPanel.item&&extraPanel.item.focusFirst)extraPanel.item.focusFirst();else if(page==='media')audioPanel.focusFirst();else if(page==='wifi'||page==='bluetooth')connectionPanel.focusFirst()})}
 function showPage(p){if(layoutEditing)desktopWidgetsItem.cancel();heldScreen=Hyprland.focusedMonitor?.name||selectedScreen?.name||'';page=p;opened=true;arrive.restart();focusPage()}
 function open(p){if(opened&&page===p&&heldScreen===Hyprland.focusedMonitor?.name){opened=false;return}showPage(p)}
 function navPosition(i){let a=(i*360/pages.length+orbitAngle)*Math.PI/180;return {x:panel.x+(310+238*Math.cos(a))*panel.scale,y:panel.y+(355+238*Math.sin(a))*panel.scale}}
 function status(){return JSON.stringify({opened:opened,opening:opening,closing:closing,page:page,reveal:reveal,timing:{open:supernova.duration,close:collapse.duration},screen:selectedScreen?.name,scale:panel.scale,panel:{x:panel.x,y:panel.y,width:panel.width*panel.scale,height:panel.height*panel.scale},orbit:{angle:orbit.angle,target:orbit.destinationAngle,rotating:orbit.rotating},nav:pages.map((p,i)=>({page:p,point:navPosition(i)})),audio:audio,nativePlayer:nativePlayer?.identity,session:session,animation:{menu:menuPhase,desktop:desktopPhase,desktopVisible:desktopVisible,fullscreen:fullscreen,reducedMotion:reducedMotion},toast:toastVisible,selectedDate:selectedDate,radios:radios,wallpapers:wallpapers,bar:{width:statusBar.width,contentWidth:statusRow.implicitWidth,scale:statusRow.scale,buttons:statusRow.children.filter(b=>b.objectName.startsWith('bar-')).map(b=>({id:b.objectName.slice(4),label:b.label,icon:b.iconName,selected:b.selected,progress:b.outlineProgress??-1,x:root.selectedScreen.width-6-statusBar.width+8+(b.x+b.width/2)*statusRow.scale,y:8+(b.y+b.height/2)*statusRow.scale}))},layoutEditing:layoutEditing,layoutWidgets:desktopWidgetsItem.widgets,osd:{visible:osdVisible,kind:osdKind,value:osdValue},mediaControls:desktopWidgetsItem.mediaControls,calendar:{month:calendar.month,year:calendar.year,selected:calendar.selectedDay}})}
 IpcHandler{target:'design'
  function open(section:string):void{root.open(section)}
  function selectPage(section:string):void{root.showPage(section)}
  function close():void{root.opened=false}
  function toggleBar():void{root.barHidden=!root.barHidden}
  function clearNotifications():void{for(let n of root.session.notifications)root.command('read_group',{app:n.app});root.command('clear_read')}
  function status():string{return root.status()}
  function action(name:string):void{root.send(name)}
  function command(payload:string):void{let v=JSON.parse(payload);root.command(v.action,v)}
 }
 component Label:Text{textFormat:Text.PlainText;font.family:'Sansation';font.pixelSize:14;color:'#e1f4eb'}
 component Muted:Label{font.pixelSize:11;color:'#a6c9bb'}
 component Heading:Text{textFormat:Text.PlainText;font.family:'ForestSmooth';font.pixelSize:35;color:'#e5fff2'}
 component Star:Text{text:'✦';font.family:'Sansation';font.pixelSize:20;color:root.accent}

 Variants{model:Quickshell.screens
  PanelWindow{required property var modelData;screen:modelData;visible:root.ownWallpaper
   anchors{top:true;bottom:true;left:true;right:true}color:'#081612';exclusionMode:ExclusionMode.Ignore
   WlrLayershell.layer:WlrLayer.Background;WlrLayershell.namespace:'emerald-pixel-background'
   Image{anchors.fill:parent;source:'sky.png';fillMode:Image.PreserveAspectCrop;sourceSize:Qt.size(2560,1440)}
  }
 }
 PanelWindow{
  id:desktopWindow;screen:root.selectedScreen
  anchors{top:true;bottom:true;left:true;right:true}color:'transparent';exclusionMode:ExclusionMode.Ignore
  WlrLayershell.layer:root.layoutEditing?WlrLayer.Overlay:WlrLayer.Bottom;WlrLayershell.namespace:'emerald-desktop';WlrLayershell.keyboardFocus:root.layoutEditing?WlrKeyboardFocus.Exclusive:WlrKeyboardFocus.OnDemand
  mask:Region{width:root.layoutEditing?desktopWindow.width:0;height:root.layoutEditing?desktopWindow.height:0;regions:[
   Region{property var bounds:desktopWidgetsItem.calendarRegion;x:bounds.x;y:bounds.y;width:bounds.visible?Math.ceil(bounds.width):0;height:bounds.visible?Math.ceil(bounds.height):0},
   Region{property var bounds:desktopWidgetsItem.mediaControls;x:bounds.x;y:bounds.y;width:bounds.visible?Math.ceil(bounds.width):0;height:bounds.visible?Math.ceil(bounds.height):0}
  ]}
  DesktopWidgets{id:desktopWidgetsItem;anchors.fill:parent;api:root}
 }

 PanelWindow{
  id:statusBar;screen:root.selectedScreen;anchors{top:true;right:true}margins{top:4;right:6}implicitWidth:Math.min(statusRow.implicitWidth+16,root.selectedScreen?.width-430||978);implicitHeight:36;color:'transparent';exclusionMode:ExclusionMode.Ignore
  visible:!root.barHidden
  mask:Region{width:statusBar.width;height:statusBar.height}
  // Stay above Waybar's transparent input surface; native workspace/toplevel
  // events return the island to Top so the compositor hides it in fullscreen.
  WlrLayershell.layer:root.opened||!root.fullscreen?WlrLayer.Overlay:WlrLayer.Top;WlrLayershell.namespace:'emerald-bar'
  Rectangle{anchors.fill:parent;radius:18;color:'#b30b201a';border.width:1;border.color:'#6075c9a9'
   Row{id:statusRow;x:8;y:4;spacing:6;scale:Math.min(1,(statusBar.width-16)/implicitWidth);transformOrigin:Item.TopLeft
    MotionButton{objectName:'bar-play';width:34;height:28;iconName:root.audio.playing?'pause':'play';textSize:16;tooltip:root.audio.playing?'Пауза':'Воспроизвести';onTriggered:root.send('play')}
    MotionButton{objectName:'bar-next';width:30;height:28;iconName:'next';textSize:16;tooltip:'Следующий трек';enabled:root.previewAudio||!!root.nativePlayer?.canGoNext;opacity:enabled?1:.4;onTriggered:root.send('next')}
    MotionButton{objectName:'bar-media';width:130;height:28;label:root.audio.title.length>17?root.audio.title.slice(0,16)+'…':root.audio.title;textSize:11;tooltip:root.audio.title;onTriggered:root.showPage('media')}
    MotionButton{objectName:'bar-volume';width:62;height:28;iconName:'volume';label:Math.round(root.defaultSink.volume)+'%';textSize:12;tooltip:root.t('system_volume')+' · '+(root.defaultSink.label||'')+' · '+root.t('volume_scroll');onTriggered:root.showPage('media');MouseArea{anchors.fill:parent;acceptedButtons:Qt.NoButton;onWheel:w=>{root.command('quick_volume',{delta:w.angleDelta.y>0?5:-5});w.accepted=true}}}
    MotionButton{objectName:'bar-microphone';width:34;height:28;iconName:root.defaultSource.mute||root.defaultSource.available===false?'mic-muted':'microphone';selected:root.defaultSource.available!==false&&!root.defaultSource.mute;textSize:17;tooltip:root.defaultSource.available===false?root.t('mic_disconnected'):(root.defaultSource.mute?'Включить микрофон':'Выключить микрофон')+' · '+root.defaultSource.label;onTriggered:if(root.defaultSource.available!==false)root.command('mic_mute')}
    MotionButton{objectName:'bar-wifi';width:34;height:28;iconName:'wifi';textSize:17;tooltip:'Wi-Fi';selected:!!root.radios.wifi?.adapter&&!!root.radios.wifi?.enabled&&!!root.radios.wifi?.hardwareEnabled;onTriggered:root.showPage('wifi')}
    MotionButton{objectName:'bar-bluetooth';width:34;height:28;iconName:'bluetooth';textSize:17;tooltip:'Bluetooth';selected:!!root.radios.bluetooth?.enabled;onTriggered:root.showPage('bluetooth')}
    MotionButton{objectName:'bar-notifications';width:root.unread?52:34;height:28;iconName:'notifications';label:root.unread?String(root.unread):'';selected:root.page==='notifications'&&root.opened;textSize:13;tooltip:'Уведомления: '+root.unread;border.color:root.notificationPulse>0?'#e9ffcc':'#456e5966';onTriggered:root.showPage('notifications');Rectangle{anchors.centerIn:parent;width:parent.width+16*(1-root.notificationPulse);height:parent.height+8*(1-root.notificationPulse);radius:height/2;color:'transparent';border.width:1;border.color:'#b8ffcf';opacity:root.notificationPulse}}
    MotionButton{objectName:'bar-overview';width:34;height:28;iconName:'overview';textSize:17;tooltip:root.t('overview');selected:root.page==='overview'&&root.opened;onTriggered:root.showPage('overview')}
    TimerClockButton{objectName:'bar-timer';now:root.now;timer:root.session.timer;tooltip:Qt.formatDate(root.now,'dd.MM.yyyy')+' · '+root.t('timer')+((root.session.timer.status==='running'||root.session.timer.status==='paused')?' · '+root.durationText(root.session.timer.remaining):'');selected:root.page==='timer'&&root.opened;onTriggered:root.showPage('timer')}
    MotionButton{objectName:'bar-system';width:34;height:28;iconName:'system';textSize:17;tooltip:'CPU '+Math.round(root.telemetry.cpu)+'% · RAM '+Math.round(root.telemetry.ramPercent||0)+'%';selected:root.page==='system'&&root.opened;onTriggered:root.showPage('system')}
    MotionButton{objectName:'bar-tools';width:34;height:28;iconName:'tools';tooltip:root.t('tools');selected:root.page==='tools'&&root.opened;onTriggered:root.showPage('tools')}
    MotionButton{objectName:'bar-recording';visible:['preparing','recording'].includes(root.session.capture?.status);width:74;height:28;iconName:'record';label:root.session.capture?.status==='recording'?root.durationText(root.session.capture.elapsed):'…';selected:true;tooltip:root.t('capture');onTriggered:root.showPage('capture')}
    MotionButton{objectName:'bar-power';width:34;height:28;iconName:'power';textSize:17;tooltip:'Питание и сеанс';selected:root.page==='power'&&root.opened;onTriggered:root.showPage('power')}
   }
  }
 }
 PanelWindow{
  screen:root.selectedScreen;anchors{top:true;right:true}margins{top:48;right:22}implicitWidth:390;implicitHeight:toastCard.implicitHeight;color:'transparent';visible:root.toastVisible&&!root.opened&&!root.fullscreen
  exclusionMode:ExclusionMode.Ignore;WlrLayershell.layer:WlrLayer.Overlay;WlrLayershell.namespace:'emerald-toast'
  NotificationToast{id:toastCard;anchors.fill:parent;api:root;onDismissed:root.toastVisible=false}
 }
 PanelWindow{
  screen:root.selectedScreen;anchors{bottom:true}margins.bottom:100;implicitWidth:300;implicitHeight:110;color:'transparent';visible:root.osdVisible
  exclusionMode:ExclusionMode.Ignore;WlrLayershell.layer:WlrLayer.Overlay;WlrLayershell.namespace:'emerald-osd';mask:Region{}
  CosmicOsd{anchors.fill:parent;kind:root.osdKind;title:root.osdTitle;value:root.osdValue;muted:root.osdMuted;reducedMotion:root.reducedMotion}
 }
 PanelWindow{
  screen:root.selectedScreen;implicitWidth:440;implicitHeight:180;color:'transparent';visible:root.profilePulse>0
  exclusionMode:ExclusionMode.Ignore;WlrLayershell.layer:WlrLayer.Overlay;WlrLayershell.namespace:'emerald-profile';mask:Region{}
  Rectangle{anchors.fill:parent;radius:30;color:'#d00b241d';opacity:Math.min(1,root.profilePulse*4)}
  Canvas{anchors.fill:parent;property real pulse:root.profilePulse;onPulseChanged:requestPaint();onPaint:{let c=getContext('2d');c.reset();let pts=[[35,105],[93,52],[155,80],[237,35],[317,70],[400,42]];c.strokeStyle='#6493d3ad';c.lineWidth=1;c.beginPath();pts.forEach((v,i)=>{if(!i)c.moveTo(v[0],v[1]);else c.lineTo(v[0],v[1])});c.stroke();pts.forEach((v,i)=>{c.fillStyle='#b6fbd0';c.globalAlpha=Math.max(0,Math.min(1,pulse*5-i*.15));c.beginPath();c.arc(v[0],v[1],2+2*Math.sin(pulse*5+i),0,Math.PI*2);c.fill()})}}
  UiText{y:112;width:parent.width;text:root.profileName?root.t('profile_'+root.profileName):root.t('profile_manual');font.family:'ForestSmooth';font.pixelSize:32;horizontalAlignment:Text.AlignHCenter;opacity:Math.min(1,root.profilePulse*4)}
 }

 PanelWindow{
  id:overlay;screen:root.selectedScreen;anchors{top:true;bottom:true;left:true;right:true}color:'transparent';exclusionMode:ExclusionMode.Ignore
  visible:root.opened||root.opening||root.closing;mask:Region{x:0;y:40;width:overlay.width;height:overlay.height-40}
  WlrLayershell.layer:WlrLayer.Overlay;WlrLayershell.namespace:'emerald-overlay';WlrLayershell.keyboardFocus:!root.opened?WlrKeyboardFocus.None:overlay.contentItem.Window.active?WlrKeyboardFocus.OnDemand:WlrKeyboardFocus.Exclusive
  // A window shortcut also reaches controls outside overlayFocus.
  Shortcut{sequence:'Escape';context:Qt.WindowShortcut;enabled:root.opened;onActivated:root.opened=false}
  // Once focused, use on-demand input so Hyprland honors the bar cutout.
  FocusScope{id:overlayFocus;anchors.fill:parent;focus:true;Keys.onEscapePressed:root.opened=false
   Shortcut{sequence:'Alt+1';enabled:root.opened;onActivated:root.showPage('launcher')}
   Shortcut{sequence:'Alt+2';enabled:root.opened;onActivated:root.showPage('agenda')}
   Shortcut{sequence:'Alt+3';enabled:root.opened;onActivated:root.showPage('wallpapers')}
   Shortcut{sequence:'Alt+4';enabled:root.opened;onActivated:root.showPage('animated')}
   Shortcut{sequence:'Alt+5';enabled:root.opened;onActivated:root.showPage('settings')}
  }
  MouseArea{anchors.fill:parent;onClicked:root.opened=false}
  Item{
   id:panel;scale:Math.max(.1,Math.min(1,(parent.width-36)/1090,(parent.height-58)/822));transformOrigin:Item.TopLeft;x:parent.width-width*scale-18;y:40;width:1090;height:822;Keys.onEscapePressed:root.opened=false
   MouseArea{anchors.fill:parent;onClicked:{}}
   VaporPanel{anchors.fill:parent;birth:root.birth;death:root.death;opening:root.opening;closing:root.closing;opened:root.opened}
   CosmicTransition{x:-150;y:-60;width:1390;height:942;birth:root.birth;death:root.death;opening:root.opening;closing:root.closing;phase:root.phase;orbitAngle:root.orbitAngle}
   Item{x:310+(30-310)*root.reveal;y:355+(24-355)*root.reveal;scale:root.reveal;opacity:root.reveal
    Star{y:1;font.pixelSize:25;rotation:root.phase*6}
    Label{x:40;y:0;text:'Управление';font.family:'ForestSmooth';font.pixelSize:23;font.letterSpacing:2}
   }
   MotionButton{objectName:'menu-close';x:310+(1029-310)*root.reveal;y:355+(25-355)*root.reveal;scale:root.reveal;width:34;height:34;iconName:'close';tooltip:root.t('close');textSize:18;opacity:root.reveal;onTriggered:root.opened=false}
   Item{x:0;y:0;width:620;height:700
    Gravity{id:blackHole;x:90;y:135;width:440;height:440;scale:root.hole;opacity:root.hole;phase:root.phase;bands:root.audio.bands;playing:root.audio.playing;warp:root.warp;progress:root.audio.position/root.audio.duration}
    OrbitNavigation{id:orbit;currentPage:root.page;birth:root.birth;death:root.death;opening:root.opening;closing:root.closing;opened:root.opened;reducedMotion:root.reducedMotion;onActivated:page=>root.showPage(page)}
    Muted{id:orbitCaption;x:310+(185-310)*root.reveal;y:355+328*root.reveal;scale:root.reveal;opacity:root.reveal;width:250;text:'SOUND BENDS THE LIGHT';font.letterSpacing:2;horizontalAlignment:Text.AlignHCenter}
   }
   Item{id:content;property real deploy:root.opening?root.smooth((root.birth-.6)/.4):root.closing?1-root.smooth(root.death/.54):root.opened?1:0
    property real spin:root.closing?(1-deploy)*-2.3:0
    x:310+deploy*(300*Math.cos(spin)+287*Math.sin(spin));y:355+deploy*(300*Math.sin(spin)-287*Math.cos(spin));width:430;height:650
    scale:Math.pow(deploy,1.3);opacity:Math.min(1,deploy*2);rotation:root.closing?-100*(1-deploy):(1-deploy)*-8;transformOrigin:Item.TopLeft;enabled:deploy>.95
    AudioPanel{id:audioPanel;anchors.fill:parent;api:root;opacity:root.arrival;transform:Translate{x:28*(1-root.arrival)}
visible:root.page==='media'}
    Loader{id:extraPanel;anchors.fill:parent;opacity:root.arrival;transform:Translate{x:28*(1-root.arrival)}
active:!root.builtInPages.includes(root.page);sourceComponent:({'launcher':launcherComponent,'notifications':notificationsComponent,'overview':overviewComponent,'agenda':agendaComponent,'timer':timerComponent,'power':powerComponent,'wallpapers':wallpaperComponent,'animated':wallpaperComponent,'settings':settingsComponent,'tools':toolsComponent,'clipboard':clipboardComponent,'capture':captureComponent,'layout':layoutComponent,'profiles':profilesComponent})[root.page]||null;onLoaded:root.focusPage()}
    ConnectionPanel{id:connectionPanel;anchors.fill:parent;api:root;visible:root.page==='wifi'||root.page==='bluetooth';opacity:root.arrival}
    SystemPanel{anchors.fill:parent;api:root;visible:root.page==='system';opacity:root.arrival}
   }
   UiText{x:620;y:732;width:420;height:40;visible:!!root.session.error;text:root.t(root.session.error);font.pixelSize:11;color:'#f6c8a2';wrapMode:Text.Wrap;maximumLineCount:2;elide:Text.ElideRight}
   Rectangle{x:31;y:783;width:1028;height:1;color:'#2b7bcca9';opacity:root.reveal}
   Muted{x:760;y:797;text:'Alt 1–5 · Tab · Enter · Esc';font.letterSpacing:1.5;font.pixelSize:9;opacity:root.reveal}
  }
 }
 Component{id:launcherComponent;LauncherPanel{api:root}}
 Component{id:notificationsComponent;NotificationPanel{api:root}}
 Component{id:overviewComponent;OverviewPanel{api:root}}
 Component{id:agendaComponent;AgendaPanel{api:root}}
 Component{id:timerComponent;TimerPanel{api:root}}
 Component{id:settingsComponent;SettingsPanel{api:root}}
 Component{id:toolsComponent;ToolsPanel{api:root}}
 Component{id:clipboardComponent;ClipboardPanel{api:root}}
 Component{id:captureComponent;CapturePanel{api:root}}
 Component{id:layoutComponent;LayoutPanel{api:root}}
 Component{id:profilesComponent;ProfilesPanel{api:root}}
 Component{id:powerComponent;PowerPanel{api:root}}
 Component{id:wallpaperComponent;WallpaperPanel{api:root}}
}
