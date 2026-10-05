#!/usr/bin/python3
import time,json,pathlib,sys,os
NAMES=set(sys.argv[1:]) or {'Xorg','dwm','launcher.py','dbus-daemon','xterm','xvkbd','netsurf-gtk'}
def read():
 out={}
 for p in pathlib.Path('/proc').glob('[0-9]*'):
  try:
   n=(p/'comm').read_text().strip()
   if n not in NAMES:continue
   st=(p/'stat').read_text();st=st[st.rfind(')')+2:].split()
   sm=(p/'smaps_rollup').read_text();mem={x.split(':')[0]:int(x.split()[1]) for x in sm.splitlines() if x.startswith(('Pss:','Rss:'))}
   out[p.name]={'name':n,'ticks':int(st[11])+int(st[12]),**mem}
  except (OSError,ValueError):pass
 return out
x=read();t=time.monotonic();time.sleep(10);y=read();dt=time.monotonic()-t
hz=os.sysconf('SC_CLK_TCK')
for k,v in y.items():v['cpu_percent_one_core']=(v['ticks']-x.get(k,v)['ticks'])/hz/dt*100
print(json.dumps({'seconds':dt,'processes':y,'cpu_percent_one_core':sum(v['cpu_percent_one_core'] for v in y.values()),'pss_kib':sum(v['Pss'] for v in y.values())},indent=2))
