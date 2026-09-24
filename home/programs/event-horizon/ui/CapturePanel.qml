import QtQuick
import QtQuick.Controls
Item {
 id:p
 required property var api
 property string kind:'screenshot'
 property string target:'region'
 property string destination:'file'
 property int delay:0
 property var capture:api.session.capture||{status:'idle',elapsed:0,path:''}
 property bool busy:capture.status==='recording'||capture.status==='preparing'
 function focusFirst(){captureButton.forceActiveFocus()}
 function start(){api.opened=false;api.command('capture_start',{kind:kind,target:target,destination:destination,delay:delay})}
 UiText{text:p.api.t('capture_title');font.family:'ForestSmooth';font.pixelSize:35}
 Row{y:65;spacing:8
  UiButton{width:196;text:p.api.t('capture_screenshot');selected:p.kind==='screenshot';enabled:!p.busy;onClicked:p.kind='screenshot'}
  UiButton{width:196;text:p.api.t('capture_recording');selected:p.kind==='recording';enabled:!p.busy;onClicked:p.kind='recording'}
 }
 UiText{y:125;text:p.api.t('capture_area');font.pixelSize:14;color:'#9bbbad'}
 Row{y:155;spacing:8;Repeater{model:[['region',p.api.t('capture_region')],['window',p.api.t('capture_window')],['monitor',p.api.t('capture_monitor')]];UiButton{required property var modelData;width:128;text:modelData[1];selected:p.target===modelData[0];enabled:!p.busy;onClicked:p.target=modelData[0]}}}
 UiText{y:217;text:p.api.t('capture_delay');font.pixelSize:14;color:'#9bbbad'}
 Row{y:247;spacing:8;Repeater{model:[0,3,5];UiButton{required property int modelData;width:128;text:modelData?modelData+p.api.t('capture_seconds'):p.api.t('capture_now');selected:p.delay===modelData;enabled:!p.busy;onClicked:p.delay=modelData}}}
 UiText{y:309;text:p.api.t('capture_save');font.pixelSize:14;color:'#9bbbad'}
 Row{y:339;spacing:8
  UiButton{width:196;text:p.api.t('capture_file');selected:p.kind==='recording'||p.destination==='file';enabled:!p.busy;onClicked:p.destination='file'}
  UiButton{width:196;text:p.api.t('capture_clipboard');selected:p.kind==='screenshot'&&p.destination==='clipboard';enabled:!p.busy&&p.kind==='screenshot';onClicked:p.destination='clipboard'}
 }
 UiButton{id:captureButton;y:411;width:400;height:48;selected:p.busy;text:p.busy?(p.capture.status==='recording'?p.api.t('capture_stop_elapsed')+p.api.durationText(p.capture.elapsed||0):p.api.t('capture_cancel')):(p.kind==='recording'?p.api.t('capture_start_recording'):p.api.t('capture_start_screenshot'));onClicked:p.busy?p.api.command('capture_stop'):p.start()}
 UiText{y:476;width:400;font.pixelSize:12;wrapMode:Text.Wrap;color:p.capture.status==='failed'?'#ffc8b4':'#9bbbad';text:p.capture.status==='failed'?p.api.t('capture_error'):p.capture.status==='finished'?(p.capture.path?p.api.t('capture_saved')+p.capture.path:p.api.t('capture_copied')):p.capture.status==='cancelled'?p.api.t('capture_cancelled'):p.api.t('capture_hint')}
 UiButton{y:567;width:400;text:p.api.t('capture_open_folder');visible:p.capture.status==='finished'&&!!p.capture.path;onClicked:p.api.command('capture_open_folder')}
}
