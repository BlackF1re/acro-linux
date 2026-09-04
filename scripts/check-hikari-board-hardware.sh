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
	CONFIG_PWRSEQ_SIMPLE=y \
	CONFIG_MFD_PM8XXX=y \
	CONFIG_PINCTRL_QCOM_SSBI_PMIC=y \
	CONFIG_INPUT_PMIC8XXX_PWRKEY=y \
	CONFIG_INPUT_PM8XXX_VIBRATOR=y \
	CONFIG_KEYBOARD_PMIC8XXX=y \
	CONFIG_KEYBOARD_GPIO=y \
	CONFIG_RTC_DRV_PM8XXX=y \
	CONFIG_QCOM_PM8XXX_XOADC=y \
	CONFIG_NFC=y \
	CONFIG_NFC_HCI=y \
	CONFIG_NFC_SHDLC=y \
	CONFIG_NFC_PN544_I2C=y \
	CONFIG_CFG80211=y \
	CONFIG_BRCMFMAC=y \
	CONFIG_BRCMFMAC_SDIO=y \
	CONFIG_BT=y \
	CONFIG_BT_HCIUART=y \
	CONFIG_BT_HCIUART_SERDEV=y \
	CONFIG_BT_HCIUART_BCM=y \
	CONFIG_BT_HCIUART_H4=y \
	CONFIG_RMI4_CORE=y \
	CONFIG_RMI4_I2C=y \
	CONFIG_RMI4_F11=y \
	CONFIG_MPU3050_I2C=y \
	CONFIG_BMA180=y; do
	grep -qx "$option" "$config" || { echo "missing $option" >&2; exit 1; }
done

emmc=/soc/amba-bus/mmc@12400000
sd=/soc/amba-bus/mmc@12180000
wifi_host=/soc/amba-bus/mmc@121c0000
wifi="$wifi_host/wifi@1"
wifi_pwrseq=/wifi-pwrseq
bt_gsbi=/soc/gsbi@16500000
bt_uart="$bt_gsbi/serial@16540000"
bt="$bt_uart/bluetooth"
pmic=/soc/ssbi@500000/pmic
rpm=/soc/rpm@104000
touch=/soc/gsbi@16200000/i2c@16280000/touchscreen@2c
nfc=/soc/gsbi@19800000/i2c@19880000/nfc@28
gsbi12=/soc/gsbi@19c00000
gyro="$gsbi12/i2c@19c80000/gyroscope@68"
accel="$gyro/i2c-gate/accelerometer@18"
keypad="$pmic/keypad@148"
gpio_keys=/gpio-keys

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

# Exact Hikari key topology: two-stage camera matrix plus discrete volume keys.
[[ $(fdtget -tu "$dtb" "$keypad" keypad,num-rows) -eq 5 ]]
[[ $(fdtget -tu "$dtb" "$keypad" keypad,num-columns) -eq 5 ]]
[[ $(fdtget -tu "$dtb" "$keypad" debounce) -eq 15 ]]
[[ $(fdtget -tu "$dtb" "$keypad" scan-delay) -eq 2 ]]
[[ $(fdtget -tu "$dtb" "$keypad" row-hold) -eq 122000 ]]
fdtget -p "$dtb" "$keypad" | grep -qx wakeup-source
[[ $(fdtget -ts "$dtb" "$gpio_keys" compatible) == gpio-keys ]]
read -r _provider vu_index vu_flags <<<"$(fdtget -tu "$dtb" "$gpio_keys/volume-up-key" gpios)"
read -r _provider vd_index vd_flags <<<"$(fdtget -tu "$dtb" "$gpio_keys/volume-down-key" gpios)"
read -r _provider sim_index sim_flags <<<"$(fdtget -tu "$dtb" "$gpio_keys/sim-detect-switch" gpios)"
[[ $vu_index -eq 25 && $vu_flags -eq 1 ]]
[[ $vd_index -eq 73 && $vd_flags -eq 0 ]]
[[ $sim_index -eq 94 && $sim_flags -eq 0 ]]
[[ $(fdtget -tu "$dtb" "$gpio_keys/volume-up-key" linux,code) -eq 115 ]]
[[ $(fdtget -tu "$dtb" "$gpio_keys/volume-down-key" linux,code) -eq 114 ]]
[[ $(fdtget -tu "$dtb" "$gpio_keys/sim-detect-switch" linux,input-type) -eq 5 ]]
[[ $(fdtget -tu "$dtb" "$gpio_keys/sim-detect-switch" linux,code) -eq 7 ]]

# Exact Hikari PN544: GSBI8/0x28, PM8058 GPIO28 IRQ, GPIO17 VEN, GPIO27 FWDL.
[[ $(fdtget -ts "$dtb" "$nfc" compatible) == nxp,pn544-i2c ]]
[[ $(fdtget -tu "$dtb" "$nfc" reg) -eq 40 ]]
read -r _provider irq_index irq_flags <<<"$(fdtget -tu "$dtb" "$nfc" interrupts-extended)"
read -r _provider en_index en_flags <<<"$(fdtget -tu "$dtb" "$nfc" enable-gpios)"
read -r _provider fw_index fw_flags <<<"$(fdtget -tu "$dtb" "$nfc" firmware-gpios)"
[[ $irq_index -eq 27 && $irq_flags -eq 1 ]]
[[ $en_index -eq 16 && $en_flags -eq 0 ]]
[[ $fw_index -eq 26 && $fw_flags -eq 0 ]]

# BCM4330 WLAN: SDCC4 four-bit/48 MHz, PM8058 S3 1.8 V, reset 130, host-wake 128.
[[ $(fdtget -ts "$dtb" "$wifi_host" status) == okay ]]
[[ $(fdtget -tu "$dtb" "$wifi_host" bus-width) -eq 4 ]]
[[ $(fdtget -tu "$dtb" "$wifi_host" max-frequency) -eq 48000000 ]]
fdtget -p "$dtb" "$wifi_host" | grep -qx non-removable
fdtget -p "$dtb" "$wifi_host" | grep -qx cap-sdio-irq
[[ $(fdtget -tu "$dtb" "$rpm/regulators-1/s3" regulator-min-microvolt) -eq 1800000 ]]
[[ $(fdtget -tu "$dtb" "$rpm/regulators-1/s3" regulator-max-microvolt) -eq 1800000 ]]
[[ $(fdtget -ts "$dtb" "$wifi_pwrseq" compatible) == mmc-pwrseq-simple ]]
read -r _provider wifi_reset_index wifi_reset_flags <<<"$(fdtget -tu "$dtb" "$wifi_pwrseq" reset-gpios)"
[[ $wifi_reset_index -eq 130 && $wifi_reset_flags -eq 1 ]]
[[ $(fdtget -ts "$dtb" "$wifi" compatible) == 'brcm,bcm4330-fmac brcm,bcm4329-fmac' ]]
[[ $(fdtget -tu "$dtb" "$wifi" reg) -eq 1 ]]
[[ $(fdtget -ts "$dtb" "$wifi" interrupt-names) == host-wake ]]
read -r wifi_irq_parent wifi_irq_index wifi_irq_flags <<<"$(fdtget -tu "$dtb" "$wifi" interrupts-extended 2>/dev/null || true)"
if [[ -n ${wifi_irq_index:-} ]]; then
	[[ $wifi_irq_index -eq 128 && $wifi_irq_flags -eq 4 ]]
else
	read -r wifi_irq_index wifi_irq_flags <<<"$(fdtget -tu "$dtb" "$wifi" interrupts)"
	[[ $wifi_irq_index -eq 128 && $wifi_irq_flags -eq 4 ]]
fi

# BCM4330 Bluetooth: GSBI6 UARTDM + hci_bcm serdev and exact Sony control GPIOs.
[[ $(fdtget -tu "$dtb" "$bt_gsbi" qcom,mode) -eq 4 ]]
[[ $(fdtget -ts "$dtb" "$bt_gsbi" status) == okay ]]
[[ $(fdtget -ts "$dtb" "$bt_uart" status) == okay ]]
fdtget -p "$dtb" "$bt_uart" | grep -qx uart-has-rtscts
[[ $(fdtget -ts "$dtb" "$bt" compatible) == brcm,bcm4330-bt ]]
read -r _provider bt_reset_index bt_reset_flags <<<"$(fdtget -tu "$dtb" "$bt" shutdown-gpios)"
read -r _provider bt_wake_index bt_wake_flags <<<"$(fdtget -tu "$dtb" "$bt" device-wakeup-gpios)"
read -r _provider bt_host_index bt_host_flags <<<"$(fdtget -tu "$dtb" "$bt" host-wakeup-gpios)"
[[ $bt_reset_index -eq 23 && $bt_reset_flags -eq 0 ]]
[[ $bt_wake_index -eq 137 && $bt_wake_flags -eq 0 ]]
[[ $bt_host_index -eq 63 && $bt_host_flags -eq 0 ]]

[[ $(fdtget -ts "$dtb" "$touch" compatible) == syna,rmi4-i2c ]]
[[ $(fdtget -tu "$dtb" "$touch" reg) -eq 44 ]]
[[ $(fdtget -tu "$dtb" "$rpm/regulators-0/l1" regulator-min-microvolt) -eq 3050000 ]]
[[ $(fdtget -tu "$dtb" "$rpm/regulators-0/l1" regulator-max-microvolt) -eq 3050000 ]]
[[ $(fdtget -tu "$dtb" "$touch/rmi4-f11@11" syna,clip-x-high) -eq 719 ]]
[[ $(fdtget -tu "$dtb" "$touch/rmi4-f11@11" syna,clip-y-high) -eq 1279 ]]
grep -qx '# CONFIG_RMI4_F34 is not set' "$config"

# Sony puts MPU3050/BMA250 on GSBI12 QUP I2C.  qcom_gsbi requires qcom,mode;
# without it the parent probe returns -EINVAL before the sensor bus can work.
[[ $(fdtget -tu "$dtb" "$gsbi12" qcom,mode) -eq 2 ]]
[[ $(fdtget -ts "$dtb" "$gsbi12" status) == okay ]]

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
