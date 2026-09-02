#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Static BOOT #5 gates.  This script only inspects host build artifacts.
set -euo pipefail

usage() {
  echo "usage: $0 --config PATH --dtb PATH" >&2
  exit 2
}

config=
dtb=
while (($#)); do
  case "$1" in
    --config) config=${2:?}; shift 2 ;;
    --dtb) dtb=${2:?}; shift 2 ;;
    *) usage ;;
  esac
done

test -f "$config" && test -f "$dtb" || usage
for option in \
  CONFIG_USB=y CONFIG_USB_CHIPIDEA=y CONFIG_USB_CHIPIDEA_UDC=y \
  CONFIG_USB_CHIPIDEA_MSM=y CONFIG_PHY_QCOM_USB_HS=y \
  CONFIG_REGULATOR_QCOM_RPM=y \
  CONFIG_USB_GADGET=y CONFIG_USB_G_SERIAL=y CONFIG_U_SERIAL_CONSOLE=y \
  CONFIG_USB_U_SERIAL=y CONFIG_USB_F_ACM=y CONFIG_USB_LIBCOMPOSITE=y; do
  grep -qx "$option" "$config" || {
    echo "BOOT5_USB_CONFIG=FAIL missing $option" >&2
    exit 1
  }
done
grep -qx 'CONFIG_CMDLINE="console=tty0 console=ttyGS0,115200"' "$config" || {
  echo 'BOOT5_USB_CONFIG=FAIL missing late ttyGS0 console cmdline' >&2
  exit 1
}

dump=$(fdtdump "$dtb")
for required in \
  'usb@12500000' 'qcom,ci-hdrc' 'dr_mode = "peripheral"' \
  'qcom,usb-hs-phy-msm8660' 'v1p8-supply' 'v3p3-supply'; do
  grep -Fq "$required" <<<"$dump" || {
    echo "BOOT5_USB_DTB=FAIL missing $required" >&2
    exit 1
  }
done

get_string() {
  fdtget -t s "$dtb" "$1" "$2"
}

get_cells() {
  fdtget -t x "$dtb" "$1" "$2"
}

test "$(get_string /usb@12500000 status)" = okay || {
  echo "BOOT5_USB_DTB=FAIL controller is not enabled" >&2
  exit 1
}
test "$(get_string /usb@12500000 dr_mode)" = peripheral || {
  echo "BOOT5_USB_DTB=FAIL dr_mode is not peripheral" >&2
  exit 1
}
test "$(get_cells /usb@12500000 interrupts)" = '0 64 4' || {
  echo "BOOT5_USB_DTB=FAIL controller IRQ is not GIC_SPI 100" >&2
  exit 1
}
for prohibited in extcon usb-role-switch; do
  if fdtget "$dtb" /usb@12500000 "$prohibited" >/dev/null 2>&1; then
    echo "BOOT5_USB_DTB=FAIL unexpected $prohibited dependency" >&2
    exit 1
  fi
done

# DTC rejects dangling labels while compiling this DTB.  These direct reads
# additionally gate every reference that the ChipIdea controller and its PHY
# need for the first peripheral-mode attempt.
for ref in \
  '/usb@12500000:phys' \
  '/usb@12500000:clocks' \
  '/usb@12500000:resets' \
  '/usb@12500000/ulpi/phy:clocks' \
  '/usb@12500000/ulpi/phy:resets' \
  '/usb@12500000/ulpi/phy:v1p8-supply' \
  '/usb@12500000/ulpi/phy:v3p3-supply'; do
  node=${ref%%:*}
  property=${ref#*:}
  values=$(get_cells "$node" "$property") || {
    echo "BOOT5_USB_DTB=FAIL unreadable $node/$property" >&2
    exit 1
  }
  test -n "$values" || {
    echo "BOOT5_USB_DTB=FAIL empty $node/$property" >&2
    exit 1
  }
done
echo "BOOT5_USB_CONFIG=PASS"
echo "BOOT5_USB_DTB=PASS"
