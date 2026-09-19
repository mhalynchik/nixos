import QtQuick
import QtQuick.Controls
TextField {
 id:f
 implicitHeight:42;leftPadding:12;rightPadding:12;
 font.family:'Sansation';font.pixelSize:16;color:'#e7fff2';placeholderTextColor:'#91b1a4';selectionColor:'#357a60';selectedTextColor:'#ffffff';selectByMouse:true
 background:Rectangle{radius:12;color:'#60091f1b';border.width:f.activeFocus?2:1;border.color:f.activeFocus?'#b1ffe0':'#477da88f'}
}
