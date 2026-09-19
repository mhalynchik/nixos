"""Controllable MPRIS service for the disposable VM; never imported by the shell.

Contract: https://specifications.freedesktop.org/mpris-spec/latest/
"""
from gi.repository import Gio, GLib

root='org.mpris.MediaPlayer2'
player=root+'.Player'
path='/org/mpris/MediaPlayer2'
properties={root:{'Identity':('s','MPRIS integration'), 'DesktopEntry':('s','test-player'),
    'CanQuit':('b',False),'CanRaise':('b',False),'HasTrackList':('b',False),
    'SupportedUriSchemes':('as',[]),'SupportedMimeTypes':('as',[])},
    player:{'PlaybackStatus':('s','Playing'),'LoopStatus':('s','None'),'Rate':('d',1.0),
    'Shuffle':('b',False),'Volume':('d',.5),'Position':('x',0),'MinimumRate':('d',1.0),'MaximumRate':('d',1.0),
    'CanGoNext':('b',True),'CanGoPrevious':('b',True),'CanPlay':('b',True),'CanPause':('b',True),'CanSeek':('b',True),'CanControl':('b',True),
    'Metadata':('a{sv}',{'mpris:trackid':GLib.Variant('o','/test/track'),'mpris:length':GLib.Variant('x',180000000),
    'xesam:title':GLib.Variant('s','Emerald · проверка плеера'),'xesam:artist':GLib.Variant('as',['Тест интеграции'])})}}
connection=Gio.bus_get_sync(Gio.BusType.SESSION,None)


def call(connection,sender,path,interface,method,parameters,invocation):
    if method in ['PlayPause','Play','Pause','Stop']:
        old=properties[player]['PlaybackStatus'][1]
        value='Stopped' if method=='Stop' else 'Paused' if method=='Pause' or method=='PlayPause' and old=='Playing' else 'Playing'
        properties[player]['PlaybackStatus']=('s',value)
        connection.emit_signal(None,path,'org.freedesktop.DBus.Properties','PropertiesChanged',
            GLib.Variant('(sa{sv}as)',(player,{'PlaybackStatus':GLib.Variant('s',value)},[])))
    if method in ['Next','Previous']:
        metadata=properties[player]['Metadata'][1]
        old=metadata['xesam:title'].unpack()
        metadata['xesam:title']=GLib.Variant('s',method+' · '+old)
        connection.emit_signal(None,path,'org.freedesktop.DBus.Properties','PropertiesChanged',
            GLib.Variant('(sa{sv}as)',(player,{'Metadata':GLib.Variant('a{sv}',metadata)},[])))
    invocation.return_value(None)


for interface,values in properties.items():
    xml='<node><interface name="'+interface+'">'
    for name,(kind,value) in values.items():xml+='<property name="'+name+'" type="'+kind+'" access="read"/>'
    if interface==player:
        for name in ['Play','Pause','PlayPause','Stop','Next','Previous']:xml+='<method name="'+name+'"/>'
        xml+='<method name="Seek"><arg type="x" direction="in"/></method><method name="SetPosition"><arg type="o" direction="in"/><arg type="x" direction="in"/></method>'
    xml+='</interface></node>'
    info=Gio.DBusNodeInfo.new_for_xml(xml)
    connection.register_object(path,info.interfaces[0],call,
        lambda c,s,p,i,n: GLib.Variant(*properties[i][n]),None)
Gio.bus_own_name_on_connection(connection,'org.mpris.MediaPlayer2.eh_test',Gio.BusNameOwnerFlags.NONE,None,None)
GLib.MainLoop().run()
