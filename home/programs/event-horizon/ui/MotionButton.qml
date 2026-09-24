import QtQuick
import QtQuick.Controls
Rectangle {
 id:b
 property string label:""
 property string iconName:""
 property string tooltip:""
 Accessible.name:tooltip||label
 property bool selected:false
 property bool glyph:false
 property bool primary:false
 property color accent:"#63d7ad"
 property int textSize:13
 signal triggered()
 width:primary?60:44;height:primary?60:44
 radius:mouse.pressed?12:height/2
 color:primary||selected?accent:mouse.containsMouse?'#80345b4a':'#4521372e'
 border.color:activeFocus?'#efffca':mouse.containsMouse?'#8fecbe':'#456e5966';border.width:activeFocus?2:1
 scale:mouse.pressed?.90:mouse.containsMouse?1.06:1
 Behavior on radius{NumberAnimation{duration:240;easing.type:Easing.OutBack}}
 Behavior on scale{NumberAnimation{duration:240;easing.type:Easing.OutBack; easing.overshoot:1.7}}
 Behavior on color{ColorAnimation{duration:160}}
 Row{anchors.centerIn:parent;spacing:5
  SpaceIcon{width:b.textSize;height:b.textSize;visible:b.glyph||b.iconName!=='';ink:b.primary||b.selected?'#10271d':'#d8eee1';kind:b.iconName||({'󰒮':'previous','󰏤':'pause','󰐊':'play','󰓛':'stop','󰒭':'next'})[b.label]||'media'}
  Text{text:b.label;color:b.primary||b.selected?'#10271d':'#d8eee1';font.family:'Sansation';visible:!b.glyph&&b.label!=='';font.pixelSize:b.textSize}
 }
 ToolTip{visible:mouse.containsMouse&&b.tooltip!=='';delay:450;text:b.tooltip;popupType:Popup.Window;y:b.height+8
  contentItem:Text{text:b.tooltip;color:'#def9ec';font.family:'Sansation';font.pixelSize:12}
  background:Rectangle{color:'#ed0c251e';border.color:'#637baa91';radius:8}
 }
 MouseArea{id:mouse;anchors.fill:parent;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;onClicked:b.triggered()}
 activeFocusOnTab:true;Keys.onReturnPressed:triggered();Keys.onSpacePressed:triggered()
}
