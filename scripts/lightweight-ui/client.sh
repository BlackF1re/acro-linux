#!/bin/sh
exec /usr/sbin/runuser -u phosh -- /usr/bin/dbus-run-session /opt/hikari-lightweight/session.sh
