#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
hikari_build_root=${HIKARI_BUILD_ROOT:-/home/paul/xperia/build}
kernel_src=${KERNEL_SRC:-/home/paul/xperia/src/linux}
build_dir=${BUILD_DIR:-"$hikari_build_root/linux-hikari-current"}
cross_compile=${CROSS_COMPILE:-arm-linux-gnueabihf-}
jobs=${JOBS:-"$(nproc)"}
targets=${TARGETS:-"zImage qcom/qcom-msm8260-sony-hikari.dtb qcom/qcom-msm8260-sony-hikari-gpu.dtb qcom/qcom-msm8260-sony-hikari-safe.dtb"}
initramfs_source=${INITRAMFS_SOURCE:-}
kernel_fragment=${KERNEL_FRAGMENT:-"$repo_root/kernel/configs/hikari-boot6-display.fragment"}
require_usb_debug=${REQUIRE_USB_DEBUG:-0}
require_display_bringup=${REQUIRE_DISPLAY_BRINGUP:-0}
require_charging=${REQUIRE_CHARGING:-0}

export KBUILD_BUILD_TIMESTAMP=${KBUILD_BUILD_TIMESTAMP:-"1970-01-01 00:00:00 UTC"}
export KBUILD_BUILD_VERSION=${KBUILD_BUILD_VERSION:-1}
export KBUILD_BUILD_USER=${KBUILD_BUILD_USER:-hikari-build}
export KBUILD_BUILD_HOST=${KBUILD_BUILD_HOST:-local}

git -C "$kernel_src" rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "KERNEL_SRC must be an external Linux git worktree" >&2
  exit 1
}
test -f "$kernel_fragment" || { echo "KERNEL_FRAGMENT must name a project config fragment" >&2; exit 1; }
mkdir -p "$hikari_build_root"
hikari_build_root=$(realpath -m -- "$hikari_build_root")
build_dir=$(realpath -m -- "$build_dir")
case "$build_dir" in "$hikari_build_root"/*) ;; *) echo "BUILD_DIR must be below HIKARI_BUILD_ROOT=$hikari_build_root" >&2; exit 1;; esac
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
  grep -Eq '^CONFIG_CMDLINE=".*console=tty0 .*console=ttyGS0,115200([ "].*)$' "$build_dir/.config" || {
    echo 'Hikari BOOT #5.1 build requires the late ttyGS0 console cmdline' >&2
    exit 1
  }
fi
if [[ "$require_display_bringup" == 1 ]]; then
  for required in \
    CONFIG_MSM_MMCC_8660=y CONFIG_INTERCONNECT_QCOM_MSM8660=y \
    CONFIG_DRM=y CONFIG_DRM_MSM=y CONFIG_DRM_MSM_MDP4=y CONFIG_DRM_MSM_DSI=y \
    CONFIG_DRM_MSM_DSI_45NM_PHY=y CONFIG_MSM_IOMMU=y \
    CONFIG_DRM_PANEL_RENESAS_R63306_TMD_MDV22=y \
    CONFIG_DRM_FBDEV_EMULATION=y CONFIG_FRAMEBUFFER_CONSOLE=y \
    CONFIG_BACKLIGHT_AS3676=y CONFIG_I2C_QUP=y; do
    grep -qx "$required" "$build_dir/.config" || {
      echo "Hikari BOOT #6 build requires $required" >&2
      exit 1
    }
  done
fi
if [[ "$require_charging" == 1 ]]; then
  for required in CONFIG_POWER_SUPPLY=y CONFIG_BATTERY_BQ27XXX=y \
    CONFIG_BATTERY_BQ27XXX_I2C=y CONFIG_CHARGER_BQ24160=y CONFIG_I2C_QUP=y; do
    grep -qx "$required" "$build_dir/.config" || {
      echo "Hikari charging build requires $required" >&2
      exit 1
    }
  done
  grep -qx '# CONFIG_BATTERY_BQ27XXX_DT_UPDATES_NVM is not set' "$build_dir/.config" || {
    echo 'Hikari charging build must not enable BQ27xxx NVM updates' >&2
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
    grep -Eq '^CONFIG_CMDLINE=".*console=tty0 .*console=ttyGS0,115200([ "].*)$' "$build_dir/.config" || {
      echo 'Hikari BOOT #5.1 build lost the late ttyGS0 console cmdline' >&2
      exit 1
    }
  fi
  if [[ "$require_display_bringup" == 1 ]]; then
    for required in \
      CONFIG_MSM_MMCC_8660=y CONFIG_INTERCONNECT_QCOM_MSM8660=y \
      CONFIG_DRM=y CONFIG_DRM_MSM=y CONFIG_DRM_MSM_MDP4=y CONFIG_DRM_MSM_DSI=y \
      CONFIG_DRM_MSM_DSI_45NM_PHY=y CONFIG_MSM_IOMMU=y \
      CONFIG_DRM_PANEL_RENESAS_R63306_TMD_MDV22=y \
      CONFIG_DRM_FBDEV_EMULATION=y CONFIG_FRAMEBUFFER_CONSOLE=y \
      CONFIG_BACKLIGHT_AS3676=y CONFIG_I2C_QUP=y; do
      grep -qx "$required" "$build_dir/.config" || {
        echo "Hikari BOOT #6 build lost $required" >&2
        exit 1
      }
    done
  fi
  if [[ "$require_charging" == 1 ]]; then
    for required in CONFIG_POWER_SUPPLY=y CONFIG_BATTERY_BQ27XXX=y \
      CONFIG_BATTERY_BQ27XXX_I2C=y CONFIG_CHARGER_BQ24160=y CONFIG_I2C_QUP=y; do
      grep -qx "$required" "$build_dir/.config" || {
        echo "Hikari charging build lost $required" >&2
        exit 1
      }
    done
    grep -qx '# CONFIG_BATTERY_BQ27XXX_DT_UPDATES_NVM is not set' "$build_dir/.config" || {
      echo 'Hikari charging build enabled BQ27xxx NVM updates' >&2
      exit 1
    }
  fi
fi

read -r -a build_targets <<<"$targets"
make -C "$kernel_src" O="$build_dir" ARCH=arm CROSS_COMPILE="$cross_compile" \
  -j"$jobs" "${build_targets[@]}"
if [[ " $targets " == *" zImage "* ]]; then
  echo "zImage: $build_dir/arch/arm/boot/zImage"
fi
for dtb_name in qcom-msm8260-sony-hikari.dtb qcom-msm8260-sony-hikari-gpu.dtb qcom-msm8260-sony-hikari-safe.dtb; do
  if [[ " $targets " == *" qcom/$dtb_name "* ]]; then
    echo "DTB:    $build_dir/arch/arm/boot/dts/qcom/$dtb_name"
  fi
done
