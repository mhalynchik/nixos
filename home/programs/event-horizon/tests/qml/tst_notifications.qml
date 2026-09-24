import QtQuick
import QtTest
import "../../ui" as Shell
Item{
 width:1000;height:720
 QtObject{
  id:api
  property var session:({notifications:[],preferences:{dnd:false},notificationPolicies:{}})
  property var toastItem:({app:'Telegram'})
  property string toastTitle:'A message'
  property string toastBody:'Short body'
  property var calls:[]
  function t(key){return key}
  function command(action,args){calls=calls.concat([{action:action,args:args}])}
  function notificationActions(item){return []}
  function notificationCanReply(item){return true}
  function invokeNotification(item,identifier){calls=calls.concat([{action:identifier}]);return true}
  function activateNotification(item){calls=calls.concat([{action:'default'}]);return true}
  function replyNotification(item,text){return true}
  function showPage(page){calls=calls.concat([{action:page}])}
 }
 Shell.NotificationPanel{id:panel;width:430;height:640;api:api}
 Shell.NotificationToast{id:toast;x:500;width:390;height:implicitHeight;api:api}
 SignalSpy{id:dismissal;target:toast;signalName:'dismissed'}
 TestCase{
  name:'Notifications';when:windowShown
  function item(id,app,time,conversationId){return {id:id,app:app,time:time,summary:'Title '+id,body:'Body',read:false,conversationId:conversationId||'',conversation:conversationId?'Chat '+conversationId:''}}
  function init(){api.calls=[];dismissal.clear();api.toastBody='Short body';api.session={notifications:[],preferences:{dnd:false},notificationPolicies:{}};panel.group='';panel.conversation=null;panel.configure=false}
  function test_groups_sorted_by_latest_and_count_unread(){
   let read=item('2','Mail',2);read.read=true;
   api.session={notifications:[item('1','Telegram',1),read,item('3','Mail',3)],preferences:{}};
   compare(panel.rows.length,2);compare(panel.rows[0].label,'Mail');compare(panel.rows[0].count,2);compare(panel.rows[0].unread,1);
   panel.openGroup(panel.rows[0]);compare(panel.group,'Mail');compare(panel.rows.length,2);compare(panel.rows[0].id,'3');
  }
  function test_real_conversation_metadata_creates_subgroups(){
   api.session={notifications:[item('1','Telegram',1,'123'),item('2','Telegram',2,'456'),item('3','Telegram',3,'123'),item('4','Telegram',4)],preferences:{}};
   panel.openGroup(panel.rows[0]);verify(panel.hasChats);compare(panel.rows.length,3);
   let row=panel.rows.find(r=>r.key==='123');compare(row.count,2);panel.openGroup(row);compare(panel.rows.length,2);compare(panel.rows[0].id,'3');
   panel.back();compare(panel.conversation,null);panel.back();compare(panel.group,'');
  }
  function test_same_summary_does_not_invent_chat_group(){
   let one=item('1','Telegram',1),two=item('2','Telegram',2);one.summary='Alice';two.summary='Alice';
   api.session={notifications:[one,two],preferences:{}};panel.openGroup(panel.rows[0]);verify(!panel.hasChats);compare(panel.rows.length,2);
  }
  function test_reply_draft_and_expansion_survive_incoming_notification(){
   let existing=item('draft','Telegram',1);existing.body='A long technical message. '.repeat(7);
   api.session={notifications:[existing],preferences:{}};panel.openGroup(panel.rows[0]);wait(30);
   let card=findChild(panel,'notification-card-draft'),reply=findChild(panel,'notification-reply-draft'),expand=findChild(panel,'notification-expand-draft');
   verify(card);verify(reply);verify(expand);expand.clicked();reply.clicked();
   let input=findChild(panel,'notification-draft-draft');verify(input);input.forceActiveFocus();keyClick(Qt.Key_O);keyClick(Qt.Key_K);
   compare(input.text,'ok');verify(card.replyOpened);verify(card.bodyExpanded);verify(input.activeFocus,'focus before incoming');
   api.session={notifications:[existing,item('new','Telegram',2)],preferences:{}};wait(30);
   compare(findChild(panel,'notification-card-draft'),card,'Existing delegate survives row insertion');
   compare(input.text,'ok');verify(card.replyOpened,'reply stays open');verify(card.bodyExpanded,'body stays expanded');verify(input.activeFocus,'reply keeps keyboard focus');
   let read=Object.assign({},existing,{read:true});api.session={notifications:[read,item('new','Telegram',2)],preferences:{}};wait(30);
   compare(findChild(panel,'notification-card-draft'),card);compare(input.text,'ok');verify(card.replyOpened);verify(card.bodyExpanded);
  }
  function test_toast_adapts_height_to_body(){
   wait(20);let shortHeight=toast.implicitHeight;
   api.toastBody='Several lines of text make a compact notification grow only when its content needs room. '.repeat(8);wait(20);
   verify(toast.implicitHeight>shortHeight);verify(toast.implicitHeight<310);
   api.toastBody='';wait(20);verify(toast.implicitHeight<shortHeight);
  }
  function test_toast_body_invokes_default_action(){
   mouseClick(toast,50,65);compare(api.calls.length,1);compare(api.calls[0].action,'default');compare(dismissal.count,1);
  }
 }
}
