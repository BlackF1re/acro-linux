#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Update one rootfs in place from the persistent incremental kernel build.
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
kernel_src=${KERNEL_SRC:-/home/paul/xperia/src/linux}
kernel_build=${KERNEL_BUILD:-/home/paul/xperia/build/linux-hikari-current}
rootfs=${ROOTFS_DIR:-/home/paul/xperia/build/hikari-rootfs-current}
initramfs=${INITRAMFS:-/home/paul/xperia/build/hikari-root-initramfs-current/hikari-root.cpio.gz}
dtb="$kernel_build/arch/arm/boot/dts/qcom/qcom-msm8260-sony-hikari.dtb"
boot_dir="$rootfs/boot/hikari-next"

for input in "$kernel_build/arch/arm/boot/zImage" "$dtb" "$initramfs"; do
	test -s "$input" || { echo "missing kernel input: $input" >&2; exit 1; }
done
test -x "$rootfs/sbin/init" || { echo "not a Debian rootfs: $rootfs" >&2; exit 1; }

sudo make -C "$kernel_src" O="$kernel_build" ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- \
	INSTALL_MOD_PATH="$rootfs" INSTALL_MOD_STRIP=1 modules_install
sudo mkdir -p "$boot_dir"
sudo install -m 0644 "$kernel_build/arch/arm/boot/zImage" "$boot_dir/zImage"
sudo install -m 0644 "$dtb" "$boot_dir/qcom-msm8260-sony-hikari.dtb"
sudo install -m 0644 "$initramfs" "$boot_dir/hikari-root.cpio.gz"
(
	cd "$boot_dir"
	sudo sh -c 'sha256sum zImage qcom-msm8260-sony-hikari.dtb hikari-root.cpio.gz > SHA256SUMS'
)
kernel_release=$(make -s -C "$kernel_src" O="$kernel_build" ARCH=arm kernelrelease)
sudo rm -f "$rootfs/lib/modules/$kernel_release/build" \
	"$rootfs/lib/modules/$kernel_release/source"
sudo depmod -b "$rootfs" "$kernel_release"
printf 'installed kernel %s into %s\n' "$kernel_release" "$rootfs"
