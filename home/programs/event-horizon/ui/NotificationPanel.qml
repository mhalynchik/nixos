import QtQuick
import QtQuick.Controls
Item {
 id:p
 required property var api
 property string group:''
 property var conversation:null
 property bool configure:false
 property var all:api.session.notifications||[]
 property var entries:all.filter(n=>n.app===group&&(conversation===null||(n.conversationId||'')===conversation)).slice().reverse()
 property var groups:makeGroups(all,'app')
 property bool hasChats:group!==''&&all.some(n=>n.app===group&&!!n.conversationId)
 property bool groupList:group===''||(hasChats&&conversation===null)
 property var rows:group===''?groups:(hasChats&&conversation===null?makeGroups(entries,'conversationId'):entries)
 onRowsChanged:syncRows()
 Component.onCompleted:syncRows()
 property var activeReply:null
 ListModel{id:stableRows}
 function rowIdentity(row){return row.latest?JSON.stringify(['group',row.app,row.key]):JSON.stringify(['entry',row.id])}
 function syncRows(){
  let focused=activeReply&&activeReply.activeFocus?activeReply:null;
  let selected=list.currentIndex>=0&&list.currentIndex<stableRows.count?stableRows.get(list.currentIndex).rowKey:'';
  let wanted=rows.map(row=>rowIdentity(row));
  for(let i=stableRows.count-1;i>=0;i--)if(!wanted.includes(stableRows.get(i).rowKey))stableRows.remove(i);
  for(let i=0;i<rows.length;i++){
   let key=wanted[i],payload=JSON.stringify(rows[i]),existing=-1;
   for(let j=i;j<stableRows.count;j++)if(stableRows.get(j).rowKey===key){existing=j;break}
   if(existing<0)stableRows.insert(i,{rowKey:key,payload:payload,bodyExpanded:false,replyOpened:false,draftText:''});
   else{if(existing!==i)stableRows.move(existing,i,1);if(stableRows.get(i).payload!==payload)stableRows.setProperty(i,'payload',payload)}
  }
  if(selected&&wanted.includes(selected))list.currentIndex=wanted.indexOf(selected);
  if(focused)Qt.callLater(()=>{if(focused&&focused.visible)focused.forceActiveFocus()});
 }
 function setRowState(key,name,value){for(let i=0;i<stableRows.count;i++)if(stableRows.get(i).rowKey===key){stableRows.setProperty(i,name,value);return}}
 property var retention:(api.session.notificationPolicies||{})[group]||({days:7,limit:200})
 function makeGroups(items,key){
  let result=[],map={};
  items.slice().sort((a,b)=>b.time-a.time).forEach(n=>{
   let value=n[key]||'',id='$'+value;
   if(!map[id]){map[id]={key:value,app:n.app,label:key==='app'?n.app:(n.conversation||api.t('notification_other')),latest:n,count:0,unread:0};result.push(map[id])}
   map[id].count++;if(!n.read)map[id].unread++;
  });return result;
 }
 function focusFirst(){dnd.forceActiveFocus()}
 function groupArgs(){let args={app:group};if(conversation!==null)args.conversation=conversation;return args}
 function openGroup(row){if(!group){group=row.key;conversation=null}else conversation=row.key;configure=false}
 function back(){if(conversation!==null)conversation=null;else group='';configure=false}
 UiText{text:api.t('notifications');font.family:'ForestSmooth';font.pixelSize:35}
 Row{y:51;spacing:8
  UiButton{id:dnd;width:150;text:api.t('dnd');selected:!!(api.session.preferences||{}).dnd;onClicked:api.command('setting',{key:'dnd',value:!selected})}
  UiButton{width:166;text:api.t('clear_read');onClicked:api.command('clear_read')}
 }
 Row{y:99;spacing:8
  UiButton{visible:p.group!=='';width:36;text:'‹';Accessible.name:api.t('back');onClicked:p.back()}
  UiText{anchors.verticalCenter:parent.verticalCenter;width:p.group?230:330;text:p.group?(p.conversation!==null?(p.entries[0]?.conversation||api.t('notification_other')):p.group):api.t('notification_sources');font.pixelSize:17;elide:Text.ElideRight}
  UiButton{visible:p.group!=='';width:42;text:'⚙';Accessible.name:api.t('notification_retention');selected:p.configure;onClicked:p.configure=!p.configure}
 }
 Column{
  id:settings;y:147;width:parent.width;spacing:8;visible:p.configure
  UiText{width:parent.width;text:api.t('notification_retention');font.pixelSize:16}
  Row{spacing:8
   UiComboBox{id:days;width:172;model:[1,3,7,30].map(x=>x+' '+api.t('notification_days'));currentIndex:Math.max(0,[1,3,7,30].indexOf(p.retention.days))}
   UiComboBox{id:limit;width:172;model:[20,50,100,200].map(x=>x+' '+api.t('notification_items'));currentIndex:Math.max(0,[20,50,100,200].indexOf(p.retention.limit))}
  }
  UiText{width:parent.width;text:api.t('notification_retention_hint');font.pixelSize:12;color:'#9fc6b3';wrapMode:Text.Wrap}
  UiButton{text:api.t('save');onClicked:{api.command('notification_policy',{app:p.group,days:[1,3,7,30][days.currentIndex],limit:[20,50,100,200][limit.currentIndex]});p.configure=false}}
 }
 ListView{
  id:list;y:p.configure?settings.y+settings.implicitHeight+14:147;width:parent.width;height:Math.max(80,parent.height-y-62);clip:true;spacing:8;model:stableRows
  ScrollBar.vertical:ScrollBar{}
  delegate:Rectangle {
   id:card
   required property string rowKey
   required property string payload
   required property bool bodyExpanded
   required property bool replyOpened
   required property string draftText
   property var modelData:JSON.parse(payload)
   objectName:'notification-card-'+(modelData.id||rowKey)
   property bool isGroup:!!modelData.latest
   property var entry:Object.assign({summary:"",body:"",read:true,time:0},isGroup?modelData.latest:modelData)
   property var actions:card.isGroup?[]:api.notificationActions(entry)
   width:list.width-10;height:content.implicitHeight+24;radius:14
   color:(card.isGroup?modelData.unread===0:entry.read)?'#24102e25':'#50124433'
   border.width:1;border.color:(card.isGroup?modelData.unread===0:entry.read)?'#3069a486':'#607de6b8'
   Column{
    id:content;x:12;y:12;width:parent.width-24;spacing:7
    Row{
     width:parent.width;spacing:6
     UiText{width:parent.width-36;font.pixelSize:card.isGroup?16:11;font.bold:card.isGroup;color:'#a9d9c2';elide:Text.ElideRight;text:card.isGroup?card.modelData.label+'  ·  '+card.modelData.count+(card.modelData.unread?'  /  '+card.modelData.unread+' '+api.t('notification_unread'):''):Qt.formatDateTime(new Date(card.entry.time*1000),'dd MMM · HH:mm')}
     UiButton{width:28;height:24;text:'×';Accessible.name:api.t('notification_delete');onClicked:{if(card.isGroup){let args={app:card.modelData.app};if(p.group)args.conversation=card.modelData.key;api.command('remove_notification_group',args)}else api.command('remove_notification',{id:card.entry.id})}}
    }
    UiText{width:parent.width;text:card.entry.summary;font.pixelSize:16;font.bold:true;wrapMode:Text.Wrap;maximumLineCount:card.bodyExpanded?100:2;elide:Text.ElideRight}
    UiText{width:parent.width;visible:text.length>0;text:card.entry.body;font.pixelSize:14;color:'#c0dccd';wrapMode:Text.Wrap;maximumLineCount:card.bodyExpanded?100:(card.isGroup?1:3);elide:Text.ElideRight}
    Flow{
     width:parent.width;spacing:6
     UiButton{visible:card.isGroup;height:28;implicitWidth:156;text:api.t('notification_expand');onClicked:p.openGroup(card.modelData)}
     Repeater{model:card.actions;UiButton{required property var modelData;height:28;implicitWidth:Math.min(165,contentItem.implicitWidth+24);text:modelData.text;onClicked:{api.invokeNotification(card.entry,modelData.identifier);api.command('read_notification',{id:card.entry.id})}}}
     UiButton{visible:!card.isGroup&&api.notificationCanReply(card.entry);height:28;implicitWidth:110;text:api.t('notification_reply');objectName:'notification-reply-'+card.entry.id;onClicked:{p.setRowState(card.rowKey,'replyOpened',!card.replyOpened);if(card.replyOpened)replyInput.forceActiveFocus()}}
     UiButton{visible:!card.isGroup&&(card.entry.body.length>140||card.entry.summary.length>80);height:28;implicitWidth:92;text:api.t(card.bodyExpanded?'notification_less':'notification_more');objectName:'notification-expand-'+card.entry.id;onClicked:p.setRowState(card.rowKey,'bodyExpanded',!card.bodyExpanded)}
     UiButton{visible:!card.isGroup&&!card.entry.read;height:28;implicitWidth:126;text:api.t('notification_read');onClicked:api.command('read_notification',{id:card.entry.id})}
    }
    Row{
     visible:card.replyOpened;spacing:6;width:parent.width
     UiField{id:replyInput;objectName:'notification-draft-'+card.entry.id;width:parent.width-88;placeholderText:api.t('notification_reply');text:card.draftText;maximumLength:4096;onActiveFocusChanged:if(activeFocus)p.activeReply=replyInput;onTextEdited:p.setRowState(card.rowKey,'draftText',text);onAccepted:sendReply.clicked()}
     UiButton{id:sendReply;width:82;text:api.t('notification_send');enabled:replyInput.text.trim().length>0&&api.notificationCanReply(card.entry);onClicked:{if(api.replyNotification(card.entry,replyInput.text)){p.setRowState(card.rowKey,'draftText','');p.setRowState(card.rowKey,'replyOpened',false);api.command('read_notification',{id:card.entry.id})}}}
    }
   }
  }
 }
 UiText{y:list.y+36;width:parent.width;visible:p.rows.length===0;text:api.t('empty_notifications');wrapMode:Text.Wrap;color:'#9dbdac'}
 Row{y:parent.height-46;spacing:8
  UiButton{width:180;text:api.t('mark_read');enabled:p.all.some(n=>!n.read);onClicked:{if(p.group)api.command('read_group',p.groupArgs());else p.groups.forEach(g=>api.command('read_group',{app:g.key}))}}
  UiButton{width:166;visible:p.group!=='';text:api.t('notification_clear_group');onClicked:api.command('remove_notification_group',p.groupArgs())}
 }
}
