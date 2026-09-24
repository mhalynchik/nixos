import json, math, os, time
from pathlib import Path
from gpu import GpuTelemetry
gpus=GpuTelemetry()
previous=None
history=[]
def read():
    global previous,history
    cpu=list(map(int,Path('/proc/stat').read_text().splitlines()[0].split()[1:9]))
    total=sum(cpu); idle=cpu[3]+cpu[4]
    percent=0 if previous is None else max(0,min(100,100*(1-(idle-previous[1])/max(1,total-previous[0]))))
    previous=(total,idle)
    mem={line.split(':')[0]:int(line.split()[1]) for line in Path('/proc/meminfo').read_text().splitlines()}
    processes={}
    for d in Path('/proc').iterdir():
        if not d.name.isdigit(): continue
        try:
            raw=(d/'stat').read_text(); name=raw[raw.index('(')+1:raw.rindex(')')]; f=raw[raw.rindex(')')+2:].split()
            cmd=(d/'cmdline').read_bytes().split(b'\0')[0].decode(errors='replace')
            if cmd: name=Path(cmd).name.lstrip('.').removesuffix('-wrapped')
            rss=max(0,int(f[21]))*os.sysconf('SC_PAGE_SIZE')//1048576
            processes[int(d.name)]={'pid':int(d.name),'parent':int(f[1]),'name':name,'rss':rss}
        except (OSError,ValueError,IndexError): pass
    top=sorted((p for p in processes.values() if p['rss']>0),key=lambda p:-p['rss'])[:5]
    chosen={1}
    for p in sorted(processes.values(),key=lambda p:-p['rss'])[:36]:
        n=p['pid']; seen=set()
        while n in processes and n not in seen:
            chosen.add(n); seen.add(n); n=processes[n]['parent']
    nodes={k:processes[k] for k in chosen if k in processes}
    children={k:sorted(n for n in nodes if nodes[n]['parent']==k and n!=k) for k in nodes}
    angles={};depths={};leaf=0
    def visit(n,depth):
        nonlocal leaf
        depths[n]=depth
        if children[n]:
            a=[visit(c,depth+1) for c in children[n]]; angles[n]=sum(a)/len(a)
        else: angles[n]=leaf; leaf+=1
        return angles[n]
    if 1 in nodes:visit(1,0)
    graph=[]
    for n,p in nodes.items():
        if n not in depths:continue
        angle=(angles[n]+.5)/max(1,leaf)*2*math.pi-math.pi/2
        radius=min(1,depths[n]/max(1,max(depths.values())))**.55
        graph.append(dict(p,x=math.cos(angle)*radius,y=math.sin(angle)*radius,depth=depths[n]))
    history=(history+[round(percent,1)])[-40:]
    return {'gpus':gpus.read(),'cpu':round(percent,1),'ram':round((mem['MemTotal']-mem['MemAvailable'])/1048576,2),'ramTotal':round(mem['MemTotal']/1048576,2),'ramPercent':round(100*(1-mem['MemAvailable']/mem['MemTotal'])),'processCount':len(processes),'top':top,'graph':graph,'history':history,'uptime':int(float(Path('/proc/uptime').read_text().split()[0]))}
if __name__ == '__main__':
    while True:
        print(json.dumps(read()),flush=True)
        time.sleep(2)
