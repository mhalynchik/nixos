import QtQuick
Canvas {
 id:fx
 property real birth:0
 property real death:0
 property bool opening:false
 property bool closing:false
 property real phase:0
 property real orbitAngle:0
 onBirthChanged:requestPaint()
 onDeathChanged:requestPaint()
 onOpeningChanged:requestPaint()
 onClosingChanged:requestPaint()
 function clamp(v){return Math.max(0,Math.min(1,v))}
 onPaint:{
  let c=getContext('2d');c.reset();if(!opening&&!closing)return;c.translate(150,60);
  let cx=310,cy=355;
  function glow(x,y,r,a){if(a<=0||r<1)return;for(let k=18;k>0;k--){c.fillStyle='rgba(142,255,213,'+(a*.035*(1-k/20))+')';c.beginPath();c.arc(x,y,r*k/18,0,Math.PI*2);c.fill()} }
  function dot(x,y,r,a){c.fillStyle='rgba(196,255,227,'+a+')';c.beginPath();c.arc(x,y,r,0,Math.PI*2);c.fill()}
  if(opening){
   let blast=clamp((birth-.035)/.115),out=1-Math.pow(1-blast,4),flare=Math.sin(clamp(birth/.24)*Math.PI);
   glow(cx,cy,28+260*out,flare*.65);
   if(birth<.23){let hot=Math.sin(clamp(birth/.23)*Math.PI);for(let i=0;i<40;i++){let a=i*2.399963,r=(90+(i%7)*17)*hot;c.strokeStyle='rgba(222,255,240,'+(hot*(.3+(i%4)*.1))+')';c.lineWidth=i%5===0?3:1;c.beginPath();c.moveTo(cx+Math.cos(a)*20*hot,cy+Math.sin(a)*20*hot);c.lineTo(cx+Math.cos(a)*r,cy+Math.sin(a)*r);c.stroke()}dot(cx,cy,3+29*hot,hot*.92)}
   if(birth<.19){let a=Math.sin(clamp(birth/.19)*Math.PI);c.strokeStyle='rgba(235,255,246,'+a+')';c.lineWidth=1.5+2*a;c.beginPath();c.moveTo(cx-245*a,cy);c.lineTo(cx+245*a,cy);c.moveTo(cx,cy-210*a);c.lineTo(cx,cy+210*a);c.stroke();dot(cx,cy,4+18*a,a)}
   if(birth>.035&&birth<.3){let fade=1-clamp((birth-.11)/.19);for(let j=0;j<3;j++){let r=24+out*(335-j*17);c.strokeStyle='rgba(166,255,216,'+(fade*(.65-j*.15))+')';c.lineWidth=j===0?2:1;c.beginPath();c.arc(cx,cy,r,0,Math.PI*2);c.stroke()}}
   // The same ejecta reverse direction and spiral into the new accretion disk.
   if(birth>.035&&birth<.56){
    let pull=clamp((birth-.17)/.36),fall=pull*pull,alpha=(1-clamp((pull-.8)/.2));
    for(let i=0;i<145;i++){
     let seed=i*2.399963,a=seed-fall*(2.2+(i%7)*.09),r=(25+out*(245+(i%13)*6))*(1-fall)+63*fall;
     let length=(1-pull)*(9+out*22)+pull*12;
     c.strokeStyle='rgba(180,255,219,'+(.18+(i%5)*.1)*alpha+')';c.lineWidth=i%7===0?2:1;c.beginPath();c.moveTo(cx+Math.cos(a)*r,cy+Math.sin(a)*r);c.lineTo(cx+Math.cos(a+.025*pull)*(r+length),cy+Math.sin(a+.025*pull)*(r+length));c.stroke();
     if(i%15===0)glow(cx+Math.cos(a)*r,cy+Math.sin(a)*r,18+12*(1-pull),alpha*.6);
    }
   }
   // Gas left in stable orbits condenses slowly into the navigation controls.
   for(let n=0;n<4;n++){
    let t=clamp((birth-.45-n*.035)/.48),end=(n*90+orbitAngle)*Math.PI/180;
    if(t<=0||t>=1)continue;let ease=t*t*(3-2*t),spread=(1-ease)*70+5;
    for(let i=0;i<38;i++){let a=end-(1-ease)*.6,j=i*2.399963,r=210+28*ease+Math.cos(j)*spread,x=cx+Math.cos(a)*r+Math.sin(j*2)*spread*.5,y=cy+Math.sin(a)*r+Math.cos(j*2)*spread*.5;
     dot(x,y,1+(i%3)*.5,Math.sin(t*Math.PI)*.65);if(i%10===0)glow(x,y,25,Math.sin(t*Math.PI)*.6)}
   }
  }
  if(closing){
   for(let i=0;i<130;i++){
    let start=i%2===0?{x:610+(i*47)%410,y:125+(i*31)%615}:{x:cx+Math.cos(i*2.4)*238,y:cy+Math.sin(i*2.4)*238};
    let t=clamp((death-(i%11)*.018)/.58),dx=start.x-cx,dy=start.y-cy,a=Math.atan2(dy,dx)-t*t*3.6,r=Math.sqrt(dx*dx+dy*dy)*Math.pow(1-t,1.7);
    if(t<=0||t>=1)continue;c.strokeStyle='rgba(136,235,192,'+(Math.sin(t*Math.PI)*.7)+')';c.lineWidth=i%9===0?2:1;c.beginPath();c.moveTo(cx+Math.cos(a)*r,cy+Math.sin(a)*r);c.lineTo(cx+Math.cos(a+.045)*(r+8+14*t),cy+Math.sin(a+.045)*(r+8+14*t));c.stroke();
   }
   let core=clamp((death-.75)/.25);if(core>0)glow(cx,cy,55*(1-core)+3,Math.sin(core*Math.PI));
  }
 }
}
