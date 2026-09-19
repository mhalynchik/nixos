"""Persistent local agenda, notification history, preferences and timer state."""
import datetime,json,math,os,time,uuid
from pathlib import Path

class DesktopState:
 def __init__(self,path,clock=time.time):
  self.path=Path(path);self.clock=clock;self.error=''
  self.data={'version':1,'agenda':[],'notifications':[],'recent':[],'settings':{'dnd':False,'reducedMotion':False},'timer':{'status':'idle','duration':1500,'remaining':1500,'deadline':0,'generation':0}}
  if self.path.exists():
   try:
    loaded=json.loads(self.path.read_text());assert loaded.get('version')==1
    for key in ['agenda','notifications','recent']:assert isinstance(loaded[key],list)
    assert isinstance(loaded['settings'],dict) and isinstance(loaded['timer'],dict)
    assert all(isinstance(loaded['settings'].get(k),bool) for k in ['dnd','reducedMotion'])
    timer=loaded['timer'];assert timer['status'] in ['idle','running','paused','finished']
    assert all(isinstance(timer[k],(int,float)) and math.isfinite(timer[k]) for k in ['duration','remaining','deadline','generation'])
    assert 1<=timer['duration']<=43200 and 0<=timer['remaining']<=43200
    assert all(isinstance(x,str) for x in loaded['recent'])
    for item in loaded['agenda']:
     assert all(isinstance(item[k],str) for k in ['id','date','title','time','kind']);datetime.date.fromisoformat(item['date']);assert isinstance(item['done'],bool)
    for item in loaded['notifications']:
     assert all(isinstance(item[k],str) for k in ['id','session','app','summary','body']);assert isinstance(item['sourceId'],int) and isinstance(item['read'],bool) and isinstance(item['time'],(float,int))
    self.data.update(loaded)
   except (ValueError,AssertionError,KeyError,TypeError,AttributeError):
    target=self.path.with_name(self.path.name+'.corrupt-'+uuid.uuid4().hex[:8]);self.path.rename(target);self.error='state_recovered'
 def save(self):
  self.path.parent.mkdir(parents=True,exist_ok=True,mode=0o700)
  temp=self.path.with_name(self.path.name+'.tmp')
  fd=os.open(temp,os.O_WRONLY|os.O_CREAT|os.O_TRUNC,0o600)
  with os.fdopen(fd,'w') as f:json.dump(self.data,f,ensure_ascii=False);f.flush();os.fsync(f.fileno())
  os.replace(temp,self.path)
 def setting(self,key,value):
  if key not in ['dnd','reducedMotion'] or not isinstance(value,bool):raise ValueError('invalid_setting')
  self.data['settings'][key]=value;self.save()
 def notify(self,value):
  item={'id':uuid.uuid4().hex,'sourceId':int(value.get('sourceId',value.get('id',0))),'session':str(value.get('session','')),'app':str(value.get('app') or 'Application')[:160],'summary':str(value.get('summary',''))[:512],'body':str(value.get('body',''))[:4096],'time':self.clock(),'read':False}
  self.data['notifications']=[n for n in self.data['notifications'] if (n['session'],n['sourceId'])!=(item['session'],item['sourceId'])]
  self.data['notifications']=(self.data['notifications']+[item])[-200:];self.save();return item
 def read_group(self,app):
  for n in self.data['notifications']:
   if n['app']==app:n['read']=True
  self.save()
 def clear_read(self):self.data['notifications']=[n for n in self.data['notifications'] if not n['read']];self.save()
 def remove_notification(self,ident):self.data['notifications']=[n for n in self.data['notifications'] if n['id']!=ident];self.save()
 def add_task(self,date,title,at='',kind='task'):
  try:datetime.date.fromisoformat(date)
  except (TypeError,ValueError):raise ValueError('invalid_task') from None
  title=str(title).strip()
  if not title or len(title)>240 or kind not in ['task','event']:raise ValueError('invalid_task')
  if at:
   try:assert datetime.datetime.strptime(at,'%H:%M').strftime('%H:%M')==at
   except (TypeError,ValueError,AssertionError):raise ValueError('invalid_task') from None
  item={'id':uuid.uuid4().hex,'date':date,'title':title,'time':at,'kind':kind,'done':False}
  self.data['agenda'].append(item);self.save();return item
 def toggle_task(self,ident):
  for item in self.data['agenda']:
   if item['id']==ident:item['done']=not item['done'];self.save();return
  raise ValueError('task_not_found')
 def delete_task(self,ident):self.data['agenda']=[x for x in self.data['agenda'] if x['id']!=ident];self.save()
 def timer_snapshot(self):
  timer=dict(self.data['timer'])
  if timer['status']=='running':timer['remaining']=max(0,math.ceil(timer['deadline']-self.clock()))
  return timer
 def timer_start(self,seconds):
  seconds=float(seconds)
  if not math.isfinite(seconds) or not 1<=seconds<=43200:raise ValueError('invalid_duration')
  self.data['timer']={'status':'running','duration':int(seconds),'remaining':int(seconds),'deadline':self.clock()+seconds,'generation':self.data['timer']['generation']+1};self.save()
 def timer_pause(self):
  timer=self.timer_snapshot()
  if timer['status']=='running':timer['status']='paused';self.data['timer']=timer;self.save()
 def timer_resume(self):
  timer=self.data['timer']
  if timer['status']=='paused':timer['status']='running';timer['deadline']=self.clock()+timer['remaining'];self.save()
 def timer_reset(self):
  timer=self.data['timer'];timer.update(status='idle',remaining=timer['duration'],deadline=0);self.save()
 def timer_tick(self):
  timer=self.timer_snapshot()
  if timer['status']=='running' and timer['remaining']==0:timer['status']='finished';self.data['timer']=timer;self.save();return True
  return False
 def remember(self,ident):self.data['recent']=([ident]+[i for i in self.data['recent'] if i!=ident])[:20];self.save()

class SearchIndex:
 def __init__(self,apps,files,commands):self.entries={x['id']:x for x in apps+files+commands}
 def resolve(self,ident):
  if ident not in self.entries:raise ValueError('unknown_result')
  return self.entries[ident]
 def search(self,query,recent=()):
  query=query.casefold().strip()[:200]
  if not query:return [self.entries[x] for x in recent if x in self.entries][:12]+[x for x in self.entries.values() if x['kind']=='command' and x['id'] not in recent][:8]
  tokens=query.split();result=[x for x in self.entries.values() if all(t in (x['name']+' '+x.get('keywords','')).casefold() for t in tokens)]
  result.sort(key=lambda x:(not x['name'].casefold().startswith(query),x['kind']=='file',x['name'].casefold()))
  return result[:30]
