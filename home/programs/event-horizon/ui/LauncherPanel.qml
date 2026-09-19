import QtQuick
import QtQuick.Controls
Item{
 id:p
 required property var api
 function focusFirst(){search.forceActiveFocus();search.selectAll()}
 Component.onCompleted:api.command('search',{query:''})
 UiText{text:api.t('launcher');font.family:'ForestSmooth';font.pixelSize:35}
 UiButton{x:300;y:4;width:120;height:30;text:api.t('refresh');onClicked:api.command('refresh')}
 UiField{id:search;y:56;width:parent.width;placeholderText:api.t('search_hint');onTextEdited:debounce.restart();Keys.onDownPressed:{results.currentIndex=Math.min(results.count-1,results.currentIndex+1)}
 Keys.onUpPressed:{results.currentIndex=Math.max(0,results.currentIndex-1)}
 onAccepted:if(results.count>0)p.api.command('launch',{id:p.api.session.search[results.currentIndex].id})}
 Timer{id:debounce;interval:100;onTriggered:{api.command('search',{query:search.text});results.currentIndex=0}}
 UiText{y:110;text:api.t(search.text.length?'search_hint':'recent');font.pixelSize:12;color:'#9bbbad'}
 ListView{id:results;y:142;width:parent.width;height:416;clip:true;spacing:8;model:api.session.search||[];currentIndex:0;keyNavigationEnabled:true;ScrollBar.vertical:ScrollBar{}
  delegate:UiButton{required property var modelData;required property int index;width:results.width-10;height:64;selected:ListView.isCurrentItem
   contentItem:Column{spacing:5;UiText{width:parent.width;text:modelData.name;font.pixelSize:16;elide:Text.ElideRight;color:parent.parent.selected?'#07281c':'#e5fff1'}UiText{width:parent.width;text:p.api.t(modelData.kind)+(modelData.kind==='file'?' · '+modelData.keywords:'');font.pixelSize:11;elide:Text.ElideMiddle;color:parent.parent.selected?'#174b36':'#8fbdab'}}
   onClicked:p.api.command('launch',{id:modelData.id})
  }
 }
 UiText{y:190;width:parent.width;visible:results.count===0;text:api.t('no_results');horizontalAlignment:Text.AlignHCenter;color:'#9bbbad'}
 UiText{y:584;width:parent.width;text:api.t('files_scope');font.pixelSize:11;color:'#8eb1a0';wrapMode:Text.Wrap}
}
