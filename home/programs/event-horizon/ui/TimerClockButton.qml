import QtQuick

MotionButton {
 id:clock
 property date now:new Date()
 property var timer:({status:'idle',duration:0,remaining:0})
 readonly property real outlineProgress:{
  if(!timer||(timer.status!=='running'&&timer.status!=='paused'))return -1
  let duration=Number(timer.duration),remaining=Number(timer.remaining)
  if(!isFinite(duration)||duration<=0||!isFinite(remaining))return -1
  return Math.max(0,Math.min(1,remaining/duration))
 }
 width:62;height:28;textSize:15;label:Qt.formatTime(now,'HH:mm')
 onOutlineProgressChanged:outline.requestPaint()
 onRadiusChanged:outline.requestPaint()
 onAccentChanged:outline.requestPaint()
 onSelectedChanged:outline.requestPaint()
 Canvas {
  id:outline
  anchors.fill:parent
  onWidthChanged:requestPaint()
  onHeightChanged:requestPaint()
  onVisibleChanged:requestPaint()
  Component.onCompleted:requestPaint()
  onPaint:{
   let c=getContext('2d');c.reset()
   if(clock.outlineProgress<=0||width<=4||height<=4)return
   let inset=1.5,left=inset,right=width-inset,top=inset,bottom=height-inset
   let radius=Math.max(0,Math.min(clock.radius-inset,(right-left)/2,(bottom-top)/2))
   let horizontal=right-left-2*radius,vertical=bottom-top-2*radius
   let remaining=(2*horizontal+2*vertical+2*Math.PI*radius)*clock.outlineProgress
   let x=width/2,y=top
   c.strokeStyle=clock.selected?'#efffca':clock.accent;c.lineWidth=2;c.lineCap='round'
   c.beginPath();c.moveTo(x,y)
   // Spend the remaining perimeter length clockwise from the top centre.
   function line(toX,toY){
    let length=Math.hypot(toX-x,toY-y),fraction=length?Math.min(1,remaining/length):0
    if(remaining>0&&length>0)c.lineTo(x+(toX-x)*fraction,y+(toY-y)*fraction)
    remaining=Math.max(0,remaining-length);x=toX;y=toY
   }
   function corner(cx,cy,start){
    let sweep=radius?Math.min(Math.PI/2,remaining/radius):0
    if(sweep>0)c.arc(cx,cy,radius,start,start+sweep)
    remaining=Math.max(0,remaining-radius*Math.PI/2)
    x=cx+radius*Math.cos(start+Math.PI/2);y=cy+radius*Math.sin(start+Math.PI/2)
   }
   line(right-radius,top);corner(right-radius,top+radius,-Math.PI/2)
   line(right,bottom-radius);corner(right-radius,bottom-radius,0)
   line(left+radius,bottom);corner(left+radius,bottom-radius,Math.PI/2)
   line(left,top+radius);corner(left+radius,top+radius,Math.PI)
   line(width/2,top);c.stroke()
  }
 }
}
