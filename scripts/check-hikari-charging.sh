#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Static gate for the deliberately conservative native Hikari charging path.
set -euo pipefail

usage() { echo "usage: $0 --config FILE --dtb FILE" >&2; exit 2; }
config= dtb=
while (($#)); do
	case "$1" in
	--config) config=$2; shift 2;;
	--dtb) dtb=$2; shift 2;;
	*) usage;;
	esac
done
test -f "$config" && test -f "$dtb" || usage
for option in CONFIG_POWER_SUPPLY=y CONFIG_BATTERY_BQ27XXX=y \
	CONFIG_BATTERY_BQ27XXX_I2C=y CONFIG_CHARGER_BQ24160=y CONFIG_I2C_QUP=y; do
	grep -qx "$option" "$config" || { echo "missing $option" >&2; exit 1; }
done
grep -qx '# CONFIG_BATTERY_BQ27XXX_DT_UPDATES_NVM is not set' "$config" || {
	echo 'BQ27xxx NVM updates must stay disabled' >&2; exit 1;
}
dt=$(mktemp)
trap 'rm -f "$dt"' EXIT
dtc -I dtb -O dts "$dtb" >"$dt"
for required in 'fuel-gauge@55' 'charger@6b' 'backlight@40' 'ti,bq27520g1' 'ti,bq24160' \
	'charge-full-design-microamp-hours = <0x1cfde0>' \
	'ti,usb-input-current-limit-microamp = <0x7a120>' \
	'ti,constant-charge-current-max-microamp = <0x174508>' \
	'ti,constant-charge-voltage-max-microvolt = <0x401640>'; do
	grep -Fq "$required" "$dt" || { echo "DTB lacks $required" >&2; exit 1; }
done
# Exact Fuji wiring has one I2C address per device; do not create a second GSBI8 node.
test "$(grep -c 'reg = <0x40>;' "$dt")" -eq 1
test "$(grep -c 'reg = <0x55>;' "$dt")" -eq 1
test "$(grep -c 'reg = <0x6b>;' "$dt")" -eq 1
# Fuji assigns the three functions to separate TLMM lines; changing one into
# a duplicate would make the I2C/charger interrupt topology unsafe.
grep -Fq 'interrupts = <0x7d 0x03>;' "$dt" || {
	echo 'DTB lacks BQ24160 GPIO125 edge-both IRQ' >&2; exit 1;
}
echo HIKARI_CHARGING_STATIC_GATE=PASS
