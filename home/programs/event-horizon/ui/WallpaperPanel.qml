import QtQuick
import QtQuick.Controls
Item{
 id:p;required property var api
 property string kind:api.page==='animated'?'animated':'static'
 property var entries:(api.wallpapers.items||[]).filter(x=>x.kind===kind)
 property string selected:''
 property bool committing:false
 property bool syncing:false
 ListModel{id:wallpaperRows;dynamicRoles:true}
 onEntriesChanged:{
  syncing=true
  for(let i=0;i<entries.length;i++){
   let found=-1
   for(let j=i;j<wallpaperRows.count;j++)if(wallpaperRows.get(j).entry.id===entries[i].id){found=j;break}
   if(found<0)wallpaperRows.insert(i,{entry:entries[i]})
   else {if(found!==i)wallpaperRows.move(found,i,1);if(JSON.stringify(wallpaperRows.get(i).entry)!==JSON.stringify(entries[i]))wallpaperRows.setProperty(i,'entry',entries[i])}
  }
  if(wallpaperRows.count>entries.length)wallpaperRows.remove(entries.length,wallpaperRows.count-entries.length)
  let current=entries.findIndex(x=>x.id===selected)
  if(selected&&current<0){selected='';pendingPreview='';hoverDelay.stop()}
  if(current>=0)grid.currentIndex=current
  syncing=false
  if(api.opened&&!selected&&entries.length)Qt.callLater(focusFirst)
 }
 Connections{target:p.api
  function onWallpapersChanged(){if(p.api.wallpapers.error)p.committing=false}
  function onOpenedChanged(){
   hoverDelay.stop();p.pendingPreview='';p.committing=false
   if(p.api.opened&&['wallpapers','animated'].includes(p.api.page)){p.api.wallpaperCommand('index');Qt.callLater(p.focusFirst)}
  }
 }
 property string pendingPreview:''
 function focusFirst(){grid.forceActiveFocus();if(grid.currentIndex>=0&&grid.currentIndex<entries.length)choose(entries[grid.currentIndex].id)}
 function choose(id){if(committing||syncing||!visible||!api.opened||pendingPreview===id)return;selected=id;pendingPreview=id;hoverDelay.restart()}
 function commit(){if(selected&&!committing){committing=true;hoverDelay.stop();pendingPreview='';api.wallpaperCommand('commit',{id:selected})}}
 onVisibleChanged:if(!visible){hoverDelay.stop();pendingPreview='';committing=false}
 onKindChanged:{hoverDelay.stop();selected='';pendingPreview='';committing=false;api.wallpaperCommand('cancel');api.wallpaperCommand('index');Qt.callLater(focusFirst)}
 Component.onCompleted:api.wallpaperCommand('index')
 Component.onDestruction:hoverDelay.stop()
 Timer{id:hoverDelay;interval:240;onTriggered:if(p.visible&&p.pendingPreview)p.api.wallpaperCommand('preview',{id:p.pendingPreview})}
 UiText{text:p.kind==='animated'?'Живые обои':'Обои';font.family:'ForestSmooth';font.pixelSize:36}
 Row{y:59;spacing:8
  UiButton{width:146;text:'Изображения';selected:p.kind==='static';onClicked:api.page='wallpapers'}
  UiButton{width:146;text:'Анимации';selected:p.kind==='animated';onClicked:api.page='animated'}
  UiButton{width:114;text:'Обновить';onClicked:api.wallpaperCommand('index')}
 }
 UiText{y:108;width:420;text:'Наведи для предпросмотра · Enter — установить · Esc — отменить';font.pixelSize:12;color:'#add0b9';wrapMode:Text.Wrap}
 GridView{id:grid;objectName:'wallpaperGrid';y:151;width:430;height:340;cellWidth:214;cellHeight:157;clip:true;model:wallpaperRows;activeFocusOnTab:true;keyNavigationEnabled:true;ScrollBar.vertical:ScrollBar{}
  Keys.onReturnPressed:p.commit()
  Keys.onEnterPressed:p.commit()
  onCurrentIndexChanged:if(!p.syncing&&activeFocus&&currentIndex>=0&&currentIndex<p.entries.length)p.choose(p.entries[currentIndex].id)
  delegate:Rectangle{
   id:tile;required property var entry;property var modelData:entry;required property int index;objectName:'wallpaperTile'+index
   width:204;height:146;radius:14;color:'#57102c23';border.width:p.selected===modelData.id?2:1;border.color:p.selected===modelData.id?'#beffd1':'#507eb495'
   Image{x:5;y:5;width:194;height:108;source:tile.modelData.thumbnail;sourceSize:Qt.size(240,150);asynchronous:true;fillMode:Image.PreserveAspectCrop}
   UiText{x:11;y:118;width:182;text:tile.modelData.name;font.pixelSize:11;elide:Text.ElideMiddle}
   UiText{anchors.centerIn:parent;text:p.kind==='animated'&&!tile.modelData.thumbnail?'▶':'';font.pixelSize:26;color:'#b2f5ce'}
   MouseArea{anchors.fill:parent;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;onEntered:{if(p.committing||p.syncing)return;grid.currentIndex=tile.index;grid.forceActiveFocus();p.choose(tile.modelData.id)}onClicked:{p.choose(tile.modelData.id);grid.forceActiveFocus()}onDoubleClicked:p.commit()}
   Component.onCompleted:if(p.kind==='animated'&&!modelData.thumbnail)p.api.wallpaperCommand('thumbnail',{id:modelData.id})
  }
 }
 UiText{y:205;width:420;visible:p.entries.length===0;text:'Здесь пока нет файлов.\nДобавь их в папку:\n'+((api.wallpapers.directories||{})[p.kind]||[]).join('\n');wrapMode:Text.Wrap;color:'#bfdac6'}
 UiText{y:507;width:420;height:49;text:api.wallpapers.error||'';wrapMode:Text.Wrap;maximumLineCount:3;elide:Text.ElideRight;font.pixelSize:12;color:'#f1c49e'}
 Row{y:566;spacing:10
  UiButton{width:220;text:p.committing?'Установка…':'Установить';selected:true;enabled:!!p.selected&&!p.committing;onClicked:p.commit()}
  UiButton{width:185;text:'Отмена';onClicked:{hoverDelay.stop();api.opened=false}}
 }
}
