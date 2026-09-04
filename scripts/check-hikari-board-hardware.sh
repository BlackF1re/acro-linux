#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Static gate for source-backed Hikari board hardware.
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
	CONFIG_QCOM_PM8XXX_XOADC=y \
	CONFIG_RMI4_CORE=y \
	CONFIG_RMI4_I2C=y \
	CONFIG_RMI4_F11=y \
	CONFIG_MPU3050_I2C=y \
	CONFIG_BMA180=y; do
	grep -qx "$option" "$config" || { echo "missing $option" >&2; exit 1; }
done

emmc=/soc/amba-bus/mmc@12400000
sd=/soc/amba-bus/mmc@12180000
pmic=/soc/ssbi@500000/pmic
rpm=/soc/rpm@104000
touch=/soc/gsbi@16200000/i2c@16280000/touchscreen@2c
gyro=/soc/gsbi@19c00000/i2c@19c80000/gyroscope@68
accel="$gyro/i2c-gate/accelerometer@18"

[[ $(fdtget -ts "$dtb" "$emmc" status) == okay ]]
[[ $(fdtget -ts "$dtb" "$sd" status) == okay ]]
[[ $(fdtget -ts "$dtb" "$pmic" compatible) == qcom,pm8058 ]]

[[ $(fdtget -tu "$dtb" "$rpm/regulators-0/l5" regulator-min-microvolt) -eq 2850000 ]]
[[ $(fdtget -tu "$dtb" "$rpm/regulators-0/l5" regulator-max-microvolt) -eq 2850000 ]]
fdtget -p "$dtb" "$rpm/regulators-0/l5" | grep -qx regulator-always-on
fdtget -p "$dtb" "$rpm/regulators-0/lvs0" | grep -qx regulator-always-on
[[ $(fdtget -tu "$dtb" "$rpm/regulators-1/l14" regulator-min-microvolt) -eq 2850000 ]]
[[ $(fdtget -tu "$dtb" "$rpm/regulators-1/l14" regulator-max-microvolt) -eq 2850000 ]]

read -r _provider cd_index cd_flags <<<"$(fdtget -tu "$dtb" "$sd" cd-gpios)"
[[ $cd_index -eq 21 && $cd_flags -eq 1 ]] || {
	echo "unexpected microSD card-detect tuple: index=$cd_index flags=$cd_flags" >&2; exit 1;
}

[[ $(fdtget -ts "$dtb" "$pmic/pwrkey@1c" compatible) == qcom,pm8058-pwrkey ]]
[[ $(fdtget -ts "$dtb" "$pmic/vibrator@4a" compatible) == qcom,pm8058-vib ]]
[[ $(fdtget -ts "$dtb" "$pmic/rtc@1e8" compatible) == qcom,pm8058-rtc ]]

[[ $(fdtget -ts "$dtb" "$touch" compatible) == syna,rmi4-i2c ]]
[[ $(fdtget -tu "$dtb" "$touch" reg) -eq 44 ]]
[[ $(fdtget -tu "$dtb" "$rpm/regulators-0/l1" regulator-min-microvolt) -eq 3050000 ]]
[[ $(fdtget -tu "$dtb" "$rpm/regulators-0/l1" regulator-max-microvolt) -eq 3050000 ]]
[[ $(fdtget -tu "$dtb" "$touch/rmi4-f11@11" syna,clip-x-high) -eq 719 ]]
[[ $(fdtget -tu "$dtb" "$touch/rmi4-f11@11" syna,clip-y-high) -eq 1279 ]]
grep -qx '# CONFIG_RMI4_F34 is not set' "$config"

# Sony powers the shared sensor domain at board init: 1.8 V I/O and 2.85 V VDD.
[[ $(fdtget -tu "$dtb" "$rpm/regulators-1/l8" regulator-min-microvolt) -eq 1800000 ]]
[[ $(fdtget -tu "$dtb" "$rpm/regulators-1/l10" regulator-min-microvolt) -eq 2850000 ]]
fdtget -p "$dtb" "$rpm/regulators-1/l8" | grep -qx regulator-always-on
fdtget -p "$dtb" "$rpm/regulators-1/l10" | grep -qx regulator-always-on

[[ $(fdtget -ts "$dtb" "$gyro" compatible) == invensense,mpu3050 ]]
[[ $(fdtget -tu "$dtb" "$gyro" reg) -eq 104 ]]
[[ $(fdtget -ts "$dtb" "$accel" compatible) == bosch,bma250 ]]
[[ $(fdtget -tu "$dtb" "$accel" reg) -eq 24 ]]
[[ $(fdtget -ts "$dtb" "$gyro" mount-matrix) == '0 1 0 1 0 0 0 0 -1' ]]
[[ $(fdtget -ts "$dtb" "$accel" mount-matrix) == '1 0 0 0 -1 0 0 0 -1' ]]

echo HIKARI_BOARD_HARDWARE_STATIC_GATE=PASS
