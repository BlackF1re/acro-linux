#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
kernel_src=${KERNEL_SRC:-/home/paul/xperia/src/linux}
build_dir=${BUILD_DIR:-/home/paul/xperia/build/linux-hikari}
cross_compile=${CROSS_COMPILE:-arm-linux-gnueabihf-}
jobs=${JOBS:-"$(nproc)"}
initramfs_source=${INITRAMFS_SOURCE:-}
kernel_fragment=${KERNEL_FRAGMENT:-"$repo_root/kernel/configs/hikari-firstboot.fragment"}
require_usb_debug=${REQUIRE_USB_DEBUG:-0}

# Keep local prototype bytes reproducible across repeated builds from the same
# source and inputs. Callers may deliberately override these conventional
# kernel build identity variables.
export KBUILD_BUILD_TIMESTAMP=${KBUILD_BUILD_TIMESTAMP:-"1970-01-01 00:00:00 UTC"}
export KBUILD_BUILD_VERSION=${KBUILD_BUILD_VERSION:-1}
export KBUILD_BUILD_USER=${KBUILD_BUILD_USER:-hikari-build}
export KBUILD_BUILD_HOST=${KBUILD_BUILD_HOST:-local}

git -C "$kernel_src" rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "KERNEL_SRC must be an external Linux git worktree" >&2
  exit 1
}
test -f "$kernel_fragment" || { echo "KERNEL_FRAGMENT must name a project config fragment" >&2; exit 1; }
case "$build_dir" in /home/paul/xperia/build/*) ;; *) echo "BUILD_DIR must be below /home/paul/xperia/build" >&2; exit 1;; esac
"$repo_root/scripts/prepare-hikari-kernel-tree.sh" "$kernel_src"
make -C "$kernel_src" O="$build_dir" ARCH=arm CROSS_COMPILE="$cross_compile" qcom_defconfig
"$kernel_src/scripts/kconfig/merge_config.sh" -m -O "$build_dir" "$build_dir/.config" "$kernel_fragment"
make -C "$kernel_src" O="$build_dir" ARCH=arm CROSS_COMPILE="$cross_compile" olddefconfig
grep -qx 'CONFIG_ARCH_QCOM_RESERVE_SMEM=y' "$build_dir/.config" || {
  echo "Hikari boot build requires CONFIG_ARCH_QCOM_RESERVE_SMEM=y" >&2
  exit 1
}
grep -qx 'CONFIG_PHYS_OFFSET=0x40000000' "$build_dir/.config" || {
  echo "Hikari boot build requires the MSM8x60 physical RAM base 0x40000000" >&2
  exit 1
}
for required in CONFIG_PSTORE=y CONFIG_PSTORE_RAM=y CONFIG_PSTORE_CONSOLE=y; do
  grep -qx "$required" "$build_dir/.config" || {
    echo "Hikari boot build requires $required for persistent diagnostics" >&2
    exit 1
  }
done
if [[ "$require_usb_debug" == 1 ]]; then
  for required in CONFIG_USB_CHIPIDEA_MSM=y CONFIG_USB_CHIPIDEA_UDC=y \
    CONFIG_PHY_QCOM_USB_HS=y \
    CONFIG_USB_GADGET=y CONFIG_USB_G_SERIAL=y CONFIG_U_SERIAL_CONSOLE=y; do
    grep -qx "$required" "$build_dir/.config" || {
      echo "Hikari BOOT #5 build requires $required" >&2
      exit 1
    }
  done
  grep -qx 'CONFIG_CMDLINE="console=tty0 console=ttyGS0,115200"' "$build_dir/.config" || {
    echo 'Hikari BOOT #5.1 build requires the late ttyGS0 console cmdline' >&2
    exit 1
  }
fi
if [[ -n "$initramfs_source" ]]; then
  test -f "$initramfs_source" || { echo "INITRAMFS_SOURCE is not a regular file" >&2; exit 1; }
  "$kernel_src/scripts/config" --file "$build_dir/.config" --set-str INITRAMFS_SOURCE "$initramfs_source"
  make -C "$kernel_src" O="$build_dir" ARCH=arm CROSS_COMPILE="$cross_compile" olddefconfig
  grep -qx 'CONFIG_ARCH_QCOM_RESERVE_SMEM=y' "$build_dir/.config" || {
    echo "Hikari boot build lost CONFIG_ARCH_QCOM_RESERVE_SMEM" >&2
    exit 1
  }
  grep -qx 'CONFIG_PHYS_OFFSET=0x40000000' "$build_dir/.config" || {
    echo "Hikari boot build lost CONFIG_PHYS_OFFSET=0x40000000" >&2
    exit 1
  }
  for required in CONFIG_PSTORE=y CONFIG_PSTORE_RAM=y CONFIG_PSTORE_CONSOLE=y; do
    grep -qx "$required" "$build_dir/.config" || {
      echo "Hikari boot build lost $required" >&2
      exit 1
    }
  done
  if [[ "$require_usb_debug" == 1 ]]; then
    for required in CONFIG_USB_CHIPIDEA_MSM=y CONFIG_USB_CHIPIDEA_UDC=y \
      CONFIG_PHY_QCOM_USB_HS=y \
      CONFIG_USB_GADGET=y CONFIG_USB_G_SERIAL=y CONFIG_U_SERIAL_CONSOLE=y; do
      grep -qx "$required" "$build_dir/.config" || {
        echo "Hikari BOOT #5 build lost $required" >&2
        exit 1
      }
    done
    grep -qx 'CONFIG_CMDLINE="console=tty0 console=ttyGS0,115200"' "$build_dir/.config" || {
      echo 'Hikari BOOT #5.1 build lost the late ttyGS0 console cmdline' >&2
      exit 1
    }
  fi
fi
make -C "$kernel_src" O="$build_dir" ARCH=arm CROSS_COMPILE="$cross_compile" -j"$jobs" zImage qcom/qcom-msm8260-sony-hikari.dtb
echo "zImage: $build_dir/arch/arm/boot/zImage"
echo "DTB:    $build_dir/arch/arm/boot/dts/qcom/qcom-msm8260-sony-hikari.dtb"
