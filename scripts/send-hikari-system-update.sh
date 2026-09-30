#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Send a prepared SYSTEM archive over USB NCM; retain XMODEM as a fallback.
set -euo pipefail

mode=usb
if [[ ${1:-} == --xmodem ]]; then
	mode=xmodem
	shift
fi
tty=${1:-/dev/ttyACM0}
archive=${2:-/home/paul/xperia/build/hikari-debian-current/hikari-system-update.tar}
test -c "$tty" || { echo "not a tty: $tty" >&2; exit 1; }
test -s "$archive" || { echo "missing update archive: $archive" >&2; exit 1; }
acm_command="$(dirname -- "${BASH_SOURCE[0]}")/hikari-acm-command.py"
test -x "$acm_command" || { echo "missing ACM command helper: $acm_command" >&2; exit 1; }
if [[ $mode == usb ]]; then
	host_interface=$(ip -o link | awk '/link\/ether 02:86:60:00:00:01/ {sub(/:$/, "", $2); print $2; exit}')
	[[ -n $host_interface ]] || {
		echo 'Hikari NCM interface not found (expected MAC 02:86:60:00:00:01)' >&2
		exit 1
	}
	sudo ip link set "$host_interface" up
	sudo ip address replace 192.168.77.1/30 dev "$host_interface"
	sudo "$acm_command" --device "$tty" --no-read hikari-receive-system usb
	sleep 1
	nc -N 192.168.77.2 7777 <"$archive"
	printf 'USB transfer complete; BOOT is verifying the archive.\n'
else
	command -v sx >/dev/null || { echo 'install host package lrzsz (sx)' >&2; exit 1; }
	sudo "$acm_command" --device "$tty" --no-read hikari-receive-system xmodem
	sleep 1
	sx "$archive" <"$tty" >"$tty"
	printf 'XMODEM transfer complete; BOOT is verifying the archive.\n'
fi
