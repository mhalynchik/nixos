import QtQuick
import Quickshell.Services.Notifications
Item{
 id:hub;required property var api
 property var live:({})
 property int revision:0
 property var deadlines:({})
 property string sessionId:Date.now().toString()
 NotificationServer{id:server;actionsSupported:true;bodySupported:true;persistenceSupported:true
  onNotification:n=>{
   if(server.trackedNotifications.values.length>=200)server.trackedNotifications.values[0].dismiss();n.tracked=true;hub.live[n.id]=n;hub.deadlines[n.id]=n.expireTimeout===0?0:Date.now()+Math.max(1000,n.expireTimeout<0?5000:n.expireTimeout);hub.revision++;
   api.command('notify',{sourceId:n.id,session:hub.sessionId,app:n.appName||'System',summary:n.summary,body:n.body});
   if(!(api.session.preferences||{}).dnd)api.showToast(n.summary,n.body);
  }
 }
 function actions(item){let r=revision;let n=live[item.sourceId];if(item.session!==sessionId||!n||!n.tracked)return [];return n.actions.map((a,i)=>({text:a.text,index:i,notificationId:item.sourceId})).slice(0,2)}
 function dismiss(item){let n=live[item.sourceId];if(item.session===sessionId&&n&&n.tracked)n.dismiss()}
 function invoke(id,index){let n=live[id];if(n&&n.tracked&&n.actions[index]){n.actions[index].invoke();revision++}}
 Timer{interval:1000;repeat:true;running:true;onTriggered:{server.trackedNotifications.values.forEach(n=>{if(hub.deadlines[n.id]&&hub.deadlines[n.id]<Date.now())n.expire()});let ids=server.trackedNotifications.values.map(n=>n.id);Object.keys(hub.live).forEach(id=>{if(!ids.includes(Number(id))){delete hub.live[id];delete hub.deadlines[id]}});hub.revision++}}
}
