import QtQuick
Canvas {
 id:g
 property real phase:0
 property real warp:0
 property real pulse:bands.length?Math.min(1,bands.reduce((a,b)=>a+b,0)/bands.length*2.4):0
 Behavior on pulse{NumberAnimation{duration:100}}
 property real reveal:1
 property var bands:[]
 property real progress:0
 property bool playing:false
 property bool galaxy:false
 property bool mini:false
 property var processes:[]
 onPhaseChanged:requestPaint()
 onRevealChanged:requestPaint()
 onBandsChanged:requestPaint()
 onPaint:{
  let c=getContext('2d');c.reset();let cx=width/2,cy=height/2,u=width/440;
  function ring(r,alpha){c.strokeStyle='rgba(138,219,189,'+alpha+')';c.lineWidth=.8*u;c.beginPath();c.arc(0,0,r*u,0,Math.PI*2);c.stroke()}
  function star(x,y,size,a){c.globalAlpha=a;c.fillStyle='#d8fff1';c.beginPath();c.moveTo(x,y-size);c.lineTo(x+size*.22,y-size*.22);c.lineTo(x+size,y);c.lineTo(x+size*.22,y+size*.22);c.lineTo(x,y+size);c.lineTo(x-size*.22,y+size*.22);c.lineTo(x-size,y);c.lineTo(x-size*.22,y-size*.22);c.closePath();c.fill();c.globalAlpha=1}
  c.save();c.translate(cx,cy);c.scale(g.reveal,g.reveal);
  if(g.galaxy){
   for(let arm=0;arm<3;arm++)for(let i=0;i<80;i++){
    let t=i/80,r=15+175*t,a=t*7+arm*Math.PI*2/3+g.phase*.16;
    let x=Math.cos(a)*r*u,y=Math.sin(a)*r*u*.68;
    c.fillStyle=i%5===0?'#c8f7e2':'#63d7ad';c.globalAlpha=.25+.65*(1-t);c.beginPath();c.arc(x,y,(i%5===0?1.8:1)*u,0,Math.PI*2);c.fill();
   }c.globalAlpha=1;
   let halo=c.createRadialGradient(0,0,0,0,0,58*u);halo.addColorStop(0,'rgba(162,255,223,.6)');halo.addColorStop(1,'rgba(99,215,173,0)');c.fillStyle=halo;c.fillRect(-60*u,-60*u,120*u,120*u);
   ring(192,.22);c.restore();return;
  }
  if(!g.mini){
   ring(178,.18);ring(211,.13);
   c.save();c.rotate(-.30);c.scale(1,.43);ring(204,.22);c.restore();
   for(let i=0;i<32;i++){
    let a=i*2.399963,r=(154+(i*37)%62+g.warp*48)*u;
    if(g.warp>.01){c.strokeStyle="rgba(167,255,222,"+(g.warp*.75)+")";c.lineWidth=1*u;c.beginPath();c.moveTo(Math.cos(a)*r,Math.sin(a)*r);c.lineTo(Math.cos(a)*(r+g.warp*28*u),Math.sin(a)*(r+g.warp*28*u));c.stroke()}
    star(Math.cos(a)*r,Math.sin(a)*r,((i%6===0)?3.3:1.2)*u,.28+.23*Math.sin(g.phase*.75+i));
   }
   for(let i=0;i<3;i++){
    let a=g.phase*(.3+i*.13)+i*2.1,r=(178+i*15)*u;
    c.strokeStyle='rgba(115,216,183,.25)';c.lineWidth=1.2*u;c.beginPath();c.arc(0,0,r,a-.33,a);c.stroke();star(Math.cos(a)*r,Math.sin(a)*r,3*u,.85);
   }
  }
  // A smaller event horizon inside a wide, luminous, sound-reactive disk.
  let p=g.pulse;
  for(let k=9;k>0;k--){c.fillStyle='rgba(48,216,154,'+(.012+p*.004)+')';c.beginPath();c.arc(0,0,(48+k*9)*u,0,Math.PI*2);c.fill()}
  c.save();c.rotate(-.32);c.scale(1,.33);
  for(let j=0;j<14;j++){let r=(63+j*4.1+p*(3+j*.28))*u;c.strokeStyle='rgba(137,255,206,'+(.16+j*.017+p*.12)+')';c.lineWidth=(1.25+p*1.5)*u;c.beginPath();c.arc(0,0,r,0,Math.PI*2);c.stroke()}
  for(let i=0;i<85;i++){let a=i*2.399963+g.phase*(.7+(i%7)/12),r=(68+(i*19)%61+p*7)*u;c.fillStyle=i%5===0?'#ecfff6':'#72efbb';c.globalAlpha=.35+(i%6)/12+p*.1;c.beginPath();c.arc(Math.cos(a)*r,Math.sin(a)*r,(1.2+p*.9)*u,0,Math.PI*2);c.fill()}
  c.globalAlpha=1;c.restore();
  c.fillStyle='rgba(2,9,12,.95)';c.beginPath();c.arc(0,0,40*u,0,Math.PI*2);c.fill();
  c.strokeStyle='#c4ffe5';c.lineWidth=(1.3+p*2)*u;c.beginPath();c.arc(0,0,41*u,0,Math.PI*2);c.stroke();
  // Lensed upper arc and front half of the disk.
  c.strokeStyle='rgba(169,255,218,'+(.3+p*.4)+')';c.lineWidth=(2+p*2)*u;c.beginPath();c.arc(0,0,(47+p*2)*u,-Math.PI*.94,-.1);c.stroke();
  c.save();c.rotate(-.32);c.scale(1,.33);c.strokeStyle='rgba(192,255,226,'+(.6+p*.35)+')';c.lineWidth=(2.3+p*2)*u;c.beginPath();c.arc(0,0,(88+p*6)*u,0,Math.PI);c.stroke();c.restore();
  if(!g.mini){
   for(let i=0;i<48;i++){
    let a=i*Math.PI*2/48-Math.PI/2,v=g.bands[i]||0,r=129*u,len=(2+v*28)*u;
    c.save();c.rotate(a);c.fillStyle=i%6===0?'#d7fff0':'#63d7ad';c.globalAlpha=.35+.65*v;c.fillRect(r,-1*u,len,2*u);c.restore();
   }c.globalAlpha=1;
   c.strokeStyle='rgba(198,255,229,.64)';c.lineWidth=1.4*u;c.beginPath();c.arc(0,0,168*u,-Math.PI/2,-Math.PI/2+Math.PI*2*g.progress);c.stroke();
  }
  c.restore();
 }
}
