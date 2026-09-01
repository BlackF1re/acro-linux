#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
kernel_src=${KERNEL_SRC:-/home/paul/xperia/src/linux}
build_dir=${BUILD_DIR:-/home/paul/xperia/build/linux-hikari}
cross_compile=${CROSS_COMPILE:-arm-linux-gnueabihf-}
jobs=${JOBS:-"$(nproc)"}
initramfs_source=${INITRAMFS_SOURCE:-}

# Keep local prototype bytes reproducible across repeated builds from the same
# source and inputs. Callers may deliberately override these conventional
# kernel build identity variables.
export KBUILD_BUILD_TIMESTAMP=${KBUILD_BUILD_TIMESTAMP:-"1970-01-01 00:00:00 UTC"}
export KBUILD_BUILD_VERSION=${KBUILD_BUILD_VERSION:-1}
export KBUILD_BUILD_USER=${KBUILD_BUILD_USER:-hikari-build}
export KBUILD_BUILD_HOST=${KBUILD_BUILD_HOST:-local}

test -d "$kernel_src/.git" || { echo "KERNEL_SRC must be an external Linux git tree" >&2; exit 1; }
case "$build_dir" in /home/paul/xperia/build/*) ;; *) echo "BUILD_DIR must be below /home/paul/xperia/build" >&2; exit 1;; esac
"$repo_root/scripts/prepare-hikari-kernel-tree.sh" "$kernel_src"
make -C "$kernel_src" O="$build_dir" ARCH=arm CROSS_COMPILE="$cross_compile" qcom_defconfig
"$kernel_src/scripts/kconfig/merge_config.sh" -m -O "$build_dir" "$build_dir/.config" "$repo_root/kernel/configs/hikari-firstboot.fragment"
make -C "$kernel_src" O="$build_dir" ARCH=arm CROSS_COMPILE="$cross_compile" olddefconfig
if [[ -n "$initramfs_source" ]]; then
  test -f "$initramfs_source" || { echo "INITRAMFS_SOURCE is not a regular file" >&2; exit 1; }
  "$kernel_src/scripts/config" --file "$build_dir/.config" --set-str INITRAMFS_SOURCE "$initramfs_source"
  make -C "$kernel_src" O="$build_dir" ARCH=arm CROSS_COMPILE="$cross_compile" olddefconfig
fi
make -C "$kernel_src" O="$build_dir" ARCH=arm CROSS_COMPILE="$cross_compile" -j"$jobs" zImage qcom/qcom-msm8260-sony-hikari.dtb
echo "zImage: $build_dir/arch/arm/boot/zImage"
echo "DTB:    $build_dir/arch/arm/boot/dts/qcom/qcom-msm8260-sony-hikari.dtb"
