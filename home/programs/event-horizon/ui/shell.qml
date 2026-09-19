import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Mpris
ShellRoot {
 id:root
 property bool opened:false
 property bool barHidden:false
 property string page:'media'
 property var pages:['media','wifi','bluetooth','system']
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
 property real orbitAngle:-Math.max(0,pages.indexOf(page))*90
 property real phase:0
 property real warp:0
 property string currentTrack:audio.title
 onCurrentTrackChanged:jump.restart()
 NumberAnimation{id:jump;target:root;property:"warp";from:1;to:0;duration:1400;easing.type:Easing.OutCubic}
 property date now:new Date()
 property var previewState:({track:0,title:'Emerald Signals',playing:false,stopped:false,position:0,duration:48,bands:[],gains:[0,0,0,0,0]})
 property var telemetry:({cpu:0,ram:0,processCount:0,top:[],history:[]})
 property color accent:'#72e7bc'
 Behavior on orbitAngle{NumberAnimation{duration:420;easing.type:Easing.InOutCubic}}
 onPageChanged:{arrive.restart();focusPage();if(page==='wifi'&&radios.wifi?.canScan)radioCommand('wifi_scan');if(page==='bluetooth'&&radios.bluetooth?.enabled)radioCommand('bt_scan');if(page!=='bluetooth'&&(radios.bluetooth?.scanning||radios.bluetooth?.pairing?.length))radioCommand('radio_idle');if(page!=='wallpapers'&&page!=='animated')wallpaperCommand('cancel')}
 NumberAnimation{id:arrive;target:root;property:'arrival';from:0;to:1;duration:280;easing.type:Easing.OutCubic}
 FontLoader{source:'fonts/forestsmooth.ttf'}
 FontLoader{source:'fonts/sansation.ttf'}
 FontLoader{source:'fonts/sansation-bold.ttf'}
 FontLoader{source:'fonts/sansation-light.ttf'}
 Timer{interval:33;running:!root.reducedMotion&&(root.opened||root.opening||root.closing);repeat:true;onTriggered:root.phase+=.033}
 Timer{interval:50;running:!root.reducedMotion&&root.desktopVisible;repeat:true;onTriggered:root.desktopPhase+=.05}
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
 property bool desktopVisible:!((session.desktop.windows||[]).some(w=>w.monitor===currentMonitor?.id&&w.workspace===currentMonitor?.activeWorkspace?.id))
 property bool fullscreen:(session.desktop.windows||[]).some(w=>w.monitor===currentMonitor?.id&&w.workspace===currentMonitor?.activeWorkspace?.id&&w.fullscreen>0)
 property int unread:(session.notifications||[]).filter(n=>!n.read).length
 property var defaultSource:(session.audio.sources||[]).find(x=>x.name===session.audio.defaultSource)||({mute:false})
 property var defaultSink:(session.audio.sinks||[]).find(x=>x.name===session.audio.defaultSink)||({volume:0})
 property string toastTitle:''
 property string toastBody:''
 property bool toastVisible:false
 function t(key){return session.labels[key]||key||''}
 function command(action,extra){if(action==='remove_notification'){let n=session.notifications.find(x=>x.id===extra.id);if(n)notifications.dismiss(n)}let v=Object.assign({},extra||{},{action:action});backend.write(JSON.stringify(v)+'\n')}
 function receive(value){
  let oldError=session.error;
  for(let key of Object.keys(value)){if(JSON.stringify(value[key])===JSON.stringify(session[key]))value[key]=session[key]}
  session=value;
  if(value.event?.kind==='task_added')taskAdded();
  if(value.event?.kind==='wallpaper'){ownWallpaper=false;opened=false}
  if(value.event?.kind==='close')opened=false;
  if(value.event?.kind==='page'){page=value.event.page;if(!opened)open(page);else focusPage()}
  if(value.event?.kind==='timer_finished'){finishedPulse.restart();command('notify',{sourceId:0,session:'timer-'+Date.now(),app:t('timer'),summary:t('finished'),body:t('timer_body')});showToast(t('finished'),t('timer_body'))}
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
 function notificationActions(item){return notifications.actions(item)}
 function invokeNotification(id,index){notifications.invoke(id,index)}
 function showToast(title,body){if((session.preferences||{}).dnd)return;toastTitle=title;toastBody=body;toastVisible=true;toastTimeout.restart();incomingPulse.restart()}
 Timer{id:toastTimeout;interval:5000;onTriggered:root.toastVisible=false}
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
 function open(p){if(opened&&page===p&&heldScreen===Hyprland.focusedMonitor?.name){opened=false;return}heldScreen=Hyprland.focusedMonitor?.name||selectedScreen?.name||'';page=p;opened=true;arrive.restart();focusPage()}
 function navPosition(i){let a=(i*90+orbitAngle)*Math.PI/180;return {x:panel.x+(310+238*Math.cos(a))*panel.scale,y:panel.y+(355+238*Math.sin(a))*panel.scale}}
 function status(){return JSON.stringify({opened:opened,opening:opening,closing:closing,page:page,reveal:reveal,timing:{open:supernova.duration,close:collapse.duration},screen:selectedScreen?.name,scale:panel.scale,panel:{x:panel.x,y:panel.y,width:panel.width*panel.scale,height:panel.height*panel.scale},nav:pages.map((p,i)=>({page:p,point:navPosition(i)})),audio:audio,nativePlayer:nativePlayer?.identity,session:session,animation:{menu:menuPhase,desktop:desktopPhase,desktopVisible:desktopVisible,fullscreen:fullscreen,reducedMotion:reducedMotion},toast:toastVisible,selectedDate:selectedDate,radios:radios,wallpapers:wallpapers,bar:{width:statusBar.width,contentWidth:statusRow.implicitWidth,scale:statusRow.scale},mediaControls:{x:desktopControls.x+93,y:desktopControls.y+848,scale:desktopStage.scale},calendar:{month:calendar.month,year:calendar.year,selected:calendar.selectedDay}})}
 IpcHandler{target:'design'
  function open(section:string):void{root.open(section)}
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
 component Controls:Row{
  spacing:12;enabled:root.mediaAvailable;opacity:enabled?1:.4
  MotionButton{y:8;label:'󰒮';glyph:true;textSize:24;onTriggered:root.send('previous')}
  MotionButton{label:root.audio.playing?'󰏤':'󰐊';primary:true;glyph:true;textSize:29;onTriggered:root.send('play')}
  MotionButton{y:8;label:'󰓛';glyph:true;textSize:22;onTriggered:root.send('stop')}
  MotionButton{y:8;label:'󰒭';glyph:true;textSize:24;onTriggered:root.send('next')}
 }
 Variants{model:Quickshell.screens
  PanelWindow{required property var modelData;screen:modelData;visible:root.ownWallpaper
   anchors{top:true;bottom:true;left:true;right:true}color:'#081612';exclusionMode:ExclusionMode.Ignore
   WlrLayershell.layer:WlrLayer.Background;WlrLayershell.namespace:'emerald-pixel-background'
   Image{anchors.fill:parent;source:'sky.png';fillMode:Image.PreserveAspectCrop;sourceSize:Qt.size(2560,1440)}
  }
 }
 PanelWindow{
  screen:root.selectedScreen
  anchors{top:true;bottom:true;left:true;right:true}color:'transparent';exclusionMode:ExclusionMode.Ignore
  WlrLayershell.layer:WlrLayer.Bottom;WlrLayershell.namespace:'emerald-desktop';WlrLayershell.keyboardFocus:WlrKeyboardFocus.OnDemand;mask:Region{regions:[Region{item:calendar},Region{item:desktopControls}]}
  Item{id:desktopStage;width:2560;height:1440;scale:Math.min(parent.width/2560,parent.height/1440);transformOrigin:Item.TopLeft
  Item{x:105;y:142;width:570;height:215
   Text{text:Qt.formatTime(root.now,'HH:mm');font.family:'Sansation';font.pixelSize:110;font.weight:Font.Light; font.letterSpacing:-5;color:'#e0ffef'}
   Heading{y:145;text:Qt.formatDate(root.now,'d MMMM');font.pixelSize:33}
   Star{x:405;y:32;rotation:root.desktopPhase*5;opacity:.55+.3*Math.sin(root.desktopPhase)}
   Rectangle{x:0;y:215;width:315;height:1;color:'#456ce0b0'}
  }
  CalendarWidget{id:calendar;x:106;y:400;today:root.now;phase:root.desktopPhase;timer:root.session.timer;surge:root.timerPulse;agenda:root.session.agenda;reducedMotion:root.reducedMotion;onDateActivated:date=>{root.selectedDate=date;root.open('agenda')};onTimerActivated:root.open('timer')}
  Item{x:93;y:848;width:620;height:200;opacity:root.opened?.4:1;Behavior on opacity{NumberAnimation{duration:250}}
   Gravity{x:0;y:0;width:170;height:170;phase:root.desktopPhase;mini:true;bands:root.audio.bands;playing:root.audio.playing}
   Heading{x:190;y:30;width:425;text:root.audio.title;font.pixelSize:29;elide:Text.ElideRight}
   Muted{x:192;y:74;width:420;text:root.mediaArtist;elide:Text.ElideRight}
   Controls{id:desktopControls;objectName:'desktopMediaControls';x:190;y:103}
  }
  }
 }
 PanelWindow{
  id:statusBar;screen:root.selectedScreen;anchors{top:true;right:true}margins{top:4;right:6}implicitWidth:Math.min(statusRow.implicitWidth+16,root.selectedScreen?.width-430||978);implicitHeight:36;color:'transparent';exclusionMode:ExclusionMode.Ignore
  visible:!root.barHidden&&(!root.fullscreen||root.opened)
  WlrLayershell.layer:WlrLayer.Overlay;WlrLayershell.namespace:'emerald-bar'
  Rectangle{anchors.fill:parent;radius:18;color:'#b30b201a';border.width:1;border.color:'#6075c9a9'
   Row{id:statusRow;x:8;y:4;spacing:6;scale:Math.min(1,(statusBar.width-16)/implicitWidth);transformOrigin:Item.TopLeft
    MotionButton{width:36;height:28;label:root.audio.playing?'󰏤':'󰐊';glyph:true;textSize:17;onTriggered:root.send('play')}
    MotionButton{objectName:'barNext';width:30;height:28;label:'󰒭';glyph:true;textSize:17;enabled:root.previewAudio||!!root.nativePlayer?.canGoNext;opacity:enabled?1:.4;onTriggered:root.send('next')}
    MotionButton{width:162;height:28;label:root.audio.title.length>20?root.audio.title.slice(0,19)+'…':root.audio.title;textSize:11;onTriggered:root.open('media')}
    MotionButton{width:67;height:28;label:Math.round(root.defaultSink.volume)+'%';textSize:11;onTriggered:root.open('media');MouseArea{anchors.fill:parent;acceptedButtons:Qt.NoButton;onWheel:w=>{root.command('quick_volume',{delta:w.angleDelta.y>0?5:-5});w.accepted=true}}}
    MotionButton{width:58;height:28;label:root.defaultSource.mute?'Mic ×':'Mic';selected:root.defaultSource.mute;textSize:11;onTriggered:root.command('mic_mute')}
    MotionButton{width:63;height:28;label:'Wi-Fi';textSize:11;selected:root.page==='wifi'&&root.opened;onTriggered:root.open('wifi')}
    MotionButton{width:82;height:28;label:'Bluetooth';textSize:11;selected:root.page==='bluetooth'&&root.opened;onTriggered:root.open('bluetooth')}
    MotionButton{width:72;height:28;label:'✦ '+root.unread;selected:root.page==='notifications'&&root.opened;textSize:12;border.color:root.notificationPulse>0?'#e9ffcc':'#456e5966';onTriggered:root.open('notifications');Rectangle{anchors.centerIn:parent;width:parent.width+16*(1-root.notificationPulse);height:parent.height+8*(1-root.notificationPulse);radius:height/2;color:'transparent';border.width:1;border.color:'#b8ffcf';opacity:root.notificationPulse}}
    MotionButton{width:85;height:28;label:root.t('overview');textSize:11;onTriggered:root.open('overview')}
    MotionButton{width:79;height:28;label:root.session.timer.status==='running'||root.session.timer.status==='paused'?root.durationText(root.session.timer.remaining):root.t('timer');textSize:11;onTriggered:root.open('timer')}
    MotionButton{width:100;height:28;label:Math.round(root.telemetry.cpu)+'% / '+Math.round(root.telemetry.ramPercent||0)+'%';textSize:11;onTriggered:root.open('system')}
    MotionButton{width:40;height:28;label:'⏻';textSize:19;onTriggered:root.open('power')}
   }
  }
 }
 PanelWindow{
  screen:root.selectedScreen;anchors{top:true;right:true}margins{top:58;right:22}implicitWidth:390;implicitHeight:135;color:'transparent';visible:root.toastVisible&&!root.opened&&!root.fullscreen
  exclusionMode:ExclusionMode.Ignore;WlrLayershell.layer:WlrLayer.Overlay;WlrLayershell.namespace:'emerald-toast'
  Rectangle{anchors.fill:parent;radius:20;color:'#bb0b241d';border.width:1;border.color:'#987cddaf'
   UiText{x:22;y:20;width:340;text:root.toastTitle;font.pixelSize:18;maximumLineCount:1;elide:Text.ElideRight}
   UiText{x:22;y:53;width:340;text:root.toastBody;font.pixelSize:13;wrapMode:Text.Wrap;maximumLineCount:3;elide:Text.ElideRight;color:'#b9d5c5'}
   MouseArea{anchors.fill:parent;onClicked:{root.toastVisible=false;root.open('notifications')}}
  }
 }
 PanelWindow{
  id:overlay;screen:root.selectedScreen;anchors{top:true;bottom:true;left:true;right:true}color:'transparent';exclusionMode:ExclusionMode.Ignore
  visible:root.opened||root.opening||root.closing;mask:Region{x:0;y:42;width:overlay.width;height:overlay.height-42}
  WlrLayershell.layer:WlrLayer.Overlay;WlrLayershell.namespace:'emerald-overlay';WlrLayershell.keyboardFocus:root.opened?WlrKeyboardFocus.Exclusive:WlrKeyboardFocus.None
  FocusScope{id:overlayFocus;anchors.fill:parent;focus:true;Keys.onEscapePressed:root.opened=false
   Keys.onPressed:event=>{if(event.modifiers&Qt.AltModifier){let i=event.key-Qt.Key_1;if(i>=0&&i<root.pages.length){root.page=root.pages[i];event.accepted=true}}}
  }
  MouseArea{anchors.fill:parent;onClicked:root.opened=false}
  Item{
   id:panel;scale:Math.max(.1,Math.min(1,(parent.width-36)/1090,(parent.height-78)/822));transformOrigin:Item.TopLeft;x:parent.width-width*scale-18;y:60;width:1090;height:822;Keys.onEscapePressed:root.opened=false
   Keys.onPressed:event=>{if(event.modifiers&Qt.AltModifier){let i=event.key-Qt.Key_1;if(i>=0&&i<root.pages.length){root.page=root.pages[i];event.accepted=true}}}
   MouseArea{anchors.fill:parent;onClicked:{}}
   VaporPanel{anchors.fill:parent;birth:root.birth;death:root.death;opening:root.opening;closing:root.closing;opened:root.opened}
   CosmicTransition{x:-150;y:-60;width:1390;height:942;birth:root.birth;death:root.death;opening:root.opening;closing:root.closing;phase:root.phase;orbitAngle:root.orbitAngle}
   Item{x:310+(30-310)*root.reveal;y:355+(24-355)*root.reveal;scale:root.reveal;opacity:root.reveal
    Star{y:1;font.pixelSize:25;rotation:root.phase*6}
    Label{x:40;y:0;text:'Управление';font.family:'ForestSmooth';font.pixelSize:23;font.letterSpacing:2}
   }
   MotionButton{x:310+(1029-310)*root.reveal;y:355+(25-355)*root.reveal;scale:root.reveal;width:34;height:34;label:'×';textSize:24;opacity:root.reveal;onTriggered:root.opened=false}
   Item{x:0;y:0;width:620;height:700
    Gravity{id:blackHole;x:90;y:135;width:440;height:440;scale:root.hole;opacity:root.hole;phase:root.phase;bands:root.audio.bands;playing:root.audio.playing;warp:root.warp;progress:root.audio.position/root.audio.duration}
    Repeater{model:4
     Item{required property int index
      property real form:root.opening?root.smooth((root.birth-.59-index*.035)/.3):root.closing?1-root.smooth((root.death-.11-index*.055)/.47):root.opened?1:0
      property real angle:(index*90+root.orbitAngle+(root.closing?-330*(1-form):0))*Math.PI/180
      x:310+238*Math.pow(form,1.4)*Math.cos(angle)-42;y:355+238*Math.pow(form,1.4)*Math.sin(angle)-42;width:84;height:84
      activeFocusOnTab:enabled;Keys.onReturnPressed:root.page=root.pages[index];Keys.onSpacePressed:root.page=root.pages[index]
      scale:form;opacity:form;rotation:root.closing?-120*(1-form):0;enabled:form>.95
      Rectangle{anchors.fill:parent;radius:42;color:root.pages[parent.index]===root.page?'#9c174d3b':'#800b2420';border.width:1;border.color:parent.activeFocus?'#efffc9':root.pages[parent.index]===root.page?'#9becce':'#5077a98f'
       scale:hover.containsMouse?1.1:1;Behavior on scale{NumberAnimation{duration:300;easing.type:Easing.OutBack}}
       SpaceIcon{anchors.horizontalCenter:parent.horizontalCenter;y:13;width:25;height:25;kind:root.pages[index];ink:root.pages[index]===root.page?'#a2ffdb':'#c1dfd2'}
       Muted{anchors.horizontalCenter:parent.horizontalCenter;y:49;text:['Signal','Wi-Fi','Bluetooth','System'][index];font.pixelSize:10}
       MouseArea{id:hover;anchors.fill:parent;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;onClicked:root.page=root.pages[index]}
      }
     }
    }
    Muted{id:orbitCaption;x:310+(185-310)*root.reveal;y:355+328*root.reveal;scale:root.reveal;opacity:root.reveal;width:250;text:'SOUND BENDS THE LIGHT';font.letterSpacing:2;horizontalAlignment:Text.AlignHCenter}
   }
   Item{id:content;property real deploy:root.opening?root.smooth((root.birth-.6)/.4):root.closing?1-root.smooth(root.death/.54):root.opened?1:0
    property real spin:root.closing?(1-deploy)*-2.3:0
    x:310+deploy*(300*Math.cos(spin)+239*Math.sin(spin));y:355+deploy*(300*Math.sin(spin)-239*Math.cos(spin));width:430;height:650
    scale:Math.pow(deploy,1.3);opacity:Math.min(1,deploy*2);rotation:root.closing?-100*(1-deploy):(1-deploy)*-8;transformOrigin:Item.TopLeft;enabled:deploy>.95
    AudioPanel{id:audioPanel;anchors.fill:parent;api:root;opacity:root.arrival;transform:Translate{x:28*(1-root.arrival)}
visible:root.page==='media'}
    Loader{id:extraPanel;anchors.fill:parent;opacity:root.arrival;transform:Translate{x:28*(1-root.arrival)}
active:!root.pages.includes(root.page);sourceComponent:({'launcher':launcherComponent,'notifications':notificationsComponent,'overview':overviewComponent,'agenda':agendaComponent,'timer':timerComponent,'power':powerComponent,'wallpapers':wallpaperComponent,'animated':wallpaperComponent})[root.page]||null;onLoaded:root.focusPage()}
    ConnectionPanel{id:connectionPanel;anchors.fill:parent;api:root;visible:root.page==='wifi'||root.page==='bluetooth';opacity:root.arrival}
    Item{anchors.fill:parent;visible:root.page==='system';opacity:root.arrival
     Heading{text:'Система';font.pixelSize:39}
     Muted{y:57;text:'Использование ресурсов'}
     Gravity{x:36;y:75;width:350;height:350;phase:root.phase;galaxy:true}
     Row{x:0;y:431;spacing:38
      Column{spacing:9;Text{text:Math.round(root.telemetry.cpu)+'%';font.family:'Sansation';font.pixelSize:37;color:root.accent}Muted{text:'CPU'}}
      Column{spacing:9;Text{text:Math.round(root.telemetry.ramPercent||0)+'%';font.family:'Sansation';font.pixelSize:37;color:root.accent}Muted{text:'RAM'}}
      Column{spacing:9;Text{text:root.telemetry.processCount;font.family:'Sansation';font.pixelSize:37;color:root.accent}Muted{text:'ПРОЦЕССОВ'}}
     }
     Column{x:0;y:531;spacing:12
      Repeater{model:root.telemetry.top.slice(0,3);Label{required property var modelData;text:'✧   '+modelData.name+'   /   '+Math.round(modelData.rss)+' MiB';font.pixelSize:12}}
     }
    }
   }
   Row{x:34;y:735;spacing:8;opacity:root.reveal;enabled:root.reveal>.95
    Repeater{model:['launcher','notifications','overview','agenda','timer'];UiButton{required property string modelData;width:195;height:33;text:root.t(modelData);selected:root.page===modelData;onClicked:root.page=modelData}}
   }
   UiText{x:620;y:684;width:420;height:40;visible:!!root.session.error;text:root.t(root.session.error);font.pixelSize:11;color:'#f6c8a2';wrapMode:Text.Wrap;maximumLineCount:2;elide:Text.ElideRight}
   Rectangle{x:31;y:783;width:1028;height:1;color:'#2b7bcca9';opacity:root.reveal}
   Muted{x:820;y:797;text:'Tab · Enter · Esc';font.letterSpacing:1.5;font.pixelSize:9;opacity:root.reveal}
  }
 }
 Component{id:launcherComponent;LauncherPanel{api:root}}
 Component{id:notificationsComponent;NotificationPanel{api:root}}
 Component{id:overviewComponent;OverviewPanel{api:root}}
 Component{id:agendaComponent;AgendaPanel{api:root}}
 Component{id:timerComponent;TimerPanel{api:root}}
 Component{id:powerComponent;PowerPanel{api:root}}
 Component{id:wallpaperComponent;WallpaperPanel{api:root}}
}
