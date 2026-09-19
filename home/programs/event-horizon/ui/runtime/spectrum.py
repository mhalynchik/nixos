"""Read the actual default output monitor. Lifetime follows visible visualizer."""
import json,os,pathlib,signal,subprocess,tempfile

def stop(*args):raise SystemExit
signal.signal(signal.SIGTERM,stop)
with tempfile.TemporaryDirectory(prefix='event-horizon-cava-',dir=os.environ.get('XDG_RUNTIME_DIR')) as folder:
 config=pathlib.Path(folder)/'cava.conf'
 config.write_text('[general]\nframerate = 20\nbars = 48\nsensitivity = 150\n[input]\nmethod = pulse\nsource = auto\n[output]\nmethod = raw\nraw_target = /dev/stdout\ndata_format = ascii\nascii_max_range = 1000\n[smoothing]\nnoise_reduction = 65\n')
 process=subprocess.Popen(['cava','-p',str(config)],stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,text=True)
 try:
  for line in process.stdout:
   try:
    values=[max(0,min(1,int(x)/1000)) for x in line.strip().split(';') if x]
    if len(values)==48:print(json.dumps(values),flush=True)
   except ValueError:pass
 finally:
  process.terminate()
  try:process.wait(timeout=2)
  except subprocess.TimeoutExpired:process.kill();process.wait()
