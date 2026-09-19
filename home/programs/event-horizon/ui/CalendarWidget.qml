import QtQuick
Item {
 id:cal
 signal dateActivated(string date)
 signal timerActivated()
 property var timer:({status:'idle',duration:1500,remaining:1500})
 property var agenda:[]
 property bool reducedMotion:false
 property real surge:0
 function activateDate(day){selectedDay=day;dateActivated(year+'-'+(month+1).toString().padStart(2,'0')+'-'+day.toString().padStart(2,'0'))}
 property date today:new Date()
 property real phase:0
 property int month:today.getMonth()
 property int year:today.getFullYear()
 property int selectedDay:today.getDate()
 property int offset:(new Date(year,month,1).getDay()+6)%7
 property int days:new Date(year,month+1,0).getDate()
 property real travel:1
 property color accent:'#72e7bc'
 width:572;height:410
 function shift(d){let n=new Date(year,month+d,1);year=n.getFullYear();month=n.getMonth();selectedDay=Math.min(selectedDay,days);journey.restart()}
 function choose(m){month=m;selectedDay=Math.min(selectedDay,days);journey.restart()}
 function reset(){year=today.getFullYear();month=today.getMonth();selectedDay=today.getDate();journey.restart()}
 function monthPoint(n){let a=n*Math.PI/6-Math.PI/2;return {x:x+110+100*Math.cos(a),y:y+175+100*Math.sin(a)}}
 NumberAnimation{id:journey;target:cal;property:'travel';from:0;to:1;duration:cal.reducedMotion?1:1100;easing.type:Easing.OutCubic}
 Text{x:0;y:7;text:cal.year;font.family:'ForestSmooth';font.pixelSize:30;color:'#ddf9ec'}
 Text{x:0;y:46;text:'ВЫБРАТЬ МЕСЯЦ';font.family:'Sansation';font.pixelSize:9;font.letterSpacing:1.5;color:'#9dcbba'}
 Pulsar{x:0;y:65;width:220;height:220;phase:cal.phase;surge:Math.max(cal.surge,1-cal.travel)}
 Canvas{x:14;y:79;width:192;height:192;visible:cal.timer.status!=='idle';property real fraction:cal.timer.remaining/Math.max(1,cal.timer.duration);onFractionChanged:requestPaint();onVisibleChanged:requestPaint();onPaint:{let c=getContext("2d");c.reset();c.strokeStyle="#a7f3c8";c.lineWidth=2;c.beginPath();c.arc(96,96,83,-Math.PI/2,-Math.PI/2+fraction*Math.PI*2);c.stroke()}}
 UiButton{x:80;y:155;width:60;height:40;text:cal.timer.status==='running'||cal.timer.status==='paused'?Math.ceil(cal.timer.remaining/60)+'m':'◉';onClicked:cal.timerActivated()}
 Repeater{model:12
  Item{required property int index;activeFocusOnTab:true;Keys.onReturnPressed:cal.choose(index);Keys.onSpacePressed:cal.choose(index);property real angle:index*Math.PI/6-Math.PI/2;property bool active:index===cal.month
   x:110+100*Math.cos(angle)-17;y:175+100*Math.sin(angle)-17;width:34;height:34
   Rectangle{anchors.fill:parent;radius:17;color:'transparent';border.width:parent.active||parent.activeFocus?1:0;border.color:parent.activeFocus?'#efffc9':'#83dfbe'}
   Text{anchors.centerIn:parent;text:(index+1).toString().padStart(2,'0');font.family:'Sansation';font.pixelSize:parent.active?13:11;font.bold:parent.active;color:parent.active?'#d8fff0':'#a1c8b8'}
   MouseArea{anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:{parent.forceActiveFocus();cal.choose(index)}}
  }
 }
 Text{x:22;y:305;width:178;text:['январь','февраль','март','апрель','май','июнь','июль','август','сентябрь','октябрь','ноябрь','декабрь'][cal.month];font.family:'Sansation';font.pixelSize:16;color:'#d8f8e8';horizontalAlignment:Text.AlignHCenter}
 Text{x:235;y:9;text:['январь','февраль','март','апрель','май','июнь','июль','август','сентябрь','октябрь','ноябрь','декабрь'][cal.month];font.family:'ForestSmooth';font.pixelSize:24;color:'#e5fff2'}
 Repeater{model:['‹','›']
  Text{required property string modelData;required property int index;x:487+index*36;y:1;width:30;height:35;text:modelData;font.family:'Sansation';font.pixelSize:28;color:mouse.containsMouse?'white':cal.accent;horizontalAlignment:Text.AlignHCenter
   MouseArea{id:mouse;anchors.fill:parent;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;onClicked:cal.shift(index===0?-1:1)}
  }
 }
 Item{x:235;y:61;width:322;height:245
  Grid{width:322;columns:7;rowSpacing:9
   Repeater{model:7
    Text{required property int index;width:46;height:21;text:['ПН','ВТ','СР','ЧТ','ПТ','СБ','ВС'][index];horizontalAlignment:Text.AlignHCenter;color:index>4?cal.accent:'#a9c5b9';font.family:'Sansation';font.pixelSize:11}
   }
   Repeater{model:42
    Item{required property int index;property int day:index-cal.offset+1;property bool valid:day>0&&day<=cal.days;property bool selected:valid&&day===cal.selectedDay;property bool current:valid&&day===cal.today.getDate()&&cal.month===cal.today.getMonth()&&cal.year===cal.today.getFullYear()
     property real enter:Math.max(0,Math.min(1,cal.travel*1.9-(index%7)*.1-Math.floor(index/7)*.06))
     width:46;height:27;opacity:enter;activeFocusOnTab:valid;Keys.onReturnPressed:cal.activateDate(day);Keys.onSpacePressed:cal.activateDate(day)
     Rectangle{x:21;y:25;width:4;height:4;radius:2;color:cal.accent;visible:parent.valid&&cal.agenda.some(e=>e.date===cal.year+'-'+(cal.month+1).toString().padStart(2,'0')+'-'+parent.day.toString().padStart(2,'0')&&!e.done)}
     Rectangle{anchors.fill:parent;radius:6;color:'transparent';border.width:parent.activeFocus?1:0;border.color:'#edffc9'}
     Text{y:(1-parent.enter)*8;x:(1-parent.enter)*18;anchors.horizontalCenter:parent.horizontalCenter;text:parent.valid?parent.day:'';font.family:'Sansation';font.pixelSize:19;font.weight:parent.current?Font.DemiBold:Font.Normal;color:parent.current||hover.containsMouse?cal.accent:'#e2f3ea'}
     Canvas{anchors.centerIn:parent;width:43;height:39;visible:parent.selected
      property real tick:cal.phase
      onTickChanged:if(visible)requestPaint()
      onVisibleChanged:requestPaint()
      onPaint:{let c=getContext('2d');c.reset();c.save();c.translate(width/2,height/2);c.rotate(-.4);c.strokeStyle='rgba(120,235,188,.45)';c.lineWidth=.75;c.save();c.scale(1,.75);c.beginPath();c.arc(0,0,20,0,Math.PI*2);c.stroke();c.restore();let a=cal.phase*.65;c.fillStyle='#abffe0';c.beginPath();c.arc(Math.cos(a)*20,Math.sin(a)*15,2,0,Math.PI*2);c.fill();c.restore()}
     }
     MouseArea{id:hover;anchors.fill:parent;enabled:parent.valid;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;onClicked:cal.activateDate(parent.day)}
    }
   }
  }
  Canvas{anchors.fill:parent;visible:cal.travel<1
   property real t:cal.travel
   onTChanged:requestPaint()
   onPaint:{let c=getContext('2d');c.reset();let x=width*t;c.strokeStyle='rgba(154,250,219,'+Math.sin(t*Math.PI)*.45+')';c.lineWidth=1;c.beginPath();c.moveTo(x,18);c.quadraticCurveTo(x-35,125,x,235);c.stroke();for(let i=0;i<18;i++){let y=(i*43)%235,dx=(i%5)*4;c.fillStyle='rgba(179,255,227,'+Math.sin(t*Math.PI)*.6+')';c.beginPath();c.arc(x-dx,y,i%4===0?2:1,0,Math.PI*2);c.fill()}}
  }
 }
 Text{x:235;y:325;text:'Сегодня · '+cal.today.toLocaleDateString(Qt.locale('ru_RU'),'d MMMM');font.family:'Sansation';font.pixelSize:12;color:'#adcbbd';MouseArea{anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:cal.reset()}}
}
