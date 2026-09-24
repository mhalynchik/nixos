import QtQuick
Item {
 id:p
 property string kind:'volume'
 property string title:''
 property real value:0
 property bool muted:false
 property bool reducedMotion:false
 property real shownValue:value
 Behavior on shownValue{NumberAnimation{duration:p.reducedMotion?0:180;easing.type:Easing.OutCubic}}
 width:300;height:110
 Rectangle{anchors.fill:parent;color:'#db0a211c';radius:28;border.color:'#727bd7b1';border.width:1}
 Canvas{x:10;y:8;width:94;height:94;property real progress:p.shownValue;onProgressChanged:requestPaint();property bool muted:p.muted;onMutedChanged:requestPaint();onPaint:{let c=getContext('2d');c.reset();c.lineWidth=2;c.strokeStyle='#35594b';c.beginPath();c.arc(47,47,36,0,Math.PI*2);c.stroke();c.strokeStyle=p.muted?'#f2bb99':'#86f2bd';c.lineWidth=3;c.beginPath();c.arc(47,47,36,-Math.PI/2,-Math.PI/2+Math.PI*2*Math.max(0,Math.min(1,p.shownValue/100)));c.stroke();let a=-Math.PI/2+Math.PI*2*Math.max(0,Math.min(1,p.shownValue/100));c.fillStyle=c.strokeStyle;c.beginPath();c.arc(47+36*Math.cos(a),47+36*Math.sin(a),4,0,Math.PI*2);c.fill()}}
 SpaceIcon{x:42;y:39;width:30;height:30;kind:p.kind;ink:p.muted?'#f2bb99':'#b1f8d5'}
 UiText{x:116;y:24;width:174;text:p.title;font.pixelSize:15;elide:Text.ElideRight}
 UiText{x:116;y:52;width:174;text:p.muted?'—':Math.round(p.value)+'%';font.pixelSize:27;color:p.muted?'#e6b498':'#8eebbd'}
}
