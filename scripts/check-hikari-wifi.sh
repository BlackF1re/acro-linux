#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Physical Wi-Fi gate. It intentionally emits no SSID, BSSID, MAC address or
# calibration content. A scan is PARTIAL evidence; real traffic is VERIFIED.
set -euo pipefail

scan=0
traffic_target=
while (($#)); do
	case "$1" in
	--scan) scan=1; shift ;;
	--traffic-target) traffic_target=$2; shift 2 ;;
	*) echo "usage: $0 [--scan] [--traffic-target IP_OR_NAME]" >&2; exit 2 ;;
	esac
done

sdio_function=
for candidate in /sys/bus/sdio/devices/*:0001:1; do
	[[ -f $candidate/vendor && -f $candidate/device ]] || continue
	if [[ $(cat "$candidate/vendor") == 0x02d0 && \
	      $(cat "$candidate/device") == 0x4330 ]]; then
		sdio_function=$candidate
		break
	fi
done
[[ -n $sdio_function ]]
test -d /sys/class/net/wlan0
test -d /sys/module/brcmfmac
ip link set wlan0 up

echo 'HIKARI_WIFI_SDIO=PASS vendor=Broadcom device=BCM4330'
if ((scan)); then
	scan_file=$(mktemp)
	trap 'rm -f -- "$scan_file"' EXIT
	iw dev wlan0 scan >"$scan_file"
	bss_count=$(grep -c '^BSS ' "$scan_file")
	((bss_count > 0))
	printf 'HIKARI_WIFI_SCAN=PASS bss_count=%u\n' "$bss_count"
fi
if [[ -n $traffic_target ]]; then
	ping -c 5 -W 5 "$traffic_target" >/dev/null
	echo 'HIKARI_WIFI_TRAFFIC=PASS'
fi
