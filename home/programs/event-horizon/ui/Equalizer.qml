import QtQuick
Item {
 id:e
 property var gains:[0,0,0,0,0]
 property real g0:gains[0]||0
 property real g1:gains[1]||0
 property real g2:gains[2]||0
 property real g3:gains[3]||0
 property real g4:gains[4]||0
 property var smoothed:[g0,g1,g2,g3,g4]
 Behavior on g0{NumberAnimation{duration:260;easing.type:Easing.OutCubic}}
 Behavior on g1{NumberAnimation{duration:260;easing.type:Easing.OutCubic}}
 Behavior on g2{NumberAnimation{duration:260;easing.type:Easing.OutCubic}}
 Behavior on g3{NumberAnimation{duration:260;easing.type:Easing.OutCubic}}
 Behavior on g4{NumberAnimation{duration:260;easing.type:Easing.OutCubic}}
 onSmoothedChanged:curve.requestPaint()
 property string family:"Sansation"
 property var bands:[]
 signal changed(int band,real value)
 signal preset(string name)
 Text{text:'Equalizer';font.family:e.family;font.pixelSize:26;color:'#dceddf'}
 Row{anchors.right:parent.right;y:0;spacing:6
  Repeater{model:['flat','warm','air'];MotionButton{required property string modelData;width:55;height:30;label:modelData;textSize:11;onTriggered:e.preset(modelData)}}
 }
 Item{id:graph;x:10;y:53;width:parent.width-20;height:parent.height-82
  Canvas{id:curve;anchors.fill:parent
   onPaint:{let c=getContext('2d');c.reset();let xs=[],ys=[];for(let i=0;i<5;i++){xs.push(width*(i+.5)/5);ys.push(height/2-(e.smoothed[i]||0)*height/24)}
    c.strokeStyle='rgba(135,182,155,0.13)';c.lineWidth=1;for(let j=0;j<3;j++){c.beginPath();c.moveTo(0,height*j/2);c.lineTo(width,height*j/2);c.stroke()}
    c.beginPath();c.moveTo(0,ys[0]);for(let i=0;i<5;i++){let x2=i<4?(xs[i]+xs[i+1])/2:width,y2=i<4?(ys[i]+ys[i+1])/2:ys[i];c.quadraticCurveTo(xs[i],ys[i],x2,y2)}c.strokeStyle='#63d7ad';c.lineWidth=2;c.stroke();c.lineTo(width,height);c.lineTo(0,height);c.closePath();let g=c.createLinearGradient(0,0,0,height);g.addColorStop(0,'rgba(99,215,173,0.28)');g.addColorStop(1,'rgba(99,215,173,0)');c.fillStyle=g;c.fill();
   }
  }
  Repeater{model:5
   Item{required property int index;x:graph.width*(index+.5)/5-16;width:32;height:graph.height
    Rectangle{x:15;y:0;width:1;height:parent.height;color:'#2080ab94'}
    Rectangle{id:knob;x:9;y:parent.height/2-(e.smoothed[index]||0)*parent.height/24-7;width:14;height:14;radius:2;rotation:45;color:drag.containsMouse?'#e3ffe9':'#63d7ad';scale:drag.pressed?1.3:1;Behavior on y{NumberAnimation{duration:140;easing.type:Easing.OutCubic}}}
    Text{anchors.horizontalCenter:parent.horizontalCenter;y:graph.height+10;text:['60','230','910','3.6k','14k'][index];font.family:'Sansation';font.pixelSize:11;color:'#a0c4b2'}
    MouseArea{id:drag;anchors.fill:parent;hoverEnabled:true;cursorShape:Qt.SizeVerCursor;onPressed:m=>e.changed(index,Math.round(Math.max(-10,Math.min(10,(.5-m.y/height)*24))));onPositionChanged:m=>{if(pressed)e.changed(index,Math.round(Math.max(-10,Math.min(10,(.5-m.y/height)*24))))}}
   }
  }
 }
 onGainsChanged:curve.requestPaint()
}
