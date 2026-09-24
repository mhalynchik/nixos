import QtQuick
import QtQuick.Controls
Item {
 id:p
 required property var api
 readonly property var metrics:api.telemetry||({})
 readonly property var gpus:metrics.gpus||[]
 function metric(value,suffix){return value===null||value===undefined?'—':Math.round(value)+suffix}
 UiText{text:'Система';font.family:'ForestSmooth';font.pixelSize:39}
 UiText{y:57;text:'Использование ресурсов';color:'#91b4a5';font.pixelSize:13}
 Gravity{x:105;y:78;width:210;height:185;phase:p.api.phase;galaxy:true}
 Row{y:275;spacing:35
  Column{spacing:7;UiText{text:p.metric(p.metrics.cpu,'%');font.pixelSize:32;color:p.api.accent}UiText{text:'CPU';color:'#91b4a5';font.pixelSize:11}}
  Column{spacing:7;UiText{text:p.metric(p.metrics.ramPercent,'%');font.pixelSize:32;color:p.api.accent}UiText{text:'RAM';color:'#91b4a5';font.pixelSize:11}}
  Column{spacing:7;UiText{text:p.metrics.processCount||0;font.pixelSize:32;color:p.api.accent}UiText{text:'ПРОЦЕССОВ';color:'#91b4a5';font.pixelSize:11}}
 }
 UiText{y:363;text:'ГРАФИКА';font.pixelSize:11;font.letterSpacing:1.7;color:'#91b4a5'}
 UiText{y:398;width:parent.width;visible:p.gpus.length===0;text:'Нет доступных данных GPU';font.pixelSize:14;color:'#91b4a5'}
 Flickable{y:391;width:parent.width;height:178;clip:true;visible:p.gpus.length>0;contentHeight:gpuRows.height
  ScrollBar.vertical:ScrollBar{}
  Column{id:gpuRows;width:parent.width-12;spacing:12
   Repeater{model:p.gpus
    Rectangle{
     required property var modelData
     width:gpuRows.width;height:112;radius:12;color:'#22112c23';border.color:'#386ba087';border.width:1
     UiText{x:12;y:8;width:parent.width-24;height:38;text:parent.modelData.name;wrapMode:Text.Wrap;maximumLineCount:2;elide:Text.ElideRight;font.pixelSize:14}
     Row{x:12;y:52;spacing:13
      Column{width:90;spacing:4
       UiText{text:p.metric(modelData.utilization,'%');font.pixelSize:19;color:p.api.accent}
       UiText{text:'Загрузка';font.pixelSize:10;color:'#91b4a5'}
      }
      Column{width:168;spacing:4
       UiText{text:modelData.memoryTotalMiB===null||modelData.memoryTotalMiB===undefined?'—':(modelData.memoryUsedMiB===null?'—':(modelData.memoryUsedMiB/1024).toFixed(1))+' / '+(modelData.memoryTotalMiB/1024).toFixed(1)+' GiB';font.pixelSize:17;color:p.api.accent}
       UiText{text:'Видеопамять';font.pixelSize:10;color:'#91b4a5'}
      }
      Column{width:74;spacing:4
       UiText{text:p.metric(modelData.temperatureC,'°');font.pixelSize:19;color:p.api.accent}
       UiText{text:'Темп.';font.pixelSize:10;color:'#91b4a5'}
      }
     }
     UiText{x:12;y:96;text:'—  датчик недоступен';visible:modelData.utilization===null||modelData.memoryTotalMiB===null||modelData.temperatureC===null;font.pixelSize:9;color:'#769689'}
    }
   }
  }
 }
 Column{y:591;spacing:6;width:parent.width
  Repeater{model:(p.metrics.top||[]).slice(0,3)
   UiText{required property var modelData;width:p.width;text:'✧   '+modelData.name+'   /   '+Math.round(modelData.rss)+' MiB';font.pixelSize:12;elide:Text.ElideRight}
  }
 }
}
