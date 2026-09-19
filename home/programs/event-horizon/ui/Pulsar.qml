import QtQuick
Canvas {
 id:p
 property real phase:0
 property real surge:0
 onPhaseChanged:requestPaint()
 onSurgeChanged:requestPaint()
 onPaint:{let c=getContext('2d');c.reset();let cx=width/2,cy=height/2,u=width/220,a=phase*.7;
  c.save();c.translate(cx,cy);c.scale(u,u);
  c.strokeStyle='rgba(121,214,189,.18)';c.lineWidth=.7;c.beginPath();c.arc(0,0,83,0,Math.PI*2);c.stroke();
  c.save();c.rotate(a);
  for(let side of [1,-1])for(let j=4;j>0;j--){c.fillStyle='rgba(134,239,222,'+(.035+(4-j)*.015)+')';c.beginPath();c.moveTo(0,0);c.lineTo(side*(82+surge*14),-j*5);c.quadraticCurveTo(side*108,0,side*(82+surge*14),j*5);c.closePath();c.fill()}
  c.strokeStyle='rgba(207,255,246,.75)';c.lineWidth=1;c.beginPath();c.moveTo(-90,0);c.lineTo(90,0);c.stroke();c.restore();
  for(let i=0;i<3;i++){let t=(phase*.32+i/3)%1,r=18+t*57;c.strokeStyle='rgba(150,246,223,'+((1-t)*.18)+')';c.beginPath();c.arc(0,0,r,0,Math.PI*2);c.stroke()}
  for(let k=9;k>0;k--){c.fillStyle='rgba(152,255,229,.025)';c.beginPath();c.arc(0,0,k*3,0,Math.PI*2);c.fill()}
  c.fillStyle='#d9fff3';c.beginPath();c.arc(0,0,6+1.2*Math.pow(Math.abs(Math.cos(a)),8)+surge*2,0,Math.PI*2);c.fill();
  c.strokeStyle='#72edbc';c.lineWidth=1.5;c.beginPath();c.arc(0,0,11,0,Math.PI*2);c.stroke();c.restore();
 }
}
