import QtQuick
import QtQuick.Controls
Item {
 id:p
 required property var api
 property bool wifi:api.page==='wifi'
 property var radioState:(wifi?api.radios.wifi:api.radios.bluetooth)||({})
 property var rows:(wifi?radioState.networks:radioState.devices)||[]
 property string selectedId:''
 property string forgetId:''
 function focusFirst(){refresh.forceActiveFocus()}
 function act(action, extra){api.radioCommand(action,extra)}
 onWifiChanged:{selectedId='';forgetId=''}
 onVisibleChanged:if(!visible)selectedId=''
 ListModel{id:connectionRows;dynamicRoles:true}
 onRowsChanged:{
  for(let i=0;i<rows.length;i++){
   let found=-1;
   for(let j=i;j<connectionRows.count;j++)if(connectionRows.get(j).entry.id===rows[i].id){found=j;break}
   if(found<0)connectionRows.insert(i,{entry:rows[i]});
   else {if(found!==i)connectionRows.move(found,i,1);connectionRows.setProperty(i,'entry',rows[i])}
  }
  if(connectionRows.count>rows.length)connectionRows.remove(rows.length,connectionRows.count-rows.length)
 }

 UiText{text:p.wifi?'Wi-Fi':'Bluetooth';font.family:'ForestSmooth';font.pixelSize:35}
 Row{y:59;spacing:8
  UiButton{id:refresh;objectName:'radioRefresh';width:130;text:p.radioState.busy||p.radioState.scanning?'Поиск…':'Обновить';enabled:!!p.radioState.adapter&&!p.radioState.busy&&!p.radioState.scanning&&(p.wifi?p.radioState.canScan===true:p.radioState.enabled===true);onClicked:p.act(p.wifi?'wifi_scan':'bt_scan')}
  UiButton{objectName:'radioPower';width:170;text:p.radioState.enabled?'Выключить':'Включить';selected:p.radioState.enabled===true;enabled:!!p.radioState.adapter&&!p.radioState.busy&&(!p.wifi||p.radioState.hardwareEnabled!==false);onClicked:p.act(p.wifi?'wifi_power':'bt_power',{enabled:!p.radioState.enabled})}
 }
 UiText{objectName:'radioStatus';y:110;width:420;text:p.wifi&&p.radioState.blockedReason?p.radioState.blockedReason:!p.radioState.adapter?'Адаптер не найден':!p.radioState.enabled?'Радиомодуль выключен':p.radioState.connecting?'Подключение…':p.rows.length?'Выбери сеть или устройство':'Пока ничего не найдено';font.pixelSize:12;color:'#a4c9b7'}
 ListView{id:list;y:142;width:430;height:350;clip:true;spacing:9;model:connectionRows;ScrollBar.vertical:ScrollBar{}
  delegate:Rectangle{
   id:card;required property var entry;property var modelData:entry;required property int index
   onChosenChanged:if(!chosen)password.clear()
   property bool chosen:p.selectedId===modelData.id
   width:418;height:chosen?(p.wifi?modelData.hidden?239:195:145):76;radius:17;color:chosen?'#66184b39':'#35132722';border.width:1;border.color:modelData.connected?'#ac83edbb':'#506d9b83'
   Behavior on height{NumberAnimation{duration:260;easing.type:Easing.OutCubic}}
   UiButton{anchors{left:parent.left;right:parent.right;top:parent.top}height:76;padding:15;text:'';background:Item{}
    contentItem:Column{spacing:8
     UiText{width:parent.width;text:card.modelData.name;font.pixelSize:16;elide:Text.ElideRight}
     UiText{width:parent.width;font.pixelSize:11;color:'#a1c9b7';text:(card.modelData.connected?'● Подключено · ':'')+(p.wifi?card.modelData.strength+'% · '+({'open':'Открытая','wpa-psk':'WPA / WPA2','sae':'WPA3','wep':'WEP','enterprise':'802.1X'})[card.modelData.security]+(card.modelData.saved?' · Сохранена':''):card.modelData.paired?'Сопряжено'+(card.modelData.battery>=0?' · '+card.modelData.battery+'%':''):'Новое устройство')}
    }
    onClicked:{p.selectedId=card.chosen?'':card.modelData.id;p.forgetId=''}
   }
   Column{visible:card.chosen;x:13;y:83;width:392;spacing:8
    UiField{id:ssid;visible:p.wifi&&!!card.modelData.hidden;width:parent.width;height:36;placeholderText:'Имя скрытой сети'}
    UiField{id:password;objectName:'wifiPassword';visible:p.wifi&&card.modelData.security!=='open';width:parent.width;height:38;echoMode:TextInput.Password;placeholderText:card.modelData.saved?'Пароль (пусто — использовать сохранённый)':'Пароль сети';font.pixelSize:12
     onAccepted:connect.clicked()
    }
    Row{spacing:8
     UiButton{id:connect;width:192;height:36;enabled:!p.radioState.busy;text:p.radioState.busy?'Подключение…':card.modelData.connected?'Отключить':card.modelData.paired||p.wifi?'Подключить':'Сопрячь и подключить'
      onClicked:{p.act(p.wifi?(card.modelData.connected?'wifi_disconnect':'wifi_connect'):(card.modelData.connected?'bt_disconnect':'bt_connect'),{id:card.modelData.id,password:password.text,ssid:ssid.text});password.clear()}
     }
     UiButton{visible:!p.wifi&&!!card.modelData.paired;width:174;height:36;text:p.forgetId===card.modelData.id?'Подтвердить удаление':'Забыть';enabled:!p.radioState.busy;onClicked:{if(p.forgetId===card.modelData.id){p.act('bt_forget',{id:card.modelData.id});p.forgetId=''}else p.forgetId=card.modelData.id}}
    }
   }
  }
 }
 Rectangle{visible:!p.wifi&&!!p.radioState.request;x:0;y:142;width:420;height:290;radius:18;color:'#ed102c23';border.width:1;border.color:'#93dfb6'
  property var request:p.radioState.request||({})
  Column{x:18;y:16;width:384;spacing:14
   UiText{width:parent.width;text:'Сопряжение · '+(parent.parent.request.name||'');wrapMode:Text.Wrap;font.pixelSize:17}
   UiText{width:parent.width;text:parent.parent.request.kind==='RequestConfirmation'?'Код совпадает на обоих устройствах?':(parent.parent.request.kind||'').startsWith('Display')?'Введи этот код на устройстве:':'Подтверди подключение или введи код устройства.';wrapMode:Text.Wrap}
   UiText{text:parent.parent.request.code||'';font.pixelSize:28;color:'#9ef5c5'}
   UiField{id:pin;visible:['RequestPinCode','RequestPasskey'].includes(parent.parent.request.kind);width:parent.width;placeholderText:'Код устройства'}
   Row{spacing:10
    UiButton{width:174;text:'Подтвердить';visible:!(p.radioState.request?.kind||'').startsWith('Display');onClicked:{p.act('bt_reply',{accept:true,value:pin.text});pin.clear()}}
    UiButton{width:160;text:'Отмена';onClicked:p.act('bt_reply',{accept:false})}
   }
  }
 }
 UiText{y:507;width:420;height:49;text:p.radioState.error||'';wrapMode:Text.Wrap;maximumLineCount:4;elide:Text.ElideRight;font.pixelSize:12;color:'#f5c49f'}
 UiButton{y:566;width:230;height:32;text:'Расширенные настройки';onClicked:api.command('open_connection_settings',{kind:p.wifi?'wifi':'bluetooth'})}
}
