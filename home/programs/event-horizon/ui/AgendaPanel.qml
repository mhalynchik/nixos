import QtQuick
import QtQuick.Controls
Item{
 id:p;required property var api
 property string date:api.selectedDate
 property var entries:(api.session.agenda||[]).filter(x=>x.date===date).sort((a,b)=>(a.time||'99').localeCompare(b.time||'99'))
 property string deleting:''
 function focusFirst(){title.forceActiveFocus()}
 UiText{text:api.t('agenda');font.family:'ForestSmooth';font.pixelSize:35}
 UiField{id:day;y:53;width:150;text:p.date;inputMask:'9999-99-99';onEditingFinished:api.selectedDate=text}
 UiButton{x:170;y:55;width:100;text:'‹';onClicked:{let d=new Date(p.date+'T12:00:00');d.setDate(d.getDate()-1);api.selectedDate=Qt.formatDate(d,'yyyy-MM-dd')}}
 UiButton{x:280;y:55;width:100;text:'›';onClicked:{let d=new Date(p.date+'T12:00:00');d.setDate(d.getDate()+1);api.selectedDate=Qt.formatDate(d,'yyyy-MM-dd')}}
 UiField{id:title;y:110;width:parent.width;placeholderText:api.t('task_hint');maximumLength:240;onAccepted:add('task')}
 UiField{id:at;y:162;width:100;placeholderText:api.t('time_hint');maximumLength:5}
 function add(kind){api.command('add_task',{date:p.date,title:title.text,time:at.text,kind:kind})}
 Connections{target:api;function onTaskAdded(){title.clear();at.clear()}}
 UiButton{x:114;y:165;width:140;text:'+ '+api.t('add_task');onClicked:p.add('task')}
 UiButton{x:264;y:165;width:140;text:'+ '+api.t('add_event');onClicked:p.add('event')}
 ListView{id:list;y:224;width:parent.width;height:385;clip:true;spacing:10;model:p.entries;ScrollBar.vertical:ScrollBar{}
  delegate:Rectangle{required property var modelData;width:list.width-10;height:94;radius:16;color:'#26133129';border.width:1;border.color:'#3d73a487'
   UiButton{x:9;y:18;width:36;height:36;text:modelData.done?'✓':'○';selected:modelData.done;onClicked:api.command('toggle_task',{id:modelData.id})}
   UiText{x:58;y:14;width:parent.width-112;text:modelData.title;wrapMode:Text.Wrap;maximumLineCount:2;elide:Text.ElideRight;font.strikeout:modelData.done;color:modelData.done?'#8aaa9b':'#e2f9ed'}
   UiText{x:58;y:67;text:(modelData.time?modelData.time+' · ':'')+api.t(modelData.kind==='task'?'add_task':'add_event');font.pixelSize:11;color:'#9cbcac'}
   UiButton{x:parent.width-44;y:14;width:32;height:28;text:p.deleting===modelData.id?'✓':'×';onClicked:{if(p.deleting===modelData.id){api.command('delete_task',{id:modelData.id});p.deleting=''}else p.deleting=modelData.id}
 ToolTip.visible:hovered;ToolTip.text:api.t(p.deleting===modelData.id?'confirm_delete':'delete')}
  }
 }
 UiText{y:265;width:parent.width;visible:p.entries.length===0;text:api.t('empty_agenda');wrapMode:Text.Wrap;color:'#9dbdac'}
}
