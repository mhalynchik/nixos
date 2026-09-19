import QtQuick
import QtQuick.Controls
Item{
 id:p;required property var api
 property string group:''
 property var groups:Array.from(new Set((api.session.notifications||[]).map(n=>n.app)))
 property var entries:(api.session.notifications||[]).filter(n=>!group||n.app===group).slice().reverse()
 function focusFirst(){dnd.forceActiveFocus()}
 UiText{text:api.t('notifications');font.family:'ForestSmooth';font.pixelSize:35}
 Row{y:55;spacing:8
  UiButton{id:dnd;width:170;text:api.t('dnd');selected:!!(api.session.preferences||{}).dnd;onClicked:api.command('setting',{key:'dnd',value:!selected})}
  UiButton{width:220;text:api.t('clear_read');onClicked:api.command('clear_read')}
 }
 UiComboBox{y:105;width:400;model:[api.t('all_notifications')].concat(p.groups);onActivated:p.group=currentIndex===0?'':p.groups[currentIndex-1];font.family:'Sansation'}
 ListView{id:list;y:160;width:parent.width;height:380;clip:true;spacing:10;model:p.entries;ScrollBar.vertical:ScrollBar{}
  delegate:Rectangle{required property var modelData;width:list.width-10;height:Math.max(130,body.y+body.implicitHeight+52);radius:16;color:modelData.read?'#20102e25':'#3d124433';border.width:1;border.color:modelData.read?'#3069a486':'#787de6b8'
   UiText{x:14;y:12;width:parent.width-60;text:modelData.app+' · '+Qt.formatTime(new Date(modelData.time*1000),'HH:mm');font.pixelSize:11;color:'#9eccb6';elide:Text.ElideRight}
   UiButton{x:parent.width-42;y:6;width:30;height:28;text:'×';onClicked:api.command('remove_notification',{id:modelData.id})}
   UiText{x:14;y:36;width:parent.width-28;text:modelData.summary;font.bold:true;wrapMode:Text.Wrap;maximumLineCount:2;elide:Text.ElideRight}
   UiText{id:body;x:14;y:84;width:parent.width-28;text:modelData.body;wrapMode:Text.Wrap;maximumLineCount:4;elide:Text.ElideRight;font.pixelSize:13;color:'#b6d9c8'}
   Row{x:14;y:parent.height-38;spacing:6
    Repeater{model:api.notificationActions(modelData);UiButton{required property var modelData;width:Math.min(180,implicitWidth);height:28;text:modelData.text;onClicked:api.invokeNotification(modelData.notificationId,modelData.index)}}
   }
  }
 }
 UiText{y:200;width:parent.width;visible:p.entries.length===0;text:api.t('empty_notifications');wrapMode:Text.Wrap;color:'#9dbdac'}
 UiButton{y:552;width:280;text:api.t('mark_read');enabled:p.entries.some(n=>!n.read);onClicked:{if(p.group)api.command('read_group',{app:p.group});else p.groups.forEach(g=>api.command('read_group',{app:g}))}}
}
