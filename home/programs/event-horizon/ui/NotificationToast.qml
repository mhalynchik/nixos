import QtQuick
import QtQuick.Controls
Rectangle {
 id:toast
 required property var api
 property var item:api.toastItem||({})
 property var actions:api.notificationActions(item)
 property bool hovered:hoverDetector.hovered
 signal dismissed()
 implicitHeight:contents.implicitHeight+28
 radius:18;color:'#d00b241d';border.width:1;border.color:'#987cddaf'
 HoverHandler{id:hoverDetector}
 MouseArea{id:hover;anchors.fill:parent;hoverEnabled:true;onClicked:{if(!toast.api.activateNotification(toast.item))toast.api.showPage('notifications');toast.dismissed()}}
 Column {
  id:contents;x:16;y:14;width:parent.width-32;spacing:8
  Row {
   width:parent.width;spacing:8
   UiText{width:parent.width-38;anchors.verticalCenter:parent.verticalCenter;text:toast.item.app||toast.api.t('notifications');font.pixelSize:12;color:'#92cbb0';elide:Text.ElideRight}
   UiButton{width:30;height:26;text:'×';Accessible.name:toast.api.t('close');onClicked:toast.dismissed()}
  }
  UiText{width:parent.width;text:toast.api.toastTitle;font.pixelSize:18;font.bold:true;wrapMode:Text.Wrap;maximumLineCount:2;elide:Text.ElideRight}
  UiText{width:parent.width;visible:text.length>0;text:toast.api.toastBody;font.pixelSize:15;color:'#c9e5d7';wrapMode:Text.Wrap;maximumLineCount:4;elide:Text.ElideRight}
  Flow {
   width:parent.width;spacing:6
   Repeater{model:toast.actions;UiButton{required property var modelData;implicitWidth:Math.min(190,contentItem.implicitWidth+24);height:30;text:modelData.text;onClicked:{toast.api.invokeNotification(toast.item,modelData.identifier);toast.dismissed()}}}
   UiButton{implicitWidth:110;height:30;text:toast.api.t('notification_history');onClicked:{toast.dismissed();toast.api.showPage('notifications')}}
  }
 }
}
