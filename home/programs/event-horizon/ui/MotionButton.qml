import QtQuick
Rectangle {
 id:b
 property string label:""
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
 Text{anchors.centerIn:parent;text:b.label;color:b.primary||b.selected?'#10271d':'#d8eee1';font.family:'Sansation';visible:!b.glyph;font.pixelSize:b.textSize}
 SpaceIcon{anchors.centerIn:parent;width:b.textSize;height:b.textSize;visible:b.glyph;ink:b.primary||b.selected?'#10271d':'#d8eee1';kind:({'󰒮':'previous','󰏤':'pause','󰐊':'play','󰓛':'stop','󰒭':'next'})[b.label]||'media'}
 MouseArea{id:mouse;anchors.fill:parent;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;onClicked:b.triggered()}
 activeFocusOnTab:true;Keys.onReturnPressed:triggered();Keys.onSpacePressed:triggered()
}
