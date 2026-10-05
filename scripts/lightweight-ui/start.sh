#!/bin/sh
set -eu
install -d -o phosh -g phosh /run/hikari-lightweight
install -d -m 0700 -o phosh -g phosh /run/hikari-lightweight/runtime
export XAUTHORITY=/run/hikari-lightweight/Xauthority
xauth -f "$XAUTHORITY" add :1 . "$(mcookie)"
chown phosh:phosh "$XAUTHORITY"
chown phosh /sys/class/backlight/as3676-backlight/brightness
export DISPLAY=:1
exec xinit /opt/hikari-lightweight/client.sh -- /usr/lib/xorg/Xorg :1 vt8 -keeptty -nolisten tcp -auth "$XAUTHORITY" -config /opt/hikari-lightweight/xorg.conf -logfile /run/hikari-lightweight/Xorg.log
