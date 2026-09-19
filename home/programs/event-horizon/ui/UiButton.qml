import QtQuick
import QtQuick.Controls
Button {
 id:b
 property bool selected:false
 implicitWidth:110;implicitHeight:36;padding:10
 font.family:'Sansation';font.pixelSize:13
 focusPolicy:Qt.StrongFocus
 contentItem:Text{text:b.text;font:b.font;color:b.enabled?(b.selected?'#09281d':'#dff9eb'):'#658578';horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter;elide:Text.ElideRight;textFormat:Text.PlainText}
 background:Rectangle{radius:14;color:b.selected?'#73ddb1':b.down?'#70588772':b.hovered?'#60365b4c':'#30234539';border.width:b.activeFocus?2:1;border.color:b.activeFocus?'#f3ffcf':'#5062957d'}
}
