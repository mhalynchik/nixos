import QtQuick
Item {
 id:orbit
 property var pages:['launcher','agenda','wallpapers','animated','settings']
 property var labels:['Поиск','Повестка','Обои','Живые обои','Настройки']
 property string currentPage:''
 property real birth:0
 property real death:0
 property bool opening:false
 property bool closing:false
 property bool opened:false
 property bool reducedMotion:false
 property real angle:0
 property real destinationAngle:0
 readonly property bool rotating:turn.running
 signal activated(string page)
 width:620;height:700
 function smooth(value){let t=Math.max(0,Math.min(1,value));return t*t*(3-2*t)}
 function selectPage(){
  let index=pages.indexOf(currentPage)
  if(index<0)return
  turn.stop()
  let target=-index*360/pages.length
  let delta=((target-angle+180)%360+360)%360-180
  destinationAngle=angle+delta
  if(reducedMotion){angle=destinationAngle;return}
  turn.from=angle;turn.to=destinationAngle;turn.restart()
 }
 onCurrentPageChanged:selectPage()
 onReducedMotionChanged:if(reducedMotion){turn.stop();angle=destinationAngle}
 Component.onCompleted:selectPage()
 NumberAnimation{id:turn;target:orbit;property:'angle';duration:420;easing.type:Easing.InOutCubic}
 Repeater{model:orbit.pages.length
  Item{
   id:button;required property int index
   objectName:'orbit-'+orbit.pages[index]
   property real form:orbit.opening?orbit.smooth((orbit.birth-.59-index*.035)/.3):orbit.closing?1-orbit.smooth((orbit.death-.11-index*.055)/.47):orbit.opened?1:0
   property real radians:(index*360/orbit.pages.length+orbit.angle+(orbit.closing?-330*(1-form):0))*Math.PI/180
   x:310+238*Math.pow(form,1.4)*Math.cos(radians)-42;y:355+238*Math.pow(form,1.4)*Math.sin(radians)-42;width:84;height:84
   activeFocusOnTab:enabled;Keys.onReturnPressed:orbit.activated(orbit.pages[index]);Keys.onSpacePressed:orbit.activated(orbit.pages[index])
   scale:form;opacity:form;rotation:orbit.closing?-120*(1-form):0;enabled:form>.95
   Rectangle{anchors.fill:parent;radius:42;color:orbit.pages[button.index]===orbit.currentPage?'#9c174d3b':'#800b2420';border.width:1;border.color:button.activeFocus?'#efffc9':orbit.pages[button.index]===orbit.currentPage?'#9becce':'#5077a98f'
    scale:hover.containsMouse?1.1:1;Behavior on scale{NumberAnimation{duration:orbit.reducedMotion?0:300;easing.type:Easing.OutBack}}
    SpaceIcon{anchors.horizontalCenter:parent.horizontalCenter;y:13;width:25;height:25;kind:orbit.pages[button.index];ink:orbit.pages[button.index]===orbit.currentPage?'#a2ffdb':'#c1dfd2'}
    UiText{anchors.horizontalCenter:parent.horizontalCenter;y:49;width:80;text:orbit.labels[button.index];font.pixelSize:11;color:'#a6c9bb';horizontalAlignment:Text.AlignHCenter}
    MouseArea{id:hover;anchors.fill:parent;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;onClicked:orbit.activated(orbit.pages[button.index])}
   }
  }
 }
}
