import QtQuick
Canvas{
 id:icon
 property string kind:'media'
 property color ink:'#d8eee1'
 onKindChanged:requestPaint()
 onInkChanged:requestPaint()
 onPaint:{let c=getContext('2d');c.reset();c.save();c.scale(width/24,height/24);c.strokeStyle=ink;c.fillStyle=ink;c.lineWidth=1.6;c.lineCap='round';c.lineJoin='round';
 function path(p){c.beginPath();c.moveTo(p[0][0],p[0][1]);for(let i=1;i<p.length;i++)c.lineTo(p[i][0],p[i][1]);c.stroke()}
 function tri(x){c.beginPath();c.moveTo(x,5);c.lineTo(x+10,12);c.lineTo(x,19);c.closePath();c.fill()}
 if(kind==='play')tri(8);
 else if(kind==='pause'){c.fillRect(7,5,3,14);c.fillRect(14,5,3,14)}
 else if(kind==='stop'){c.fillRect(6,6,12,12)}
 else if(kind==='next'){tri(4);c.fillRect(17,5,2,14)}
 else if(kind==='previous'){c.translate(24,0);c.scale(-1,1);tri(4);c.fillRect(17,5,2,14)}
 else if(kind==='wifi'){for(let r of [5,10,15]){c.beginPath();c.arc(12,20,r,-Math.PI*.77,-Math.PI*.23);c.stroke()}c.beginPath();c.arc(12,20,1.5,0,Math.PI*2);c.fill()}
 else if(kind==='bluetooth'){path([[7,7],[17,16],[12,21],[12,3],[17,8],[7,17]])}
 else if(kind==='system'){c.strokeRect(6,6,12,12);c.strokeRect(10,10,4,4);for(let x of [9,15]){path([[x,3],[x,6]]);path([[x,18],[x,21]]);path([[3,x],[6,x]]);path([[18,x],[21,x]])}}
 else {c.beginPath();c.arc(12,12,8,0,Math.PI*2);c.stroke();c.beginPath();c.arc(12,12,2,0,Math.PI*2);c.fill();path([[16,5],[16,12]])}
 c.restore();}
}
