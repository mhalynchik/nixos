import QtQuick
import QtQuick.Controls
Item {
 id:p
 required property var api
 property var history:api.session.clipboard||{items:[],paused:false}
 property var filtered:(history.items||[]).filter(item=>item.preview.toLowerCase().indexOf(search.text.toLowerCase())!==-1)
 function focusFirst(){search.forceActiveFocus()}
 function copy(item){api.command('clipboard_copy',{id:item.id})}
 UiText{text:p.api.t('clipboard_title');font.family:'ForestSmooth';font.pixelSize:35}
 Row{y:55;spacing:8
  UiButton{width:196;text:p.history.paused?p.api.t('clipboard_resume'):p.api.t('clipboard_pause');selected:p.history.paused;onClicked:p.api.command('clipboard_pause',{value:!p.history.paused})}
  UiButton{width:196;text:confirmClear.visible?p.api.t('cancel'):p.api.t('clipboard_clear');onClicked:confirmClear.visible=!confirmClear.visible}
 }
 UiButton{id:confirmClear;visible:false;y:99;width:400;text:p.api.t('clipboard_clear_confirm');onClicked:{p.api.command('clipboard_clear');visible=false}}
 UiField{id:search;y:confirmClear.visible?142:105;width:400;placeholderText:p.api.t('clipboard_search');onAccepted:if(p.filtered.length)p.copy(p.filtered[0])}
 ListView{id:list;x:0;y:search.y+54;width:400;height:Math.min(420,p.height-y-75);clip:true;spacing:7;model:p.filtered;ScrollBar.vertical:ScrollBar{}
  delegate:Rectangle{required property var modelData;width:list.width-10;height:90;radius:15;color:'#30234539';border.color:modelData.pinned?'#769ddcb5':'#3062957d'
   UiButton{x:4;y:4;width:parent.width-84;height:82;onClicked:p.copy(modelData)
    contentItem:Item{
     Image{id:thumb;anchors.left:parent.left;anchors.verticalCenter:parent.verticalCenter;width:76;height:62;visible:!!modelData.thumbnail&&status===Image.Ready;source:modelData.thumbnail||'';sourceSize.width:160;sourceSize.height:160;fillMode:Image.PreserveAspectFit;asynchronous:true;cache:false}
     Column{x:thumb.visible?86:0;width:parent.width-x;anchors.verticalCenter:parent.verticalCenter;spacing:5
     UiText{width:parent.width;text:(modelData.pinned?'◆  ':'')+(modelData.mime.startsWith('image/')?p.api.t('clipboard_image'):'')+modelData.preview;font.pixelSize:14;wrapMode:Text.Wrap;maximumLineCount:2;elide:Text.ElideRight}
     UiText{width:parent.width;text:Qt.formatDateTime(new Date(modelData.time*1000),'dd.MM · HH:mm')+p.api.t('clipboard_copy_hint');font.pixelSize:11;color:'#9bbbad';elide:Text.ElideRight}
     }
    }
   }
   UiButton{x:parent.width-76;y:5;width:70;height:35;text:modelData.pinned?p.api.t('clipboard_unpin'):p.api.t('clipboard_pin');font.pixelSize:10;selected:!!modelData.pinned;onClicked:p.api.command('clipboard_pin',{id:modelData.id})}
   UiButton{x:parent.width-76;y:47;width:70;height:35;text:p.api.t('delete');font.pixelSize:11;onClicked:p.api.command('clipboard_delete',{id:modelData.id})}
  }
 }
 UiText{y:list.y+20;width:400;text:p.history.error?p.api.t('clipboard_unavailable'):p.history.paused?p.api.t('clipboard_paused'):p.api.t('clipboard_empty');visible:p.filtered.length===0;horizontalAlignment:Text.AlignHCenter;color:'#9bbbad'}
 UiText{y:list.y+list.height+12;width:400;font.pixelSize:11;color:'#9bbbad';wrapMode:Text.Wrap;text:p.api.t('clipboard_privacy')}
}
