import QtQuick
import QtQuick.Controls
Item{
 id:p;required property var api
 property string selected:''
 property var windows:(api.session.desktop||{}).windows||[]
 property var spaces:Array.from(new Set([1,2,3,4].concat(((api.session.desktop||{}).workspaces||[]).map(w=>w.id).filter(id=>id>0)))).sort((a,b)=>a-b)
 function focusFirst(){if(cards.count)cards.itemAt(0).focusButton()}
 UiText{text:api.t('overview');font.family:'ForestSmooth';font.pixelSize:35}
 UiText{y:51;width:parent.width;text:api.t('overview_help');wrapMode:Text.Wrap;font.pixelSize:12;color:'#9dc4b1'}
 Flickable{y:98;width:parent.width;height:500;contentHeight:grid.height;clip:true;ScrollBar.vertical:ScrollBar{}
  Column{id:grid;width:parent.width-12;spacing:12
   Repeater{id:cards;model:p.spaces
    Rectangle{id:card;required property int modelData
     property var items:p.windows.filter(w=>w.workspace===modelData)
     width:grid.width;height:Math.max(146,92+items.length*44);radius:18;color:drop.containsDrag?'#65377558':'#30122d25';border.width:1;border.color:drop.containsDrag?'#c1ffdb':'#4964927e'
     function focusButton(){jump.forceActiveFocus()}
     UiButton{id:jump;x:12;y:10;width:185;height:32;text:api.t('workspace')+' '+card.modelData;onClicked:api.command('workspace',{workspace:card.modelData})}
     UiButton{x:210;y:10;width:190;height:32;text:api.t('move');enabled:p.selected!=='';onClicked:api.command('move_window',{address:p.selected,workspace:card.modelData})}
     UiText{x:16;y:66;text:api.t('empty_workspace');visible:card.items.length===0;font.pixelSize:13;color:'#8bac9b'}
     Column{x:12;y:56;spacing:7
      Repeater{model:card.items
       Item{id:tile;required property var modelData;width:card.width-24;height:38
        Rectangle{id:drag;property string address:tile.modelData.address;y:0;width:parent.width-72;height:38;radius:10;color:p.selected===address?'#75478166':'#46234b39';border.color:focusArea.activeFocus?'#efffca':'#52628870';border.width:focusArea.activeFocus?2:1
         Drag.active:mouse.drag.active;Drag.keys:['orbit-window'];Drag.hotSpot.x:width/2;Drag.hotSpot.y:19
         UiText{x:10;anchors.verticalCenter:parent.verticalCenter;width:parent.width-20;text:tile.modelData.app+' · '+tile.modelData.title;elide:Text.ElideRight;font.pixelSize:12}
         FocusScope{id:focusArea;anchors.fill:parent;activeFocusOnTab:true;Keys.onSpacePressed:p.selected=tile.modelData.address;Keys.onReturnPressed:api.command('focus_window',{address:tile.modelData.address})}
         MouseArea{id:mouse;anchors.fill:parent;drag.target:drag;onPressed:{p.selected=tile.modelData.address;focusArea.forceActiveFocus()}
 onReleased:{drag.Drag.drop();drag.x=0;drag.y=0}
 onDoubleClicked:api.command('focus_window',{address:tile.modelData.address})}
        }
        UiButton{x:parent.width-65;width:62;height:38;text:'↗';onClicked:api.command('focus_window',{address:tile.modelData.address})}
       }
      }
     }
     DropArea{id:drop;anchors.fill:parent;keys:['orbit-window'];onDropped:event=>{api.command('move_window',{address:event.source.address,workspace:card.modelData});event.acceptProposedAction()}}
    }
   }
  }
 }
}
