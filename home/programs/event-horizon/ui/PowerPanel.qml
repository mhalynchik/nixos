import QtQuick
Item{
 id:p;required property var api
 property string selected:''
 function focusFirst(){lockButton.forceActiveFocus()}
 UiText{text:'Питание';font.family:'ForestSmooth';font.pixelSize:38}
 UiText{y:61;width:420;text:'Управление сеансом и компьютером';font.pixelSize:13;color:'#aad0bc'}
 Column{y:115;spacing:12
  UiButton{id:lockButton;width:410;height:54;text:'Заблокировать';onClicked:api.command('power',{operation:'lock'})}
  Repeater{model:[{id:'suspend',name:'Сон'},{id:'logout',name:'Завершить сеанс'},{id:'reboot',name:'Перезагрузить'},{id:'poweroff',name:'Выключить'}]
   UiButton{required property var modelData;width:410;height:54;text:modelData.name;selected:p.selected===modelData.id;onClicked:p.selected=modelData.id}
  }
 }
 UiText{y:462;width:420;text:p.selected?'Сохрани работу перед продолжением.':'';font.pixelSize:14;color:'#c1ddc7';wrapMode:Text.Wrap}
 Row{y:511;spacing:12;visible:p.selected!==''
  UiButton{width:230;height:47;text:'Подтвердить';selected:true;onClicked:api.command('power',{operation:p.selected})}
  UiButton{width:168;height:47;text:'Отмена';onClicked:p.selected=''}
 }
}
