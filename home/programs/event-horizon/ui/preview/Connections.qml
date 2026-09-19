import QtQuick
QtObject {
 // Visual fixtures only. Replace with a NetworkManager / BlueZ adapter at integration.
 readonly property var networks: [
  {name:'Emerald Home',detail:'WPA3  ·  5 GHz'},
  {name:'Studio',detail:'WPA2  ·  5 GHz'},
  {name:'Guest',detail:'Открытая сеть'}
 ]
 readonly property var devices: [
  {name:'Headphones',detail:'Аудиоустройство'},
  {name:'Wireless keyboard',detail:'Устройство ввода'},
  {name:'Controller',detail:'Игровой контроллер'}
 ]
}
