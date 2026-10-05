#!/usr/bin/python3
import gi,subprocess
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk,Gdk,GLib

def spawn(args): subprocess.Popen(args,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
def key(s): spawn(['xdotool','key','--clearmodifiers',s])
def keyboard():
 if subprocess.run(['pgrep','-x','xvkbd'],stdout=subprocess.DEVNULL).returncode==0:
  spawn(['pkill','-x','xvkbd']);return
 spawn(['xvkbd','-geometry','720x350+0+930','-no-keypad','-compact'])
 remaining=[25]
 def place():
  r=subprocess.run(['xdotool','search','--class','xvkbd'],text=True,capture_output=True)
  if r.returncode:
   remaining[0]-=1;return remaining[0]>0
  wid=r.stdout.splitlines()[-1]
  subprocess.run(['xprop','-id',wid,'-f','_NET_WM_WINDOW_TYPE','32a','-set','_NET_WM_WINDOW_TYPE','_NET_WM_WINDOW_TYPE_DIALOG'],stdout=subprocess.DEVNULL)
  subprocess.run(['xdotool','windowsize',wid,'720','350','windowmove',wid,'0','930'])
  return False
 GLib.timeout_add(300,place)

def info():
 p=subprocess.run(['nmcli','-t','-f','DEVICE,STATE,CONNECTION','device'],text=True,capture_output=True)
 d=Gtk.MessageDialog(message_type=Gtk.MessageType.INFO,buttons=Gtk.ButtonsType.CLOSE,text='Network')
 d.format_secondary_text(p.stdout or p.stderr);d.run();d.destroy()

def brightness(delta):
 from pathlib import Path
 p=Path('/sys/class/backlight/as3676-backlight')
 (p/'brightness').write_text(str(max(8,min(int((p/'max_brightness').read_text()),int((p/'brightness').read_text())+delta))))
def volume(delta): spawn(['wpctl','set-volume','@DEFAULT_AUDIO_SINK@','5%+' if delta.startswith('+') else '5%-'])
win=Gtk.Window(type=Gtk.WindowType.POPUP);win.set_accept_focus(False)
win.set_default_size(100,70);win.move(620,40)
b=Gtk.Button(label='Menu');win.add(b)
css=Gtk.CssProvider();css.load_from_data(b'* { font-size: 22px; } button, menuitem { padding: 14px; }')
Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(),css,Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
def menu(button):
 m=Gtk.Menu()
 actions=[('Terminal',lambda:spawn(['xterm'])),('Browser',lambda:spawn(['netsurf-gtk'])),('Keyboard',keyboard),('Next window',lambda:key('alt+j')),('Close window',lambda:key('alt+shift+c')),('Brightness +',lambda:brightness(16)),('Brightness -',lambda:brightness(-16)),('Volume +',lambda:volume('+5%')),('Volume -',lambda:volume('-5%')),('Network status',info),('Return to Phosh',lambda:spawn(['pkill','-x','dwm']))]
 for name,action in actions:
  item=Gtk.MenuItem(label=name);item.connect('activate',lambda _,a=action:a());m.append(item)
 m.show_all();m.popup_at_widget(button,Gdk.Gravity.SOUTH_EAST,Gdk.Gravity.NORTH_EAST,None)
b.connect('clicked',menu);win.show_all()
GLib.timeout_add(1000,lambda:(key("alt+m"),False)[1])
Gtk.main()
