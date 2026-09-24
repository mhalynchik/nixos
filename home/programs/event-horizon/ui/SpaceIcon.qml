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
 else if(kind==='launcher'){c.beginPath();c.arc(10,10,6,0,Math.PI*2);c.stroke();path([[14.5,14.5],[21,21]])}
 else if(kind==='agenda'){c.strokeRect(3,5,18,16);path([[3,10],[21,10]]);path([[7,3],[7,7]]);path([[17,3],[17,7]]);for(let x of [7,12,17])for(let y of [14,18]){c.beginPath();c.arc(x,y,.7,0,Math.PI*2);c.fill()}}
 else if(kind==='wallpapers'){c.strokeRect(2,3,20,18);path([[3,18],[8,12],[12,16],[17,10],[21,15]]);c.beginPath();c.arc(8,8,1.5,0,Math.PI*2);c.stroke()}
 else if(kind==='animated'){c.strokeRect(2,4,20,16);c.beginPath();c.moveTo(9,8);c.lineTo(16,12);c.lineTo(9,16);c.closePath();c.fill()}
 else if(kind==='wifi'){for(let r of [5,10,15]){c.beginPath();c.arc(12,20,r,-Math.PI*.77,-Math.PI*.23);c.stroke()}c.beginPath();c.arc(12,20,1.5,0,Math.PI*2);c.fill()}
 else if(kind==='bluetooth'){path([[7,7],[17,16],[12,21],[12,3],[17,8],[7,17]])}
 else if(kind==='volume'){path([[4,9],[8,9],[13,5],[13,19],[8,15],[4,15],[4,9]]);for(let r of [5,8]){c.beginPath();c.arc(13,12,r,-.8,.8);c.stroke()}}
 else if(kind==='microphone'||kind==='mic-muted'){c.beginPath();c.arc(12,6,3,Math.PI,0);c.lineTo(15,12);c.arc(12,12,3,0,Math.PI);c.closePath();c.stroke();c.beginPath();c.arc(12,12,6,0,Math.PI);c.stroke();path([[12,18],[12,22]]);path([[8,22],[16,22]]);if(kind==='mic-muted'){c.globalCompositeOperation='destination-out';c.lineWidth=5;path([[3,3],[21,21]]);c.globalCompositeOperation='source-over';c.lineWidth=2.2;path([[3,3],[21,21]])}}
 else if(kind==='notifications'){path([[5,17],[7,14],[7,9]]);c.beginPath();c.arc(12,9,5,Math.PI,Math.PI*2);c.stroke();path([[17,9],[17,14],[19,17],[5,17]]);c.beginPath();c.arc(12,19,2,0,Math.PI);c.stroke()}
 else if(kind==='overview'){for(let x of [3,14])for(let y of [3,14])c.strokeRect(x,y,7,7)}
 else if(kind==='timer'){c.beginPath();c.arc(12,14,8,0,Math.PI*2);c.stroke();path([[9,2],[15,2]]);path([[12,2],[12,6]]);path([[12,9],[12,14],[16,16]])}
 else if(kind==='power'){c.beginPath();c.arc(12,13,8,-Math.PI*.3,Math.PI*1.3);c.stroke();path([[12,2],[12,12]])}
 else if(kind==='settings'){for(let i=0;i<8;i++){let a=i*Math.PI/4;path([[12+7*Math.cos(a),12+7*Math.sin(a)],[12+10*Math.cos(a),12+10*Math.sin(a)]])}c.beginPath();c.arc(12,12,7,0,Math.PI*2);c.stroke();c.beginPath();c.arc(12,12,2.5,0,Math.PI*2);c.stroke()}
 else if(kind==='brightness'){c.beginPath();c.arc(12,12,4,0,Math.PI*2);c.stroke();for(let i=0;i<8;i++){let a=i*Math.PI/4;path([[12+7*Math.cos(a),12+7*Math.sin(a)],[12+10*Math.cos(a),12+10*Math.sin(a)]])}}
 else if(kind==='record'){c.beginPath();c.arc(12,12,7,0,Math.PI*2);c.fill()}
 else if(kind==='close'){path([[6,6],[18,18]]);path([[18,6],[6,18]])}
 else if(kind==='tools'){path([[3,8],[21,8],[21,20],[3,20],[3,8]]);path([[8,8],[8,4],[16,4],[16,8]]);path([[3,13],[21,13]]);path([[12,11],[12,15]])}
 else if(kind==='system'){c.strokeRect(6,6,12,12);c.strokeRect(10,10,4,4);for(let x of [9,15]){path([[x,3],[x,6]]);path([[x,18],[x,21]]);path([[3,x],[6,x]]);path([[18,x],[21,x]])}}
 else {c.beginPath();c.arc(12,12,8,0,Math.PI*2);c.stroke();c.beginPath();c.arc(12,12,2,0,Math.PI*2);c.fill();path([[16,5],[16,12]])}
 c.restore();}
}
