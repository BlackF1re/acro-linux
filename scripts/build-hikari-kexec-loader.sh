#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Build the single-core rescue kernel that safely kexecs an SMP kernel from SD.
# Reuse the canonical source and O= directory; no duplicate tree is created.
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
hikari_build_root=${HIKARI_BUILD_ROOT:-/home/paul/xperia/build}
kernel_build=${KERNEL_BUILD:-"$hikari_build_root/linux-hikari-current"}
base_fragment="$repo_root/kernel/configs/hikari-boot6-display.fragment"
debian_fragment="$repo_root/kernel/configs/hikari-debian.fragment"
loader_fragment="$repo_root/kernel/configs/hikari-kexec-loader.fragment"
root_initramfs="$hikari_build_root/hikari-root-initramfs-current/hikari-root.cpio.gz"

test -s "$root_initramfs" || {
	echo "missing root initramfs: $root_initramfs" >&2
	exit 1
}

HIKARI_BUILD_ROOT="$hikari_build_root" BUILD_DIR="$kernel_build" \
	KERNEL_FRAGMENT="$base_fragment" \
	KERNEL_EXTRA_FRAGMENTS="$debian_fragment $loader_fragment" \
	PRUNE_DEFAULT_MODULES=1 INITRAMFS_SOURCE="$root_initramfs" \
	REQUIRE_USB_DEBUG=1 REQUIRE_DISPLAY_BRINGUP=1 REQUIRE_CHARGING=1 \
	TARGETS='zImage qcom/qcom-msm8260-sony-hikari.dtb' \
	"$repo_root/scripts/build-hikari-kernel.sh"

config="$kernel_build/.config"
grep -qx '# CONFIG_SMP is not set' "$config" || {
	echo 'loader build unexpectedly enables SMP' >&2
	exit 1
}
grep -qx 'CONFIG_KEXEC=y' "$config" || {
	echo 'loader build lost CONFIG_KEXEC=y' >&2
	exit 1
}

printf 'HIKARI_KEXEC_LOADER=PASS\nbuild=%s\ninitramfs=%s\n' \
	"$kernel_build" "$root_initramfs"
