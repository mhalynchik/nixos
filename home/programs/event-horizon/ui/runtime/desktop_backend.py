"""Session adapters. No shell command interpolation; actions are allowlisted."""
import configparser,datetime,json,math,os,re,select,shutil,signal,subprocess,sys,time,tempfile
from pathlib import Path
from desktop_state import DesktopState,SearchIndex
from idle_settings import IdleSettings
from timer_sound import TimerSoundPlayer
from desktop_profiles import DesktopProfiles
from desktop_tools import DesktopTools
from widget_layout import WidgetLayouts
BASE=Path(__file__).resolve().parent.parent
LABELS=json.loads((BASE/'i18n/ru.json').read_text())

def run(args,timeout=3):
 p=subprocess.run(args,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,timeout=timeout,env=dict(os.environ,LC_ALL='C.UTF-8'))
 if p.returncode:raise RuntimeError((p.stderr.strip() or p.stdout.strip() or 'command_failed')[:350])
 return p.stdout.strip()
def data(args,default):
 try:return json.loads(run(args))
 except (ValueError,OSError,RuntimeError,subprocess.TimeoutExpired):return default
def volume(item):
 channels=list(item.get('volume',{}).values())
 return round(sum(float(x.get('value',0))/65536*100 for x in channels)/max(1,len(channels)))
def audio_label(*values):
 return next((str(v).strip() for v in values if v is not None and str(v).strip().lower() not in ['', '(null)', 'null', 'none']), '')

def audio_rows(rows, group):
 result=[];applications={}
 for x in rows:
  props=x.get('properties',{})
  if group=='sources' and (x.get('monitor_of_sink') not in [None,4294967295,'4294967295'] or x.get('name','').endswith('.monitor')):continue
  row={'id':x['index'],'name':x.get('name',''),'volume':volume(x),'mute':bool(x.get('mute'))}
  if group=='sources':
   # A disconnected analogue jack still exists as a source and may ignore mute.
   # Unknown availability (common on USB/virtual inputs) is not disconnection.
   port=next((p for p in x.get('ports',[]) if p.get('name')==x.get('active_port')),None)
   row['available']=not port or port.get('availability') not in ['not available','no']
  if group=='sink-inputs':
   binary=Path(props.get('application.process.binary','')).name.removeprefix('.').removesuffix('-wrapped')
   label={'floorp':'Floorp','librewolf':'LibreWolf','spotify':'Spotify'}.get(binary) or audio_label(props.get('application.name'),binary,props.get('media.name'),'Audio')
   key=(binary or label,props.get('application.process.id') or x.get('client',x['index']))
   if key not in applications:
    row.update(label=label,ids=[],volumes=[],muted=[]);applications[key]=row;result.append(row)
   app=applications[key];app['ids'].append(x['index']);app['volumes'].append(row['volume']);app['muted'].append(row['mute'])
  else:
   row['label']=audio_label(x.get('description'),props.get('node.description'),props.get('node.nick'),props.get('device.description'),props.get('device.product.name'),props.get('alsa.card_name'),x.get('name'),str(x['index']))
   result.append(row)
 for app in applications.values():
  app['volume']=round(sum(app.pop('volumes'))/len(app['ids']));app['mute']=all(app.pop('muted'))
 return result

def audio_snapshot():
 result={'sinks':[],'sources':[],'streams':[],'defaultSink':'','defaultSource':'','available':False}
 try:
  result['defaultSink']=run(['pactl','get-default-sink']);result['defaultSource']=run(['pactl','get-default-source'])
  for group,key in [('sinks','sinks'),('sources','sources'),('sink-inputs','streams')]:
   result[key]=audio_rows(json.loads(run(['pactl','-f','json','list',group])),group)
  microphones=[x for x in result['sources'] if x['available']]
  if not any(x['name']==result['defaultSource'] for x in microphones):
   result['defaultSource']=microphones[0]['name'] if microphones else ''
  result['available']=True
 except (ValueError,OSError,RuntimeError,subprocess.TimeoutExpired):pass
 return result

def desktop_snapshot():
 monitors=data(['hyprctl','monitors','-j'],[]);windows=data(['hyprctl','clients','-j'],[]);workspaces=data(['hyprctl','workspaces','-j'],[])
 return {'monitors':monitors,'windows':[{'address':x['address'],'title':x.get('title',''),'app':x.get('class',''),'workspace':x['workspace']['id'],'monitor':x.get('monitor',0),'fullscreen':x.get('fullscreen',0),'size':x.get('size',[0,0]),'at':x.get('at',[0,0])} for x in windows if x.get('mapped',True)],'workspaces':workspaces}

def brightness_snapshot():
 try:
  fields=run(['brightnessctl','-c','backlight','-m']).splitlines()[0].split(',')
  value=int(fields[3].rstrip('%'))
  return {'available':True,'value':max(0,min(100,value)),'device':fields[0]}
 except (ValueError,IndexError,OSError,RuntimeError,subprocess.TimeoutExpired):
  return {'available':False,'value':0,'device':''}

def committed_wallpaper(lock=False):
 path=Path(os.environ.get('XDG_STATE_HOME',str(Path.home()/'.local/state')))/('current-lock-wallpaper' if lock else 'current-wallpaper')
 try:return str(path.resolve(strict=True))
 except (OSError,RuntimeError):return ''

def index_apps():
 roots=[Path(os.environ.get('XDG_DATA_HOME',str(Path.home()/'.local/share')))]+[Path(x) for x in os.environ.get('XDG_DATA_DIRS','/usr/local/share:/usr/share').split(':')]
 roots.extend([Path.home()/'.nix-profile/share',Path('/etc/profiles/per-user')/os.environ.get('USER','')/'share',Path('/run/current-system/sw/share')])
 found={};seen=set()
 for root in roots:
  for path in sorted((root/'applications').glob('*.desktop')):
   if path.name in seen:continue
   seen.add(path.name)
   try:
    p=configparser.ConfigParser(interpolation=None,strict=False);p.read(path);v=p['Desktop Entry']
    if v.get('Type','Application')!='Application' or v.getboolean('Hidden',False) or v.getboolean('NoDisplay',False):continue
    if not v.get('Exec'):continue
    entry={'id':'app:'+path.name,'name':v.get('Name[ru]',v.get('Name',path.stem)),'kind':'app','path':str(path),'keywords':v.get('Keywords','')+' '+v.get('GenericName','')};found[entry['id']]=entry
   except (configparser.Error,ValueError,KeyError,OSError):continue
 return list(found.values())
def index_files():
 home=Path.home();roots=[home/x for x in ['Documents','Downloads','Pictures','Desktop','Документы','Загрузки','Изображения','Рабочий стол']];items=[];seen=set()
 for root in roots:
  if not root.is_dir():continue
  for current,dirs,files in os.walk(root,followlinks=False):
   depth=len(Path(current).relative_to(root).parts);dirs[:]=sorted(d for d in dirs if not d.startswith('.') and d not in ['node_modules','target','venv'] and depth<3 and not (Path(current)/d).is_symlink())
   for name in sorted(files):
    p=Path(current)/name
    if name.startswith('.') or p.is_symlink() or str(p) in seen:continue
    seen.add(str(p));items.append({'id':'file:'+str(p),'name':name,'kind':'file','path':str(p),'keywords':str(p.parent.relative_to(home))})
    if len(items)>=10000:return items
 return items

def commands():return [{'id':'command:'+x,'name':LABELS[x],'kind':'command','command':x} for x in ['sound','notifications','overview','agenda','timer','change_wallpaper','animated_wallpaper','power','lock','bluetooth','wifi','connect_headphones','tools','clipboard','capture','layout','profiles','settings']]

class Session:
 def __init__(self):
  root=Path(os.environ.get('EVENT_HORIZON_STATE_DIR',str(Path(os.environ.get('XDG_STATE_HOME',str(Path.home()/'.local/state')))/'event-horizon')))
  self.idle=IdleSettings(root/'idle.json')
  self.timer_sound=TimerSoundPlayer(BASE/'sounds')
  self.profiles=DesktopProfiles(root/'profiles.json');self.tools=DesktopTools(root);self.layouts=WidgetLayouts(root/'layouts.json');self.brightness=brightness_snapshot();self.prune_at=0
  self.store=DesktopState(root/'desktop.json');self.index=SearchIndex(index_apps(),index_files(),commands());self.query='';self.audio={};self.desktop={};self.error=self.store.error or self.idle.error;self.event=None;self.serial=0;self.pending=[]
 def launch(self,args):
  log=tempfile.TemporaryFile(mode='w+t')
  try:process=subprocess.Popen(args,stdin=subprocess.DEVNULL,stdout=subprocess.DEVNULL,stderr=log)
  except OSError:log.close();raise
  self.pending.append((process,log))
 def launch_external(self,args):
  # Applications get their own scope and survive a shell service restart.
  self.launch(['systemd-run','--user','--scope','--quiet','--']+args)
 def lock_screen(self):
  # User services have no caller login session. Resolve our graphical session
  # explicitly instead of asking logind to lock the service's nonexistent one.
  ident=run(['loginctl','show-user',str(os.getuid()),'--property=Display','--value'])
  if not re.fullmatch(r'[A-Za-z0-9_-]+',ident):raise RuntimeError('Активный графический сеанс не найден')
  properties=run(['loginctl','show-session',ident,'--property=User','--property=Active','--property=Remote','--property=Type','--property=Class'])
  session=dict(line.split('=',1) for line in properties.splitlines() if '=' in line)
  if session.get('User')!=str(os.getuid()) or session.get('Active')!='yes' or session.get('Remote')!='no' or session.get('Type')!='wayland':
   raise RuntimeError('Активный локальный сеанс Wayland не найден')
  if session.get('Class')=='greeter':raise RuntimeError('После обновления перезагрузите компьютер: текущий рабочий стол ещё запущен как greeter.')
  run(['systemctl','--user','is-active','hypridle.service'])
  run(['loginctl','lock-session',ident])
  self.event={'kind':'close'}
 def emit(self):
  value={'idle':dict(self.idle.values),'labels':LABELS,'notifications':self.store.data['notifications'],'notificationPolicies':self.store.data['notificationPolicies'],'agenda':self.store.data['agenda'],'preferences':self.store.data['settings'],'timer':self.store.timer_snapshot(),'timerSoundPlaying':self.timer_sound.active,'audio':self.audio,'desktop':self.desktop,'search':self.index.search(self.query,self.store.data['recent']),'query':self.query,'error':self.error,'event':self.event,'serial':self.serial}
  value.update(profiles=self.profiles.snapshot(),brightness=self.brightness,layout=self.layouts.snapshot(committed_wallpaper()),**self.tools.snapshot())
  background=committed_wallpaper(True)
  value['layout']['background']=Path(background).as_uri() if background else ''
  print(json.dumps(value,ensure_ascii=False),flush=True)
 def execute(self,m):
  action=m.get('action','');self.error='';self.event=None
  if action=='search':self.query=str(m.get('query',''))[:200]
  elif action=='refresh':self.index=SearchIndex(index_apps(),index_files(),commands())
  elif action=='launch':
   item=self.index.resolve(m['id']);self.store.remember(item['id'])
   if item['kind']=='app':self.launch_external(['gio','launch',item['path']]);self.event={'kind':'close'}
   elif item['kind']=='file':self.launch_external(['gio','open',item['path']]);self.event={'kind':'close'}
   elif item['command'] in ['sound','notifications','overview','agenda','timer','bluetooth','wifi','tools','clipboard','capture','layout','profiles','settings']:self.event={'kind':'page','page':'media' if item['command']=='sound' else item['command']}
   elif item['command'] in ['change_wallpaper','animated_wallpaper','power']:self.event={'kind':'page','page':{'change_wallpaper':'wallpapers','animated_wallpaper':'animated','power':'power'}[item['command']]}
   elif item['command']=='lock':self.lock_screen()
   elif item['command']=='connect_headphones':self.event={'kind':'page','page':'bluetooth'}
  elif action=='open_applications':self.launch_external(['nwg-drawer']);self.event={'kind':'close'}
  elif action=='open_audio_settings':self.launch_external(['pavucontrol']);self.event={'kind':'close'}
  elif action=='open_connection_settings':
   commands={'wifi':'nm-connection-editor','bluetooth':'blueman-manager'}
   if m.get('kind') not in commands:raise ValueError('unknown_action')
   self.launch_external([commands[m['kind']]]);self.event={'kind':'close'}
  elif action=='power':
   if m.get('operation')=='lock':self.lock_screen()
   else:
    operations={'suspend':['systemctl','suspend'],'logout':['hyprctl','dispatch','exit'],'reboot':['systemctl','reboot'],'poweroff':['systemctl','poweroff']}
    if m.get('operation') not in operations:raise ValueError('unknown_action')
    self.launch_external(operations[m['operation']]);self.event={'kind':'close'}
  elif action=='idle_settings':self.idle.apply({key:m.get(key) for key in ['lockMinutes','screenMinutes','suspendMinutes']})
  elif action=='setting':self.store.setting(m['key'],m['value'])
  elif action=='notify':self.store.notify(m)
  elif action=='read_group':self.store.read_group(m['app'],m.get('conversation'))
  elif action=='read_notification':self.store.read_notification(m['id'])
  elif action=='notification_policy':self.store.notification_policy(m['app'],m['days'],m['limit'])
  elif action=='remove_notification_group':self.store.remove_notification_group(m['app'],m.get('conversation'))
  elif action=='clear_read':self.store.clear_read()
  elif action=='remove_notification':self.store.remove_notification(m['id'])
  elif action=='add_task':self.store.add_task(m['date'],m['title'],m.get('time',''),m.get('kind','task'));self.event={'kind':'task_added'}
  elif action=='toggle_task':self.store.toggle_task(m['id'])
  elif action=='delete_task':self.store.delete_task(m['id'])
  elif action=='timer_start':self.store.timer_start(m['seconds']);self.timer_sound.stop()
  elif action=='timer_pause':self.store.timer_pause()
  elif action=='timer_resume':self.store.timer_resume()
  elif action=='timer_reset':self.store.timer_reset();self.timer_sound.stop()
  elif action=='timer_sound_preview':self.timer_sound.start(self.store.data['settings'],preview=True)
  elif action=='timer_sound_stop':self.timer_sound.stop()
  elif action in ['volume','mute','default_device']:
   self.audio=audio_snapshot();group=m.get('group','sinks');allowed={'sinks':'sink','sources':'source','streams':'sink-input'}
   if group not in allowed:raise ValueError('invalid_audio_group')
   ident=int(m['id']);item=next((x for x in self.audio[group] if x['id']==ident),None)
   if item is None:raise ValueError('device_disappeared')
   if action=='volume':
    level=float(m['value'])
    if not math.isfinite(level) or not 0<=level<=100:raise ValueError('invalid_volume')
    for target in item.get('ids',[ident]):run(['pactl','set-'+allowed[group]+'-volume',str(target),str(round(level))+'%'])
   elif action=='mute':
    for target in item.get('ids',[ident]):run(['pactl','set-'+allowed[group]+'-mute',str(target),'0' if item.get('mute') else '1'])
   else:
    if group not in ['sinks','sources']:raise ValueError('invalid_default')
    run(['pactl','set-default-'+allowed[group],item['name']])
    streamtype='sink-inputs' if group=='sinks' else 'source-outputs'
    old_source=next((x['id'] for x in self.audio.get('sources',[]) if x['name']==self.audio.get('defaultSource')),None)
    for stream in data(['pactl','-f','json','list',streamtype],[]):
     # Output-monitor capture belongs to the visualizer, not to microphone selection.
     if group=='sources' and (old_source is None or stream.get('source')!=old_source):continue
     run(['pactl','move-'+('sink-input' if group=='sinks' else 'source-output'),str(stream['index']),item['name']])
   self.audio=audio_snapshot()
  elif action=='profile_save':self.profiles.save(m['name'],m['values'])
  elif action=='profile_apply':
   self.profiles.apply(m['name'],self.capture_profile,self.apply_profile);self.event={'kind':'profile','name':m['name']}
  elif action=='profile_restore':self.profiles.restore(self.apply_profile,self.capture_profile);self.event={'kind':'profile','name':''}
  elif action=='layout_save':self.layouts.save(m['monitor'],m.get('wallpaper',''),m['widgets'])
  elif action=='layout_reset':self.layouts.reset(m['monitor'],m.get('wallpaper',''))
  elif action=='brightness':
   self.brightness=brightness_snapshot()
   if self.brightness['available']:
    level=max(1,min(100,self.brightness['value']+max(-5,min(5,int(m['delta'])))))
    run(['brightnessctl','-c','backlight','set',str(level)+'%']);self.brightness=brightness_snapshot()
  elif action=='output_mute':run(['pactl','set-sink-mute','@DEFAULT_SINK@','toggle']);self.audio=audio_snapshot()
  elif action=='quick_volume':
   self.audio=audio_snapshot();delta=max(-5,min(5,int(m['delta'])));device=next((x for x in self.audio['sinks'] if x['name']==self.audio['defaultSink']),None)
   if device is None:raise ValueError('device_disappeared')
   level=max(0,min(100,device['volume']+delta));run(['pactl','set-sink-volume','@DEFAULT_SINK@',str(level)+'%']);self.audio=audio_snapshot()
  elif action=='mic_mute':
   self.audio=audio_snapshot();source=self.audio['defaultSource']
   if not source:raise ValueError('device_disappeared')
   run(['pactl','set-source-mute',source,'toggle']);self.audio=audio_snapshot()
  elif action in ['focus_window','move_window','workspace']:
   self.desktop=desktop_snapshot()
   if action=='workspace':
    workspace=int(m['workspace']);assert 1<=workspace<=99;run(['hyprctl','dispatch','workspace',str(workspace)]);self.event={'kind':'close'}
   else:
    address=str(m['address'])
    if not re.fullmatch(r'0x[0-9a-fA-F]+',address) or not any(x['address']==address for x in self.desktop['windows']):raise ValueError('window_disappeared')
    if action=='focus_window':run(['hyprctl','dispatch','focuswindow','address:'+address]);self.event={'kind':'close'}
    else:
     workspace=int(m['workspace']);assert 1<=workspace<=99;run(['hyprctl','dispatch','movetoworkspacesilent',str(workspace)+',address:'+address])
   self.desktop=desktop_snapshot()
  elif action=='capture_open_folder':
   path=self.tools.snapshot()['capture'].get('path','')
   if path and Path(path).is_file():self.launch_external(['xdg-open',str(Path(path).parent)]);self.event={'kind':'close'}
  elif action.startswith(('clipboard_','capture_')):
   if not self.tools.handle(action,m):raise ValueError('unknown_action')
   if action=='capture_start':self.event={'kind':'close'}
  elif action=='dismiss_error':self.error=''
  else:raise ValueError('unknown_action')
  self.serial+=1
 def capture_profile(self):
  self.audio=audio_snapshot();self.brightness=brightness_snapshot()
  sink=next((x for x in self.audio['sinks'] if x['name']==self.audio['defaultSink']),None)
  return {'dnd':self.store.data['settings']['dnd'],'volume':sink['volume'] if sink else None,'brightness':self.brightness['value'] if self.brightness['available'] else None,'widgets':dict(clock=True,calendar=True,media=True),'outputName':sink['name'] if sink else '', 'brightnessDevice':self.brightness['device']}
 def apply_profile(self,values):
  target=values.get('outputName',self.audio.get('defaultSink'))
  if values['volume'] is not None and any(s['name']==target for s in self.audio.get('sinks',[])):
   run(['pactl','set-sink-volume',target,str(values['volume'])+'%'])
  if values['brightness'] is not None and self.brightness['available'] and values.get('brightnessDevice',self.brightness['device'])==self.brightness['device']:
   run(['brightnessctl','-c','backlight','set',str(max(1,values['brightness']))+'%'])
  self.store.setting('dnd',values['dnd']);self.audio=audio_snapshot();self.brightness=brightness_snapshot()
 def poll(self):
  remaining=[]
  for process,log in self.pending:
   code=process.poll()
   if code is None:remaining.append((process,log));continue
   if code!=0:log.seek(0);self.error=log.read(350).strip() or 'launch_failed';self.serial+=1
   log.close()
  self.pending=remaining
  self.audio=audio_snapshot();self.desktop=desktop_snapshot();self.brightness=brightness_snapshot()
  if time.monotonic()>=getattr(self,'prune_at',0):
   self.store.prune_notifications();self.prune_at=time.monotonic()+60
  try:self.timer_sound.poll()
  except (OSError,RuntimeError) as error:self.error=str(error)[:350];self.serial+=1
  if self.store.timer_tick():
   self.event={'kind':'timer_finished'};self.serial+=1
   try:self.timer_sound.start(self.store.data['settings'])
   except (OSError,RuntimeError) as error:self.error=str(error)[:350]

def main():
 session=Session()
 try:serve(session)
 finally:
  session.timer_sound.stop();session.tools.close()

def serve(session):
 last=0;pending=b''
 while True:
  if select.select([sys.stdin],[],[],.2)[0]:
   chunk=os.read(sys.stdin.fileno(),65536)
   if not chunk:return
   pending+=chunk
   # TextIO.readline can buffer the next command while select sees an empty FD.
   # Drain complete messages immediately, even when no further input arrives.
   while b'\n' in pending:
    line,pending=pending.split(b'\n',1)
    try:session.execute(json.loads(line))
    except (ValueError,TypeError,KeyError,AssertionError,OSError,RuntimeError,subprocess.TimeoutExpired) as exc:session.error=str(exc)[:350];session.serial+=1
    session.emit();session.event=None
  if time.monotonic()-last>=1:
   session.poll();session.emit();session.event=None;last=time.monotonic()
if __name__=='__main__':main()
