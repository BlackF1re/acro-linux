#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Fail closed in CI if a new peripheral can accidentally remove the physically
# verified BOOT #5.1 recovery path.  This is an offline/static gate only.
set -euo pipefail

usage() {
  echo "usage: $0 --kernel-src PATH --config PATH --dtb PATH" >&2
  exit 2
}

kernel_src=
config=
dtb=
while (($#)); do
  case "$1" in
    --kernel-src) kernel_src=${2:?}; shift 2 ;;
    --config) config=${2:?}; shift 2 ;;
    --dtb) dtb=${2:?}; shift 2 ;;
    *) usage ;;
  esac
done

[[ -d $kernel_src && -f $config && -f $dtb ]] || usage
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
init="$repo_root/initramfs/hikari-firstboot/init"
[[ -f $init ]] || { echo "missing diagnostic PID1: $init" >&2; exit 1; }

# The recovery console must remain completely built-in.  Modules are too late
# to diagnose early probe failures and cannot help if storage is unavailable.
for option in \
  CONFIG_PRINTK=y \
  CONFIG_DEVTMPFS=y CONFIG_DEVTMPFS_MOUNT=y \
  CONFIG_PROC_FS=y CONFIG_SYSFS=y CONFIG_TMPFS=y \
  CONFIG_BLK_DEV_INITRD=y \
  CONFIG_PSTORE=y CONFIG_PSTORE_RAM=y CONFIG_PSTORE_CONSOLE=y \
  CONFIG_USB=y CONFIG_USB_GADGET=y \
  CONFIG_USB_CHIPIDEA=y CONFIG_USB_CHIPIDEA_UDC=y \
  CONFIG_USB_CHIPIDEA_MSM=y CONFIG_PHY_QCOM_USB_HS=y \
  CONFIG_USB_G_SERIAL=y CONFIG_U_SERIAL_CONSOLE=y \
  CONFIG_USB_U_SERIAL=y CONFIG_USB_F_ACM=y CONFIG_USB_LIBCOMPOSITE=y; do
  grep -qx "$option" "$config" || {
    echo "HIKARI_DIAG_SURVIVAL=FAIL missing built-in $option" >&2
    exit 1
  }
done

# Recoverable bring-up faults should be logged, not deliberately escalated to
# panic.  The detectors remain useful because they emit diagnostics to both
# ttyGS0 and ramoops while their panic actions stay disabled.
grep -qx '# CONFIG_PANIC_ON_OOPS is not set' "$config" || {
  echo 'HIKARI_DIAG_SURVIVAL=FAIL panic-on-oops must remain disabled' >&2
  exit 1
}
for option in \
  CONFIG_PANIC_TIMEOUT=0 \
  CONFIG_DETECT_HUNG_TASK=y CONFIG_BOOTPARAM_HUNG_TASK_PANIC=0 \
  CONFIG_SOFTLOCKUP_DETECTOR=y CONFIG_BOOTPARAM_SOFTLOCKUP_PANIC=0; do
  grep -qx "$option" "$config" || {
    echo "HIKARI_DIAG_SURVIVAL=FAIL missing non-fatal diagnostic policy $option" >&2
    exit 1
  }
done

# Keep the known-good console first-class and keep risky display probes off the
# synchronous initcall path.  Additional drivers may fail or defer without
# becoming a prerequisite for ttyGS0.
grep -Eq '^CONFIG_CMDLINE=".*console=tty0 .*console=ttyGS0,115200 .*driver_async_probe=mdp4,msm_dsi.*"$' "$config" || {
  echo 'HIKARI_DIAG_SURVIVAL=FAIL ttyGS0/async display cmdline invariant lost' >&2
  exit 1
}

# PID1 must never be the interactive shell.  Failed mounts and a missing USB
# cable are intentionally non-fatal; the console supervisor is a child and the
# independent ALIVE loop keeps init present forever.
if grep -Eq '^[[:space:]]*set[[:space:]]+-e([[:space:]]|$)' "$init"; then
  echo 'HIKARI_DIAG_SURVIVAL=FAIL PID1 must not exit on an optional command failure' >&2
  exit 1
fi
for marker in \
  'console_supervisor()' \
  'console_supervisor &' \
  '/bin/sh -i </dev/ttyGS0 >/dev/ttyGS0 2>&1' \
  'HIKARI SHELL EXIT rc=$?' \
  'HIKARI ALIVE uptime=$1'; do
  grep -Fq "$marker" "$init" || {
    echo "HIKARI_DIAG_SURVIVAL=FAIL PID1 invariant missing: $marker" >&2
    exit 1
  }
done
[[ $(grep -Fc 'while :; do' "$init") -ge 2 ]] || {
  echo 'HIKARI_DIAG_SURVIVAL=FAIL shell supervisor and PID1 liveness loops are both required' >&2
  exit 1
}
if grep -Eq '^[[:space:]]*exec[[:space:]].*(ttyGS0|/bin/sh)' "$init"; then
  echo 'HIKARI_DIAG_SURVIVAL=FAIL PID1 must not exec the USB shell' >&2
  exit 1
fi

# Reuse the physically verified BOOT #5 USB/DT checks and the TWRP-compatible
# persistent-console checks instead of duplicating their hardware constants.
"$repo_root/scripts/check-hikari-boot5-interactive.sh" --config "$config" --dtb "$dtb"
"$repo_root/scripts/check-hikari-persistent-ram.sh" --config "$config" --dtb "$dtb"
python3 "$repo_root/tools/check_hikari_kernel_guards.py" --kernel-src "$kernel_src"

echo 'HIKARI_DIAG_SURVIVAL=PASS'
echo 'usb=ttyGS0 built-in peripheral-mode; pid1=independent supervisor; panic-escalation=off; ramoops=retained'
