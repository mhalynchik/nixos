import QtQuick
import QtTest
import "../../ui" as Shell
Item {
 width:430;height:650
 QtObject{id:api;property var telemetry:({});property real phase:0;property color accent:'#83dab3'}
 Shell.SystemPanel{id:panel;anchors.fill:parent;api:api}
 TestCase{
  name:'SystemPanel';when:windowShown
  function test_gpu_states_data(){return [
   {tag:'not-yet-loaded',value:{}},
   {tag:'no-gpu',value:{gpus:[]}},
   {tag:'unknown-sensors',value:{gpus:[{name:'Unknown GPU',utilization:null,memoryTotalMiB:null,memoryUsedMiB:null,temperatureC:null}]}},
   {tag:'multiple-gpus',value:{gpus:[{name:'AMD Radeon',utilization:32,memoryUsedMiB:2048,memoryTotalMiB:8192,temperatureC:50},{name:'Intel Arc',utilization:null,memoryUsedMiB:null,memoryTotalMiB:null,temperatureC:null},{name:'NVIDIA GeForce',utilization:0,memoryUsedMiB:1024,memoryTotalMiB:16384,temperatureC:34}]}}
  ]}
  function test_gpu_states(data){
   api.telemetry=data.value
   api.phase+=.1
   compare(panel.gpus.length,(data.value.gpus||[]).length)
   verify(waitForRendering(panel))
   verify(grabImage(panel).width>0)
  }
  function test_missing_metrics_stay_distinct_from_zero(){
   compare(panel.metric(null,'%'),'—')
   compare(panel.metric(undefined,'%'),'—')
   compare(panel.metric(0,'%'),'0%')
   compare(panel.metric(50.7,'°'),'51°')
  }
 }
}
