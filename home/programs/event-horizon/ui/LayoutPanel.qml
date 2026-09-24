import QtQuick
Item {
 id:p
 required property var api
 readonly property var desktop:api.desktopWidgets
 function focusFirst(){editButton.forceActiveFocus()}
 UiText{text:'Виджеты';font.family:'ForestSmooth';font.pixelSize:35}
 UiText{y:57;width:405;text:'Расположение сохраняется отдельно для каждого монитора. Привяжи его к обоям или используй общий профиль.';wrapMode:Text.Wrap;font.pixelSize:13;color:'#9cbea9'}
 UiText{y:126;width:405;text:p.desktop.monitor;font.pixelSize:13;elide:Text.ElideRight}
 Row{y:159;spacing:10
  UiButton{width:193;text:'Для этих обоев';selected:p.desktop.wallpaperSpecific;onClicked:p.desktop.wallpaperSpecific=true}
  UiButton{width:193;text:'Для монитора';selected:!p.desktop.wallpaperSpecific;onClicked:p.desktop.wallpaperSpecific=false}
 }
 Column{y:221;spacing:12
  Repeater{model:[{key:'clock',name:'Часы и дата'},{key:'calendar',name:'Календарь'},{key:'media',name:'Музыкальный виджет'}]
   Row{required property var modelData;spacing:10
    UiText{width:277;height:36;verticalAlignment:Text.AlignVCenter;text:parent.modelData.name}
    UiButton{width:109;text:p.desktop.widgets[parent.modelData.key].visible?'Виден':'Скрыт';selected:p.desktop.widgets[parent.modelData.key].visible;onClicked:p.desktop.toggle(parent.modelData.key)}
   }
  }
 }
 UiButton{id:editButton;objectName:'layout-edit';y:391;width:396;text:'Разместить на рабочем столе';selected:true;onClicked:p.desktop.beginEditing()}
 UiText{y:443;width:405;text:'Перетаскивание, изменение размера и привязка к сетке. Esc отменяет несохранённые изменения.';wrapMode:Text.Wrap;color:'#9cbea9';font.pixelSize:13}
 Row{y:518;spacing:10
  UiButton{width:193;text:'Сохранить';enabled:p.desktop.dirty;onClicked:p.desktop.save()}
  UiButton{width:193;text:'Отмена';enabled:p.desktop.dirty;onClicked:p.desktop.cancel()}
 }
 UiButton{y:570;width:396;text:'Удалить профиль размещения';onClicked:p.desktop.resetProfile()}
 UiText{y:623;width:405;text:p.desktop.dirty?'Есть несохранённые изменения':'Размер подстраивается под разрешение экрана';font.pixelSize:12;color:'#9cbea9';wrapMode:Text.Wrap}
}
