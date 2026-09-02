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
  CONFIG_USB_GADGET=y CONFIG_CONFIGFS_FS=y CONFIG_USB_CONFIGFS=y \
  CONFIG_USB_CONFIGFS_ACM=y; do
  grep -qx "$option" "$config" || {
    echo "BOOT5_USB_CONFIG=FAIL missing $option" >&2
    exit 1
  }
done

dump=$(fdtdump "$dtb")
for required in \
  'usb@12500000' 'qcom,ci-hdrc' 'dr_mode = "peripheral"' \
  'qcom,usb-hs-phy-msm8660' 'v1p8-supply' 'v3p3-supply'; do
  grep -Fq "$required" <<<"$dump" || {
    echo "BOOT5_USB_DTB=FAIL missing $required" >&2
    exit 1
  }
done
echo "BOOT5_USB_CONFIG=PASS"
echo "BOOT5_USB_DTB=PASS"
