import QtQuick
import QtTest
import "../../ui" as Shell
Item {
 width:430;height:650
 QtObject {
  id:testApi
  property var session:({idle:{lockMinutes:10,screenMinutes:15,suspendMinutes:30}})
  property var sent:null
  function t(key){return key}
  function command(action,args){sent={action:action,args:args}}
 }
 Shell.SettingsPanel{id:panel;anchors.fill:parent;api:testApi}
 TestCase {
  name:'IdleSettings';when:windowShown
  function init(){testApi.session={idle:{lockMinutes:10,screenMinutes:15,suspendMinutes:30}};panel.load(testApi.session.idle);testApi.sent=null}
  function test_validation_and_explicit_apply(){
   let lock=findChild(panel,'idle-lock'),screen=findChild(panel,'idle-screen'),sleep=findChild(panel,'idle-suspend'),apply=findChild(panel,'idle-apply')
   compare(apply.enabled,false)
   lock.text='60';compare(apply.enabled,false)
   screen.text='60';sleep.text='90';compare(apply.enabled,true)
   compare(testApi.sent,null)
   mouseClick(apply)
   compare(testApi.sent.action,'idle_settings');compare(testApi.sent.args,{lockMinutes:60,screenMinutes:60,suspendMinutes:90})
   compare(panel.dirty,true)
   testApi.session={idle:{lockMinutes:60,screenMinutes:60,suspendMinutes:90}}
   compare(panel.dirty,false);compare(apply.enabled,false)
   lock.text='';compare(apply.enabled,false)
   lock.text='241';compare(apply.enabled,false)
  }
  function test_polling_preserves_draft_and_cancel_restores_saved(){
   findChild(panel,'idle-lock').text='5'
   testApi.session={idle:{lockMinutes:10,screenMinutes:15,suspendMinutes:30},audio:{}}
   compare(findChild(panel,'idle-lock').text,'5')
   mouseClick(findChild(panel,'idle-cancel'))
   compare(findChild(panel,'idle-lock').text,'10');compare(panel.dirty,false)
  }
  function test_disable_all_idle_actions(){
   panel.load({lockMinutes:0,screenMinutes:0,suspendMinutes:0})
   let apply=findChild(panel,'idle-apply');compare(apply.enabled,true)
   mouseClick(apply);compare(testApi.sent.args,{lockMinutes:0,screenMinutes:0,suspendMinutes:0})
  }
  function test_waits_for_initial_backend_preferences(){
   testApi.session={};panel.initialized=false
   compare(panel.enabled,false)
   testApi.session={idle:{lockMinutes:45,screenMinutes:60,suspendMinutes:0}}
   tryCompare(findChild(panel,'idle-lock'),'text','45')
   compare(panel.enabled,true);compare(panel.dirty,false)
  }
 }
}
