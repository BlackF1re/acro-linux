#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Static gate for source-backed Hikari storage and PM8058 board baseline.
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

for option in \
	CONFIG_MMC=y \
	CONFIG_MMC_BLOCK=y \
	CONFIG_MMC_ARMMMCI=y \
	CONFIG_MFD_PM8XXX=y \
	CONFIG_PINCTRL_QCOM_SSBI_PMIC=y \
	CONFIG_INPUT_PMIC8XXX_PWRKEY=y \
	CONFIG_INPUT_PM8XXX_VIBRATOR=y \
	CONFIG_RTC_DRV_PM8XXX=y \
	CONFIG_QCOM_PM8XXX_XOADC=y; do
	grep -qx "$option" "$config" || { echo "missing $option" >&2; exit 1; }
done

emmc=/soc/amba-bus/mmc@12400000
sd=/soc/amba-bus/mmc@12180000
pmic=/soc/ssbi@500000/pmic
rpm=/soc/rpm@104000

[[ $(fdtget -ts "$dtb" "$emmc" status) == okay ]] || {
	echo 'Hikari eMMC/SDCC1 is not enabled' >&2; exit 1;
}
[[ $(fdtget -ts "$dtb" "$sd" status) == okay ]] || {
	echo 'Hikari microSD/SDCC3 is not enabled' >&2; exit 1;
}
[[ $(fdtget -ts "$dtb" "$pmic" compatible) == qcom,pm8058 ]] || {
	echo 'PM8058 MFD node is missing' >&2; exit 1;
}

# Exact Sony rail levels.  LVS0 is a switch and therefore has no voltage
# setting, but both eMMC rails were always-on in the downstream board data.
[[ $(fdtget -tu "$dtb" "$rpm/regulators-0/l5" regulator-min-microvolt) -eq 2850000 ]]
[[ $(fdtget -tu "$dtb" "$rpm/regulators-0/l5" regulator-max-microvolt) -eq 2850000 ]]
fdtget -p "$dtb" "$rpm/regulators-0/l5" | grep -qx regulator-always-on
fdtget -p "$dtb" "$rpm/regulators-0/lvs0" | grep -qx regulator-always-on
[[ $(fdtget -tu "$dtb" "$rpm/regulators-1/l14" regulator-min-microvolt) -eq 2850000 ]]
[[ $(fdtget -tu "$dtb" "$rpm/regulators-1/l14" regulator-max-microvolt) -eq 2850000 ]]

# PM8058 GPIO22 is represented as zero-based GPIO index 21 and is active low.
read -r _provider cd_index cd_flags <<<"$(fdtget -tu "$dtb" "$sd" cd-gpios)"
[[ $cd_index -eq 21 && $cd_flags -eq 1 ]] || {
	echo "unexpected microSD card-detect tuple: index=$cd_index flags=$cd_flags" >&2; exit 1;
}

# These children come directly from upstream pm8058.dtsi once Hikari wires
# the parent interrupt.  Keep them present so power-key, haptics and RTC do
# not silently disappear while other hardware is added.
[[ $(fdtget -ts "$dtb" "$pmic/pwrkey@1c" compatible) == qcom,pm8058-pwrkey ]]
[[ $(fdtget -ts "$dtb" "$pmic/vibrator@4a" compatible) == qcom,pm8058-vib ]]
[[ $(fdtget -ts "$dtb" "$pmic/rtc@1e8" compatible) == qcom,pm8058-rtc ]]

echo HIKARI_BOARD_HARDWARE_STATIC_GATE=PASS
