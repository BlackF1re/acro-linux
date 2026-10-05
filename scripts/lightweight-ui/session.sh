#!/bin/sh
export GDK_BACKEND=x11 LIBGL_ALWAYS_SOFTWARE=1
export XDG_SESSION_TYPE=x11
export XDG_RUNTIME_DIR=/run/hikari-lightweight/runtime
xrdb -merge <<'RESOURCES'
Xft.dpi: 180
XTerm*faceName: DejaVu Sans Mono
XTerm*faceSize: 14
XTerm*scrollBar: true
XTerm*saveLines: 2000
RESOURCES
xrandr --dpi 180
xset s off -dpms
/opt/hikari-lightweight/launcher.py > /run/hikari-lightweight/launcher.log 2>&1 &
(sleep 3; xdotool key alt+m) &
xterm -T 'Hikari terminal' &
exec dwm
