#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Inject the per-device factory Bluetooth address into a built DTB.  The
# identifier remains outside Git; the upstream hci_bcm driver consumes the
# standard local-bd-address property before registering the controller.
set -euo pipefail

[[ $# -eq 2 ]] || {
	echo "usage: $0 DTB BLUETOOTH_ADDRESS_FILE" >&2
	exit 2
}

dtb=$1
address_file=$2
node=/soc/gsbi@16500000/serial@16540000/bluetooth

test -s "$dtb"
test -s "$address_file"
command -v fdtput >/dev/null

address=$(tr -d '\r\n' <"$address_file")
[[ $address =~ ^([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}$ ]] || {
	echo 'invalid Bluetooth address file' >&2
	exit 1
}
address=${address^^}
[[ $address != 00:00:00:00:00:00 && $address != 43:30:B1:00:00:00 ]] || {
	echo 'refusing a non-unique Bluetooth address' >&2
	exit 1
}

IFS=: read -r b0 b1 b2 b3 b4 b5 <<<"$address"
(( (16#$b0 & 1) == 0 )) || {
	echo 'refusing a multicast Bluetooth address' >&2
	exit 1
}

# bluetooth-controller.yaml defines local-bd-address in little-endian order.
fdtput -t bx "$dtb" "$node" local-bd-address \
	"0x$b5" "0x$b4" "0x$b3" "0x$b2" "0x$b1" "0x$b0"
[[ $(fdtget -t bx "$dtb" "$node" local-bd-address | wc -w) -eq 6 ]]
echo 'HIKARI_DTB_BLUETOOTH_IDENTITY=PASS'
