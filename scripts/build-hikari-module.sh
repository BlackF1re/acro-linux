#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Example: scripts/build-hikari-module.sh drivers/nfc
set -euo pipefail

subdir=${1:-}
kernel_src=${KERNEL_SRC:-/home/paul/xperia/src/linux}
kernel_build=${KERNEL_BUILD:-/home/paul/xperia/build/linux-hikari-current}
rootfs=${ROOTFS_DIR:-/home/paul/xperia/build/hikari-rootfs-current}

[[ $subdir != /* && $subdir != *..* && -d "$kernel_src/$subdir" ]] || {
	echo "usage: ${0##*/} <kernel-relative-driver-directory>" >&2
	exit 2
}
test -f "$kernel_build/.config" || { echo 'persistent kernel build is not configured' >&2; exit 1; }
test -x "$rootfs/sbin/init" || { echo "not a rootfs: $rootfs" >&2; exit 1; }

# A trailing directory target is an in-tree incremental Kbuild target. Using
# M= here would treat the driver as an external module, dirty the source tree
# and install a duplicate under lib/modules/.../updates.
make -C "$kernel_src" O="$kernel_build" ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- \
	-j"$(nproc)" "$subdir/"
sudo make -C "$kernel_src" O="$kernel_build" ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- \
	INSTALL_MOD_PATH="$rootfs" INSTALL_MOD_STRIP=1 modules_install
kernel_release=$(make -s -C "$kernel_src" O="$kernel_build" ARCH=arm kernelrelease)
updates_dir="$rootfs/lib/modules/$kernel_release/updates"
if [[ -d $updates_dir ]]; then
	# The managed Hikari rootfs carries only this in-tree kernel's modules.
	# Remove duplicates left by versions of this helper predating the in-tree
	# build target above; find -delete keeps the exact generated scope explicit.
	sudo find "$updates_dir" -depth -delete
fi
sudo depmod -b "$rootfs" "$kernel_release"
printf 'updated %s modules for %s\n' "$subdir" "$kernel_release"
