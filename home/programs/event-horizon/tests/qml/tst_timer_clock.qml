import QtQuick
import QtTest
import "../../ui" as Shell

Item {
 width:220;height:100
 Shell.TimerClockButton{id:clock;x:40;y:30}
 SignalSpy{id:activation;target:clock;signalName:'triggered'}
 TestCase {
  name:'TimerClockButton';when:windowShown
  function init(){
   clock.timer={status:'idle',duration:0,remaining:0}
   clock.now=new Date(2026,8,20,13,45);clock.selected=false;clock.width=62;clock.visible=true
   clock.focus=false;activation.clear();mouseMove(parent,200,90)
   wait(300)
  }
  function snapshot(){waitForRendering(clock,100);wait(40);return grabImage(clock)}
  function hasPixelChange(first,second,start,end){
   for(let x=start;x<end;x++)for(let y=0;y<first.height;y++)
    if(first.pixel(x,y)!==second.pixel(x,y))return true
   return false
  }
  function test_clock_and_activation(){
   compare(clock.label,'13:45')
   clock.now=new Date(2026,8,20,13,46);compare(clock.label,'13:46')
   mouseClick(clock,31,14);compare(activation.count,1)
   clock.forceActiveFocus();keyClick(Qt.Key_Return);keyClick(Qt.Key_Space)
   compare(activation.count,3)
  }
  function test_timer_lifecycle(){
   compare(clock.outlineProgress,-1)
   clock.timer={status:'running',duration:120,remaining:120};compare(clock.outlineProgress,1)
   clock.timer={status:'running',duration:120,remaining:90};compare(clock.outlineProgress,.75)
   clock.timer={status:'paused',duration:120,remaining:90};wait(80);compare(clock.outlineProgress,.75)
   clock.timer={status:'running',duration:120,remaining:60};compare(clock.outlineProgress,.5)
   clock.timer={status:'running',duration:120,remaining:0};compare(clock.outlineProgress,0)
   clock.timer={status:'finished',duration:120,remaining:0};compare(clock.outlineProgress,-1)
   clock.timer={status:'idle',duration:120,remaining:120};compare(clock.outlineProgress,-1)
  }
  function test_invalid_and_clamped_values(){
   clock.timer={status:'running',duration:0,remaining:30};compare(clock.outlineProgress,-1)
   clock.timer={status:'running',duration:60,remaining:Infinity};compare(clock.outlineProgress,-1)
   clock.timer={status:'running',duration:60,remaining:80};compare(clock.outlineProgress,1)
   clock.timer={status:'running',duration:60,remaining:-5};compare(clock.outlineProgress,0)
   clock.timer=null;compare(clock.outlineProgress,-1)
  }
  function test_outline_draws_clockwise_and_clears(){
   let idle=snapshot()
   clock.timer={status:'running',duration:60,remaining:60};let full=snapshot()
   verify(!full.equals(idle),'Starting the timer must draw the outline')
   clock.timer={status:'running',duration:60,remaining:30};let half=snapshot()
   compare(half.pixel(60,14),full.pixel(60,14),'Right side remains at half time')
   compare(half.pixel(1,14),idle.pixel(1,14),'Left side has depleted at half time')
   verify(full.pixel(1,14)!==idle.pixel(1,14),'Full outline covers the left side')
   clock.timer={status:'paused',duration:60,remaining:30};verify(snapshot().equals(half))
   clock.timer={status:'running',duration:60,remaining:0};verify(snapshot().equals(idle))
   clock.timer={status:'finished',duration:60,remaining:0};verify(snapshot().equals(idle))
   clock.timer={status:'running',duration:60,remaining:60};verify(snapshot().equals(full))
   clock.timer={status:'idle',duration:0,remaining:0};verify(snapshot().equals(idle))
  }
  function test_resize_repaints_outline(){
   clock.width=90;let idle=snapshot()
   clock.timer={status:'running',duration:60,remaining:60};let full=snapshot()
   verify(hasPixelChange(full,idle,75,90),'Outline reaches the resized right edge')
   clock.width=62;let smaller=snapshot();compare(smaller.width,62)
   clock.timer={status:'idle',duration:0,remaining:0};let smallerIdle=snapshot()
   verify(hasPixelChange(smaller,smallerIdle,50,62),'Outline follows the smaller right edge')
  }
  function test_hidden_updates_repaint_on_show(){
   clock.timer={status:'running',duration:60,remaining:60};let full=snapshot()
   clock.visible=false;clock.timer={status:'running',duration:60,remaining:30};wait(40)
   clock.visible=true;let half=snapshot();verify(!half.equals(full))
   clock.visible=false;clock.timer={status:'idle',duration:0,remaining:0};wait(40)
   clock.visible=true;let idle=snapshot();verify(!idle.equals(half))
  }
 }
}
