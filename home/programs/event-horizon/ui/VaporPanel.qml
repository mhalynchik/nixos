import QtQuick
Image{
 property real birth:0
 property real death:0
 property bool opening:false
 property bool closing:false
 property bool opened:false
 source:'mist/'+(closing?'close':'open')+Math.min(47,Math.floor((closing?death:opening?birth:opened?1:0)*47)).toString().padStart(2,'0')+'.png'
 cache:true;smooth:true
}
