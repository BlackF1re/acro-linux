#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Install owner-supplied BCM4330 firmware and board calibration from a mounted
# stock Sony system image. These proprietary/device-specific files are never
# stored in this repository.
set -euo pipefail

usage()
{
	echo "usage: $0 STOCK_SYSTEM_ROOT TARGET_ROOT" >&2
	exit 2
}

[[ $# -eq 2 ]] || usage
stock_root=$(realpath -e -- "$1")
target_root=$(realpath -e -- "$2")
firmware_src="$stock_root/etc/firmware/fw_bcm4330b2.bin"
calibration_src="$stock_root/etc/wifi/calibration"
firmware_dir="$target_root/lib/firmware/brcm"

[[ $stock_root != "$target_root" ]] || {
	echo 'source and target roots must differ' >&2
	exit 1
}
[[ -f $firmware_src && -s $firmware_src ]] || {
	echo 'stock BCM4330 B2 firmware is missing' >&2
	exit 1
}
[[ -f $calibration_src && -s $calibration_src ]] || {
	echo 'stock Hikari Wi-Fi calibration is missing' >&2
	exit 1
}

install -d -m 0755 "$firmware_dir"
install -m 0644 "$firmware_src" "$firmware_dir/brcmfmac4330-sdio.bin"
install -m 0600 "$calibration_src" \
	"$firmware_dir/brcmfmac4330-sdio.sony,hikari.txt"

echo 'HIKARI_BCM4330_PRIVATE_FIRMWARE=PASS'
