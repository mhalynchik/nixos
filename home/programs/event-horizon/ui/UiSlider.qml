import QtQuick
import QtQuick.Controls
Slider{
 id:c
 implicitHeight:36
 background:Rectangle{x:c.leftPadding;y:c.topPadding+c.availableHeight/2-height/2;width:c.availableWidth;height:3;radius:2;color:'#426957'
  Rectangle{width:c.visualPosition*parent.width;height:parent.height;radius:2;color:'#87e6b5'}
 }
 handle:Rectangle{x:c.leftPadding+c.visualPosition*(c.availableWidth-width);y:c.topPadding+c.availableHeight/2-height/2;implicitWidth:14;implicitHeight:14;rotation:45;radius:3;color:c.pressed?'#dcffe9':'#84e4b7';border.width:c.activeFocus?2:0;border.color:'#f3ffcd'}
}
