import QtQuick
import Quickshell.Services.Notifications
Item {
 id:hub
 required property var api
 property var live:({})
 property var tokens:({})
 property var deadlines:({})
 property var born:({})
 property int revision:0
 property int sequence:0
 property string sessionId:Date.now().toString()
 function bodyText(text){
  return String(text||'').replace(/<\/?(?:b|i|u)\s*>|<\/?a(?:\s+[^<>]*)?>|<img(?:\s+[^<>]*)?\/?>/gi,'').replace(/&(#x[0-9a-f]+|#[0-9]+|lt|gt|amp|quot|apos|nbsp);/gi,(entity,name)=>{
   let names={lt:'<',gt:'>',amp:'&',quot:'"',apos:"'",nbsp:'\u00a0'};
   if(name[0]!=='#')return names[name.toLowerCase()]||entity;
   let code=name[1].toLowerCase()==='x'?parseInt(name.slice(2),16):parseInt(name.slice(1),10);
   return code>0&&code<=0x10ffff&&!(code>=0xd800&&code<=0xdfff)?String.fromCodePoint(code):'\ufffd';
  }).slice(0,4096);
 }

 function ref(item){
  let r=revision;
  if(!item||item.session!==sessionId||tokens[item.sourceId]!==item.actionToken)return null;
  let n=live[item.sourceId];
  return n&&n.tracked&&(!deadlines[n.id]||deadlines[n.id]>Date.now())?n:null;
 }
 function actions(item){let n=ref(item);return n?n.actions.filter(a=>a.identifier!=='inline-reply').map(a=>({text:a.identifier==='default'?api.t('notification_open'):a.text,identifier:a.identifier})).slice(0,6):[]}
 function canReply(item){let n=ref(item);return !!n&&n.hasInlineReply}
 function invoke(item,identifier){
  let n=ref(item);if(!n)return false;
  let action=n.actions.find(a=>a.identifier===identifier);if(!action)return false;
  action.invoke();hub.revision++;return true;
 }
 function activate(item){return invoke(item,'default')}
 function reply(item,text){let n=ref(item);if(!n||!n.hasInlineReply||!String(text).trim())return false;n.sendInlineReply(String(text).slice(0,4096));hub.revision++;return true}
 function dismiss(item){let n=ref(item);if(n)n.dismiss();hub.revision++}
 function receive(n){
  // Popup lifetime and action lifetime are separate. Default notifications remain
  // actionable in history, bounded by the same retention policy and live cap.
  if(server.trackedNotifications.values.length>=200)server.trackedNotifications.values[0].dismiss();
  n.tracked=true;
  let id=n.id,token=sessionId+':'+(++sequence),h=n.hints||{};
  live[id]=n;tokens[id]=token;born[id]=Date.now();
  // Quickshell 0.2.1 preserves the DBus millisecond timeout (verified live).
  deadlines[id]=n.expireTimeout>0?Date.now()+n.expireTimeout:0;
  n.closed.connect(()=>{delete hub.live[id];delete hub.tokens[id];delete hub.deadlines[id];delete hub.born[id];hub.revision++});
  let conversation=String(h['x-kde-origin-name']||h['x-telegram-chat-name']||'');
  let conversationId=String(h['x-telegram-chat-id']||h['x-event-horizon-conversation-id']||conversation);
  let item={sourceId:id,session:sessionId,actionToken:token,app:String(n.appName||'System').slice(0,160),desktopEntry:String(n.desktopEntry).slice(0,200),summary:String(n.summary||'').slice(0,512),body:bodyText(n.body),conversation:conversation.slice(0,200),conversationId:conversationId.slice(0,200)};
  if(!n.transient)api.command('notify',Object.assign({},item,{body:String(n.body||'').slice(0,16384)}));
  if(!(api.session.preferences||{}).dnd)api.showToast(item.summary,item.body,item);
  hub.revision++;
 }
 NotificationServer {
  id:server
  actionsSupported:true;bodySupported:true;persistenceSupported:true;inlineReplySupported:true
  onNotification:n=>hub.receive(n)
 }
 Timer {
  interval:1000;repeat:true;running:true
  onTriggered:{
   let now=Date.now();
   server.trackedNotifications.values.slice().forEach(n=>{if(hub.deadlines[n.id]&&hub.deadlines[n.id]<=now)n.expire()});
   // Pruned history must not retain unlimited DBus notification objects.
   let history=hub.api.session.notifications||[],known={};
   history.forEach(x=>{if(x.session===hub.sessionId)known[x.actionToken]=true});
   Object.keys(hub.live).forEach(id=>{
    let n=hub.live[id];if(!n||!n.tracked){delete hub.live[id];delete hub.tokens[id];delete hub.deadlines[id];delete hub.born[id];return}
    let retained=known[hub.tokens[id]];
    let created=hub.born[id]||now;
    if(!retained&&now-created>10000&&(!hub.api.toastItem||hub.api.toastItem.actionToken!==hub.tokens[id]))n.expire();
   });
  }
 }
}
