import QtQuick
import QtTest
import "../../ui" as Shell
Item {
 width:450;height:650
 QtObject {
  id:testApi
  property string page:'wallpapers'
  property bool opened:true
  property var wallpapers:({items:[],directories:{},error:''})
  property var calls:[]
  function wallpaperCommand(action,extra){calls=calls.concat([{action:action,id:extra?.id}])}
 }
 Shell.WallpaperPanel{id:panel;anchors.fill:parent;api:testApi}
 TestCase {
  name:'WallpaperSelection';when:windowShown
  function test_updates_do_not_recreate_tiles_or_lose_enter() {
   let items=[]
   for(let i=0;i<12;i++)items.push({id:'id'+i,name:'Wallpaper '+i,kind:'static',thumbnail:''})
   testApi.wallpapers={items:items,directories:{},error:''};wait(50)
   let grid=findChild(panel,'wallpaperGrid')
   grid.forceActiveFocus();grid.currentIndex=1;wait(260)
   let tile=findChild(panel,'wallpaperTile1');verify(tile!==null)
   testApi.calls=[]
   for(let i=0;i<100;i++){
    let updated=items.map(x=>Object.assign({},x))
    testApi.wallpapers={items:updated,directories:{},preview:'id1',error:''}
    wait(1)
   }
   compare(findChild(panel,'wallpaperTile1'),tile)
   compare(grid.currentIndex,1);compare(panel.selected,'id1')
   compare(testApi.calls.length,0)
   keyClick(Qt.Key_Return);wait(20)
   compare(testApi.calls.length,1);compare(testApi.calls[0].action,'commit');compare(testApi.calls[0].id,'id1')
   panel.choose('id2');wait(270)
   compare(testApi.calls.length,1)
   testApi.wallpapers=Object.assign({},testApi.wallpapers,{error:'Temporary failure'});wait(20)
   compare(panel.committing,false)
   keyClick(Qt.Key_Return);compare(testApi.calls.length,2)
   // Closing/reopening during the collapse does not destroy the panel.
   testApi.opened=false;wait(20);testApi.calls=[]
   testApi.opened=true;wait(280)
   verify(testApi.calls.some(x=>x.action==='index'))
   verify(testApi.calls.some(x=>x.action==='preview'&&x.id==='id1'))
   testApi.calls=[];keyClick(Qt.Key_Return)
   compare(testApi.calls[0].action,'commit')
  }
 }
}
