import QtQuick
Item {
 id:desktop
 required property var api
 property alias calendar:calendarWidget
 property alias controlItem:desktopControls
 property var defaults:api.session.layout?.defaults||({clock:{x:105/2560,y:142/1440,scale:1,visible:true},calendar:{x:106/2560,y:400/1440,scale:1,visible:true},media:{x:93/2560,y:848/1440,scale:1,visible:true}})
 readonly property string monitor:api.selectedScreen?.name||'unknown'
 readonly property string wallpaper:api.session.layout?.wallpaper||''
 property bool wallpaperSpecific:true
 readonly property string contextWallpaper:wallpaperSpecific?wallpaper:''
 readonly property string contextKey:JSON.stringify([monitor,contextWallpaper])
 readonly property var saved:api.session.layout?.profiles?.[contextKey]||api.session.layout?.profiles?.[JSON.stringify([monitor,''])]||defaults
 property var draft:null
 readonly property var widgets:draft||saved
 readonly property bool dirty:!!draft&&JSON.stringify(draft)!==JSON.stringify(saved)
 readonly property real baseScale:Math.min(width/2560,height/1440)
 readonly property var mediaControls:({x:mediaFrame.x+desktopControls.x*mediaFrame.contentScale,y:mediaFrame.y+desktopControls.y*mediaFrame.contentScale,width:desktopControls.width*mediaFrame.contentScale,height:desktopControls.height*mediaFrame.contentScale,scale:mediaFrame.contentScale,visible:mediaFrame.visible})
 readonly property var calendarRegion:({x:calendarFrame.x,y:calendarFrame.y,width:calendarFrame.width,height:calendarFrame.height,visible:calendarFrame.visible})
 readonly property bool editing:api.layoutEditing
 onContextKeyChanged:{draft=null;if(api.layoutEditing)api.layoutEditing=false}
 function copy(value){return JSON.parse(JSON.stringify(value))}
 function update(name,change){let next=copy(widgets);next[name]=Object.assign({},next[name],change);draft=next}
 function toggle(name){update(name,{visible:!widgets[name].visible})}
 function beginEditing(){if(!draft)draft=copy(saved);api.layoutEditing=true;api.opened=false;forceActiveFocus()}
 function cancel(){draft=null;api.layoutEditing=false}
 function reset(){draft=copy(defaults)}
 function save(){api.command('layout_save',{monitor:monitor,wallpaper:contextWallpaper,widgets:copy(widgets)});api.layoutEditing=false}
 function resetProfile(){api.command('layout_reset',{monitor:monitor,wallpaper:contextWallpaper});draft=null}
 function visibleInProfile(name){return api.session.profiles?.activeWidgets?.[name]!==false}
 Keys.onEscapePressed:cancel()
 Shortcut{sequence:'Escape';enabled:desktop.editing;context:Qt.WindowShortcut;onActivated:desktop.cancel()}
 Image{anchors.fill:parent;visible:desktop.editing;source:desktop.editing?(api.session.layout?.background||'sky.png'):'';fillMode:Image.PreserveAspectCrop;asynchronous:true;cache:false;sourceSize:Qt.size(width,height)}
 Canvas{anchors.fill:parent;visible:desktop.editing;opacity:.14
  onWidthChanged:requestPaint();onHeightChanged:requestPaint();onVisibleChanged:requestPaint()
  onPaint:{let c=getContext('2d');c.reset();c.fillStyle='#a3f9d4';for(let x=0;x<width;x+=16)for(let y=48;y<height;y+=16)c.fillRect(x,y,1,1)}
 }
 component Frame:Item {
  id:frame
  required property string widgetName
  objectName:'widget-'+widgetName
  required property string title
  required property real designWidth
  required property real designHeight
  property var placement:desktop.widgets[widgetName]
  property real contentScale:Math.min(desktop.baseScale*placement.scale,desktop.width/designWidth,Math.max(0,desktop.height-48)/designHeight)
  x:Math.max(0,Math.min(desktop.width-width,placement.x*desktop.width))
  y:Math.max(48,Math.min(desktop.height-height,placement.y*desktop.height))
  width:designWidth*contentScale;height:designHeight*contentScale
  visible:desktop.editing||(placement.visible&&desktop.visibleInProfile(widgetName))
  opacity:desktop.editing&&(!placement.visible||!desktop.visibleInProfile(widgetName))?.4:1
  default property alias contents:body.data
  Item{id:body;width:frame.designWidth;height:frame.designHeight;scale:frame.contentScale;transformOrigin:Item.TopLeft;enabled:!desktop.editing}
  Rectangle{anchors.fill:parent;visible:desktop.editing;color:'#180e382b';radius:10;border.color:dragArea.pressed?'#edffc9':'#8bcaa994';border.width:1}
  MouseArea{id:dragArea;objectName:'drag-'+frame.widgetName;anchors.fill:parent;enabled:desktop.editing;cursorShape:pressed?Qt.ClosedHandCursor:Qt.OpenHandCursor
   property point origin;property point start
   onPressed:mouse=>{origin=mapToItem(desktop,mouse.x,mouse.y);start=Qt.point(frame.x,frame.y);desktop.forceActiveFocus()}
   onPositionChanged:mouse=>{if(!pressed)return;let point=mapToItem(desktop,mouse.x,mouse.y);let x=Math.max(0,Math.min(desktop.width-frame.width,Math.round((start.x+point.x-origin.x)/16)*16));let y=Math.max(48,Math.min(desktop.height-frame.height,Math.round((start.y+point.y-origin.y)/16)*16));desktop.update(frame.widgetName,{x:x/desktop.width,y:y/desktop.height})}
  }
  UiText{x:10;y:frame.y>=68?-20:8;visible:desktop.editing;text:frame.title+(frame.placement.visible?'':' · скрыт');font.pixelSize:12;color:'#d9ffe9';style:Text.Outline;styleColor:'#081d16'}
  Rectangle{visible:desktop.editing;anchors.right:parent.right;anchors.bottom:parent.bottom;width:28;height:28;radius:6;color:'#b20c3025';border.color:'#8ee6bc'
   UiText{anchors.centerIn:parent;text:'↘';font.pixelSize:19}
   MouseArea{objectName:'resize-'+frame.widgetName;anchors.fill:parent;cursorShape:Qt.SizeFDiagCursor;property point origin;property real initialScale
    onPressed:mouse=>{origin=mapToItem(desktop,mouse.x,mouse.y);initialScale=frame.placement.scale}
    onPositionChanged:mouse=>{if(!pressed)return;let point=mapToItem(desktop,mouse.x,mouse.y);let delta=((point.x-origin.x)/frame.designWidth+(point.y-origin.y)/frame.designHeight)/2/desktop.baseScale;desktop.update(frame.widgetName,{scale:Math.max(.55,Math.min(1.6,Math.round((initialScale+delta)*20)/20))})}
   }
  }
 }
 Frame{widgetName:'clock';title:'Часы';designWidth:570;designHeight:225
  Text{text:Qt.formatTime(desktop.api.now,'HH:mm');font.family:'Sansation';font.pixelSize:110;font.weight:Font.Light;font.letterSpacing:-5;color:'#e0ffef'}
  UiText{y:145;text:Qt.formatDate(desktop.api.now,'d MMMM');font.family:'ForestSmooth';font.pixelSize:33}
  UiText{x:405;y:32;text:'✦';font.pixelSize:20;color:desktop.api.accent;rotation:desktop.api.desktopPhase*5;opacity:.55+.3*Math.sin(desktop.api.desktopPhase)}
  Rectangle{y:215;width:315;height:1;color:'#456ce0b0'}
 }
 Frame{id:calendarFrame;widgetName:'calendar';title:'Календарь';designWidth:572;designHeight:410
  CalendarWidget{id:calendarWidget;today:desktop.api.now;phase:desktop.api.desktopPhase;timer:desktop.api.session.timer;surge:desktop.api.timerPulse;agenda:desktop.api.session.agenda;reducedMotion:desktop.api.reducedMotion;onDateActivated:date=>{desktop.api.selectedDate=date;desktop.api.open('agenda')};onTimerActivated:desktop.api.open('timer')}
 }
 Frame{id:mediaFrame;widgetName:'media';title:'Музыка';designWidth:620;designHeight:200
  Item{width:620;height:200;opacity:desktop.api.opened?.4:1;Behavior on opacity{NumberAnimation{duration:250}}
   Gravity{width:170;height:170;phase:desktop.api.desktopPhase;mini:true;bands:desktop.api.audio.bands;playing:desktop.api.audio.playing}
   UiText{x:190;y:30;width:425;text:desktop.api.audio.title;font.family:'ForestSmooth';font.pixelSize:29;elide:Text.ElideRight}
   UiText{x:192;y:74;width:420;text:desktop.api.mediaArtist;font.pixelSize:11;color:'#a6c9bb';elide:Text.ElideRight}
   Row{id:desktopControls;objectName:'desktopMediaControls';x:190;y:103;spacing:12;enabled:desktop.api.mediaAvailable;opacity:enabled?1:.4
    MotionButton{y:8;label:'󰒮';glyph:true;textSize:24;onTriggered:desktop.api.send('previous')}
    MotionButton{label:desktop.api.audio.playing?'󰏤':'󰐊';primary:true;glyph:true;textSize:29;onTriggered:desktop.api.send('play')}
    MotionButton{y:8;label:'󰒭';glyph:true;textSize:24;onTriggered:desktop.api.send('next')}
   }
  }
 }
 Rectangle{id:toolbar;z:100;visible:desktop.editing;anchors.horizontalCenter:parent.horizontalCenter;y:58;width:Math.min(700,parent.width-24);height:118;radius:18;color:'#e00b241d';border.color:'#75c9a9'
  UiText{x:16;y:12;width:parent.width-32;text:'Перетащи виджет · угол ↘ меняет размер · сетка 16 px';font.pixelSize:13;elide:Text.ElideRight}
  Row{x:16;y:44;spacing:8
   Repeater{model:[{key:'clock',name:'Часы'},{key:'calendar',name:'Календарь'},{key:'media',name:'Музыка'}]
    UiButton{required property var modelData;width:103;height:28;text:modelData.name;selected:desktop.widgets[modelData.key].visible;onClicked:desktop.toggle(modelData.key)}
   }
  }
  Row{anchors.right:parent.right;anchors.rightMargin:16;y:80;spacing:8
   UiButton{width:110;height:28;text:'Сбросить';onClicked:desktop.reset()}
   UiButton{width:110;height:28;text:'Отмена';onClicked:desktop.cancel()}
   UiButton{width:110;height:28;text:'Сохранить';selected:true;onClicked:desktop.save()}
  }
 }
}
