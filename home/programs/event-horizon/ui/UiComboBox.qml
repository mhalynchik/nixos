import QtQuick
import QtQuick.Controls
ComboBox{
 id:c;implicitHeight:36;font.family:'Sansation';font.pixelSize:14
 contentItem:UiText{leftPadding:12;rightPadding:28;text:c.displayText;verticalAlignment:Text.AlignVCenter;elide:Text.ElideRight}
 background:Rectangle{radius:12;color:'#62204032';border.width:c.activeFocus?2:1;border.color:c.activeFocus?'#e9ffd0':'#4c78ad91'}
 indicator:UiText{x:c.width-24;anchors.verticalCenter:parent.verticalCenter;text:'⌄';color:'#9cecc1'}
 delegate:ItemDelegate{width:c.width;contentItem:UiText{text:c.textRole?modelData[c.textRole]:modelData;elide:Text.ElideRight}background:Rectangle{radius:8;color:parent.highlighted?'#aa32634c':'transparent'}highlighted:c.highlightedIndex===index}
 popup:Popup{y:c.height+6;width:c.width;implicitHeight:Math.min(280,contentItem.implicitHeight+12);padding:6;background:Rectangle{radius:14;color:'#ee102a21';border.width:1;border.color:'#658fb497'}contentItem:ListView{clip:true;implicitHeight:contentHeight;model:c.popup.visible?c.delegateModel:null;currentIndex:c.highlightedIndex;ScrollBar.vertical:ScrollBar{}}}
}
