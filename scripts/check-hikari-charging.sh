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
kernel_tree=${KERNEL_TREE:-}
for option in CONFIG_POWER_SUPPLY=y CONFIG_BATTERY_BQ27XXX=y \
	CONFIG_BATTERY_BQ27XXX_I2C=y CONFIG_CHARGER_BQ24160=y CONFIG_I2C_QUP=y \
	CONFIG_PINCTRL_QCOM_SSBI_PMIC=y CONFIG_REGULATOR_FIXED_VOLTAGE=y; do
	grep -qx "$option" "$config" || { echo "missing $option" >&2; exit 1; }
done
grep -qx '# CONFIG_BATTERY_BQ27XXX_DT_UPDATES_NVM is not set' "$config" || {
	echo 'BQ27xxx NVM updates must stay disabled' >&2; exit 1;
}
dt=$(mktemp)
trap 'rm -f "$dt"' EXIT
dtc -I dtb -O dts "$dtb" >"$dt"
for required in 'fuel-gauge@55' 'charger@6b' 'backlight@40' 'ti,bq27520g1' 'ti,bq24160' \
	'usb-otg-guard' 'regulator-ext-5v' 'regulator-usb-otg-vbus' \
	'qcom,pm8901' 'qcom,pm8901-mpp' \
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
# Sony's VBUS chain is represented as three dependent regulators.  Exact
# phandle values are build-dependent, so gate the source pins through the
# compiled properties instead of comparing generated phandle numbers.
test "$(fdtget -t x "$dtb" /regulator-usb-otg-vbus gpio | awk '{print $(NF-1), $NF}')" = '1c 0' || {
	echo 'DTB lacks NCP373 GPIO28 active-high enable' >&2; exit 1;
}
test "$(fdtget -t x "$dtb" /regulator-ext-5v gpio | awk '{print $(NF-1), $NF}')" = '1 0' || {
	echo 'DTB lacks PM8901 MPP1 active-high ext-5V enable' >&2; exit 1;
}
test "$(fdtget -t x "$dtb" /connector id-gpios | awk '{print $(NF-1), $NF}')" = '1f 0' || {
	echo 'DTB lacks physical PM8058 GPIO31 USB ID (Sony index 30)' >&2; exit 1;
}
test "$(fdtget -t x "$dtb" /connector vbus-gpios | awk '{print $(NF-1), $NF}')" = 'b 1' || {
	echo 'DTB lacks physical PM8058 MPP11 active-low VBUS detection (Sony index 10)' >&2; exit 1;
}
test "$(fdtget -t x "$dtb" /regulator-usb-otg-vbus interrupts)" = '68 2' || {
	echo 'DTB lacks NCP373 GPIO104 falling-edge fault IRQ' >&2; exit 1;
}
fdtget -t x "$dtb" /regulator-ext-5v vin-supply >/dev/null || {
	echo 'DTB lacks BQ24160-to-ext-5V dependency' >&2; exit 1;
}
fdtget -t x "$dtb" /regulator-usb-otg-vbus vin-supply >/dev/null || {
	echo 'DTB lacks ext-5V-to-NCP373 dependency' >&2; exit 1;
}
if [[ -n "$kernel_tree" ]]; then
	mpp_driver="$kernel_tree/drivers/pinctrl/qcom/pinctrl-ssbi-mpp.c"
	test -f "$mpp_driver" || { echo "missing materialized SSBI MPP driver: $mpp_driver" >&2; exit 1; }
	python3 - "$mpp_driver" <<'PY'
from pathlib import Path
import re
import sys

text = Path(sys.argv[1]).read_text()
direction = re.search(
    r"static int pm8xxx_mpp_direction_output\(.*?\n}\n",
    text,
    re.S,
)
if not direction:
    raise SystemExit("SSBI MPP direction-output callback not found")
body = direction.group(0)
for required in ("pin->input = false;", "pin->output_value = !!value;"):
    if required not in body:
        raise SystemExit(f"SSBI MPP output-state fix missing: {required}")
for required in (
    "#define SSBI_REG_ADDR_PM8901_MPP_BASE\t0x27",
    'of_device_is_compatible(pdev->dev.of_node, "qcom,pm8901-mpp")',
):
    if required not in text:
        raise SystemExit(f"SSBI MPP PM8901 register-base fix missing: {required}")
PY
fi
echo HIKARI_CHARGING_STATIC_GATE=PASS
