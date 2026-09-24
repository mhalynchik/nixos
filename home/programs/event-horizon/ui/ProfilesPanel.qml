import QtQuick
Item {
 id:p;required property var api
 property string chosen:'work'
 property var preset:api.session.profiles?.presets?.[chosen]||({dnd:false,volume:null,brightness:null,widgets:{clock:true,calendar:true,media:true}})
 property bool draftDnd:false
 property var widgets:({clock:true,calendar:true,media:true})
 function load(){draftDnd=preset.dnd;volume.text=preset.volume===null?'':String(preset.volume);brightness.text=preset.brightness===null?'':String(preset.brightness);widgets=Object.assign({},preset.widgets)}
 function focusFirst(){load();volume.forceActiveFocus()}
 onChosenChanged:load()
 onPresetChanged:Qt.callLater(load)
 Component.onCompleted:load()
 UiText{text:api.t('profiles');font.family:'ForestSmooth';font.pixelSize:35}
 Row{y:60;spacing:8;Repeater{model:['work','music','evening'];UiButton{required property string modelData;width:128;text:api.t('profile_'+modelData);selected:p.chosen===modelData;onClicked:p.chosen=modelData}}}
 UiText{y:116;width:400;text:api.t('profile_description');wrapMode:Text.Wrap;font.pixelSize:13;color:'#a1c5b3'}
 UiButton{y:185;width:400;text:api.t('dnd');selected:p.draftDnd;onClicked:p.draftDnd=!p.draftDnd}
 UiText{y:244;text:api.t('system_volume')}
 UiField{id:volume;x:280;y:232;width:120;placeholderText:'—';validator:IntValidator{bottom:0;top:100}}
 UiText{y:302;text:api.t('brightness')+(api.session.brightness?.available?'':' · '+api.t('unavailable'))}
 UiField{id:brightness;x:280;y:290;width:120;placeholderText:'—';validator:IntValidator{bottom:0;top:100}}
 UiText{y:348;width:400;text:api.t('profile_blank');font.pixelSize:12;wrapMode:Text.Wrap;color:'#a1c5b3'}
 Row{y:400;spacing:8;Repeater{model:['clock','calendar','media'];UiButton{required property string modelData;width:128;text:api.t('widget_'+modelData);selected:p.widgets[modelData]!==false;onClicked:p.widgets=Object.assign({},p.widgets,{[modelData]:!selected})}}}
 UiButton{y:460;width:400;text:api.t('profile_save_apply');selected:true;enabled:(!volume.text||volume.acceptableInput)&&(!brightness.text||brightness.acceptableInput);onClicked:{api.command('profile_save',{name:p.chosen,values:{dnd:p.draftDnd,volume:volume.text?Number(volume.text):null,brightness:brightness.text?Number(brightness.text):null,widgets:p.widgets}});api.command('profile_apply',{name:p.chosen})}}
 UiButton{y:512;width:400;text:api.t('profile_restore');enabled:!!api.session.profiles?.canRestore;onClicked:api.command('profile_restore')}
 UiText{y:566;width:400;text:api.session.profiles?.active?api.t('profile_active')+': '+api.t('profile_'+api.session.profiles.active):api.t('profile_manual');color:'#a1c5b3';wrapMode:Text.Wrap;font.pixelSize:12}
}
