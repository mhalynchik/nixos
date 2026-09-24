import QtQuick
Item {
 id:p;required property var api
 function focusFirst(){buttons.itemAt(0).forceActiveFocus()}
 UiText{text:api.t('tools');font.family:'ForestSmooth';font.pixelSize:35}
 UiText{y:58;width:410;text:api.t('tools_description');font.pixelSize:13;color:'#a1c5b3';wrapMode:Text.Wrap}
 Column{y:124;spacing:14;Repeater{id:buttons;model:['clipboard','capture','layout','profiles','settings'];UiButton{required property string modelData;width:410;height:66;text:api.t(modelData);onClicked:api.showPage(modelData)}}}
 UiText{y:560;width:410;text:api.t('tools_shortcuts');font.pixelSize:12;color:'#a1c5b3';wrapMode:Text.Wrap}
}
