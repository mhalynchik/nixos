import QtQuick
Item {
 id:p;required property var api
 enabled:!!api.session.idle
 property bool initialized:false
 property var saved:api.session.idle||{lockMinutes:10,screenMinutes:15,suspendMinutes:30}
 readonly property bool valid:lockField.acceptableInput&&screenField.acceptableInput&&sleepField.acceptableInput
 readonly property bool ordered:(!Number(lockField.text)||!Number(screenField.text)||Number(screenField.text)>=Number(lockField.text))&&(!Number(lockField.text)||!Number(sleepField.text)||Number(sleepField.text)>=Number(lockField.text))
 readonly property bool dirty:Number(lockField.text)!==saved.lockMinutes||Number(screenField.text)!==saved.screenMinutes||Number(sleepField.text)!==saved.suspendMinutes
 function load(values){lockField.text=String(values.lockMinutes);screenField.text=String(values.screenMinutes);sleepField.text=String(values.suspendMinutes)}
 function focusFirst(){lockField.forceActiveFocus()}
 Component.onCompleted:{load(saved);initialized=!!api.session.idle}
 onSavedChanged:if(!initialized&&api.session.idle){Qt.callLater(()=>{load(saved);initialized=true})}
 UiText{text:api.t('settings');font.family:'ForestSmooth';font.pixelSize:35}
 UiText{y:57;width:410;text:api.t('idle_description');wrapMode:Text.Wrap;color:'#9cbea9';font.pixelSize:13}
 UiText{y:121;text:api.t('idle_lock')}
 UiText{y:149;text:api.t('idle_minutes');color:'#9cbea9';font.pixelSize:12}
 UiField{id:lockField;objectName:'idle-lock';x:285;y:115;width:110;validator:IntValidator{bottom:0;top:240}
 inputMethodHints:Qt.ImhDigitsOnly;Accessible.name:api.t('idle_lock')}
 UiText{y:216;text:api.t('idle_screen')}
 UiText{y:244;text:api.t('idle_minutes');color:'#9cbea9';font.pixelSize:12}
 UiField{id:screenField;objectName:'idle-screen';x:285;y:210;width:110;validator:IntValidator{bottom:0;top:240}
 inputMethodHints:Qt.ImhDigitsOnly;Accessible.name:api.t('idle_screen')}
 UiText{y:311;text:api.t('idle_suspend')}
 UiText{y:339;text:api.t('idle_minutes');color:'#9cbea9';font.pixelSize:12}
 UiField{id:sleepField;objectName:'idle-suspend';x:285;y:305;width:110;validator:IntValidator{bottom:0;top:240}
 inputMethodHints:Qt.ImhDigitsOnly;Accessible.name:api.t('idle_suspend')}
 UiText{y:385;width:405;height:65;text:!p.valid?api.t('idle_range'):!p.ordered?api.t('idle_order'):api.t('idle_sleep_lock');wrapMode:Text.Wrap;color:!p.valid||!p.ordered?'#f6c8a2':'#9cbea9';font.pixelSize:13}
 Row{y:470;spacing:10
  UiButton{objectName:'idle-apply';width:193;text:api.t('apply');enabled:p.valid&&p.ordered&&p.dirty;selected:enabled;onClicked:api.command('idle_settings',{lockMinutes:Number(lockField.text),screenMinutes:Number(screenField.text),suspendMinutes:Number(sleepField.text)})}
  UiButton{objectName:'idle-cancel';width:193;text:api.t('cancel');enabled:p.dirty;onClicked:p.load(p.saved)}
 }
 UiText{y:525;width:405;text:api.t(p.dirty?'idle_unsaved':'idle_saved');wrapMode:Text.Wrap;color:'#9cbea9';font.pixelSize:12}
}
