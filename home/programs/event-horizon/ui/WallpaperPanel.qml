import QtQuick
import QtQuick.Controls
Item{
 id:p;required property var api
 property string kind:api.page==='animated'?'animated':'static'
 property var entries:(api.wallpapers.items||[]).filter(x=>x.kind===kind)
 property string selected:''
 property string pendingPreview:''
 function focusFirst(){grid.forceActiveFocus()}
 function choose(id){selected=id;pendingPreview=id;hoverDelay.restart()}
 function commit(){if(selected){hoverDelay.stop();api.wallpaperCommand('commit',{id:selected})}}
 onVisibleChanged:if(!visible)hoverDelay.stop()
 onKindChanged:{hoverDelay.stop();selected='';api.wallpaperCommand('cancel')}
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
 GridView{id:grid;y:151;width:430;height:340;cellWidth:214;cellHeight:157;clip:true;model:p.entries;activeFocusOnTab:true;keyNavigationEnabled:true;ScrollBar.vertical:ScrollBar{}
  Keys.onReturnPressed:p.commit()
  Keys.onEnterPressed:p.commit()
  onCurrentIndexChanged:if(activeFocus&&currentIndex>=0&&currentIndex<p.entries.length)p.choose(p.entries[currentIndex].id)
  delegate:Rectangle{
   id:tile;required property var modelData;required property int index
   width:204;height:146;radius:14;color:'#57102c23';border.width:p.selected===modelData.id?2:1;border.color:p.selected===modelData.id?'#beffd1':'#507eb495'
   Image{x:5;y:5;width:194;height:108;source:tile.modelData.thumbnail;sourceSize:Qt.size(240,150);asynchronous:true;fillMode:Image.PreserveAspectCrop}
   UiText{x:11;y:118;width:182;text:tile.modelData.name;font.pixelSize:11;elide:Text.ElideMiddle}
   UiText{anchors.centerIn:parent;text:p.kind==='animated'&&!tile.modelData.thumbnail?'▶':'';font.pixelSize:26;color:'#b2f5ce'}
   MouseArea{anchors.fill:parent;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;onEntered:{grid.currentIndex=tile.index;grid.forceActiveFocus();p.choose(tile.modelData.id)}onClicked:{p.choose(tile.modelData.id);grid.forceActiveFocus()}onDoubleClicked:p.commit()}
   Component.onCompleted:if(p.kind==='animated'&&!modelData.thumbnail)p.api.wallpaperCommand('thumbnail',{id:modelData.id})
  }
 }
 UiText{y:205;width:420;visible:p.entries.length===0;text:'Здесь пока нет файлов.\nДобавь их в папку:\n'+((api.wallpapers.directories||{})[p.kind]||[]).join('\n');wrapMode:Text.Wrap;color:'#bfdac6'}
 UiText{y:507;width:420;height:49;text:api.wallpapers.error||'';wrapMode:Text.Wrap;maximumLineCount:3;elide:Text.ElideRight;font.pixelSize:12;color:'#f1c49e'}
 Row{y:566;spacing:10
  UiButton{width:220;text:'Установить';selected:true;enabled:!!p.selected;onClicked:p.commit()}
  UiButton{width:185;text:'Отмена';onClicked:{hoverDelay.stop();api.opened=false}}
 }
}
