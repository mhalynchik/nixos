import subprocess,socket,json,os,time,select,sys,threading,pathlib,signal
BASE=pathlib.Path(__file__).parent
RUNTIME=pathlib.Path(os.environ.get('XDG_RUNTIME_DIR','/tmp'))/('event-horizon-preview-'+str(os.getpid()))
RUNTIME.mkdir(mode=0o700,parents=True,exist_ok=True)
SOCK=str(RUNTIME/'mpv.sock')
try: os.unlink(SOCK)
except FileNotFoundError: pass
mpv=subprocess.Popen(['mpv','--no-video','--idle=yes','--no-terminal','--volume=48','--ao=pulse','--input-ipc-server='+SOCK],stdout=subprocess.DEVNULL,stderr=open(RUNTIME/'mpv.log','w'))
for _ in range(100):
 if os.path.exists(SOCK):break
 time.sleep(.05)
sock=socket.socket(socket.AF_UNIX);sock.connect(SOCK);f=sock.makefile('r');request_id=0

def command(*cmd):
 global request_id
 request_id+=1;sock.sendall((json.dumps({'command':cmd,'request_id':request_id})+'\n').encode())
 while True:
  msg=json.loads(f.readline())
  if msg.get('request_id')==request_id:return msg.get('data')

cfg=RUNTIME/'cava.conf';cfg.write_text('[general]\nframerate = 30\nbars = 48\nsensitivity = 180\n[input]\nmethod = pulse\nsource = auto\n[output]\nmethod = raw\nraw_target = /dev/stdout\ndata_format = ascii\nascii_max_range = 1000\n[smoothing]\nnoise_reduction = 65\n')
cava=subprocess.Popen(['cava','-p',str(cfg)],stdout=subprocess.PIPE,stderr=open(RUNTIME/'cava.log','w'),text=True)
bars=[0]*48

def read_cava():
 global bars
 for line in cava.stdout:
  try:
   values=[int(x)/1000 for x in line.strip().split(';') if x]
   if len(values)==48:bars=values
  except ValueError:pass
threading.Thread(target=read_cava,daemon=True).start()
index=0;gains=[0]*5;freqs=[60,230,910,3600,14000]
titles=['Emerald Signals','Cloud Garden','After the Rain']

def load():command('loadfile',str(BASE/f'track{index}.wav'),'replace');command('set_property','loop-file','inf');command('set_property','pause',False)
def eq():
 command('set_property','af','lavfi=['+','.join(f'equalizer=f={hz}:t=o:w=1:g={g}' for hz,g in zip(freqs,gains))+']')
load();command('set_property','pause',True)
last=0
def shutdown(*args):raise SystemExit
signal.signal(signal.SIGTERM,shutdown)
try:
 while True:
  if select.select([sys.stdin],[],[],.03)[0]:
   line=sys.stdin.readline()
   if not line:break
   try:
    m=json.loads(line);act=m['action']
    if act=='play':
     if command('get_property','idle-active'):load()
     else:command('cycle','pause')
    elif act=='stop':command('stop')
    elif act in ('next','previous'):
     index=(index+(1 if act=='next' else -1))%3;load()
    elif act=='seek':command('seek',m['value'],'absolute')
    elif act=='eq':gains[int(m['band'])]=float(m['value']);eq()
    elif act=='preset':gains={'flat':[0,0,0,0,0],'warm':[5,3,0,-2,-3],'air':[-2,0,2,4,5]}[m['name']];eq()
   except Exception as e:print(str(e),file=sys.stderr,flush=True)
  if time.monotonic()-last>.065:
   idle=command('get_property','idle-active');paused=command('get_property','pause')
   print(json.dumps({'track':index,'title':titles[index],'playing':not paused and not idle,'stopped':bool(idle),'position':command('get_property','time-pos') or 0,'duration':command('get_property','duration') or 48,'bands':bars if not idle else [0]*48,'gains':gains,'filters':command('get_property','af')}),flush=True);last=time.monotonic()
finally:
 cava.terminate();mpv.terminate()
 for process in [cava,mpv]:
  try:process.wait(timeout=2)
  except subprocess.TimeoutExpired:process.kill();process.wait()
 import shutil
 shutil.rmtree(RUNTIME,ignore_errors=True)
