#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
hikari_build_root=${HIKARI_BUILD_ROOT:-/home/paul/xperia/build}
busybox_src=${BUSYBOX_SRC:-/home/paul/xperia/src/busybox}
busybox_build=${BUSYBOX_BUILD:-"$hikari_build_root/busybox-hikari-current"}
output_dir=${OUTPUT_DIR:-"$hikari_build_root/hikari-root-initramfs-current"}
gen_init_cpio=${GEN_INIT_CPIO:-"$hikari_build_root/linux-hikari-current/usr/gen_init_cpio"}
cross_compile=${CROSS_COMPILE:-arm-linux-gnueabihf-}
jobs=${JOBS:-"$(nproc)"}

mkdir -p "$hikari_build_root"
hikari_build_root=$(realpath -m -- "$hikari_build_root")
busybox_build=$(realpath -m -- "$busybox_build")
output_dir=$(realpath -m -- "$output_dir")
for output in "$busybox_build" "$output_dir"; do
	case "$output" in "$hikari_build_root"/*) ;; *) echo "output outside HIKARI_BUILD_ROOT: $output" >&2; exit 1;; esac
done
test -x "$gen_init_cpio" || { echo "missing gen_init_cpio: $gen_init_cpio" >&2; exit 1; }

mkdir -p "$busybox_build" "$output_dir"
if [[ ! -f "$busybox_build/.config" ]]; then
	(
		set +o pipefail
		yes '' | make -C "$busybox_src" O="$busybox_build" ARCH=arm CROSS_COMPILE="$cross_compile" defconfig
	)
fi
if grep -q '^# CONFIG_STATIC is not set$' "$busybox_build/.config"; then
	sed -i 's/^# CONFIG_STATIC is not set$/CONFIG_STATIC=y/' "$busybox_build/.config"
elif ! grep -q '^CONFIG_STATIC=y$' "$busybox_build/.config"; then
	printf '\nCONFIG_STATIC=y\n' >>"$busybox_build/.config"
fi
# BusyBox 1.36 tc still references CBQ UAPI removed by current libc headers.
# The bootstrap neither needs nor ships a traffic-control interface.
if grep -q '^CONFIG_TC=y$' "$busybox_build/.config"; then
	sed -i 's/^CONFIG_TC=y$/# CONFIG_TC is not set/' "$busybox_build/.config"
fi
make -C "$busybox_src" O="$busybox_build" ARCH=arm CROSS_COMPILE="$cross_compile" -j"$jobs" busybox

list="$output_dir/hikari-root.list"
archive="$output_dir/hikari-root.cpio"
{
	printf '%s\n' \
		'dir /bin 0755 0 0' 'dir /dev 0755 0 0' 'dir /newroot 0755 0 0' \
		'dir /proc 0755 0 0' 'dir /run 0755 0 0' 'dir /sbin 0755 0 0' \
		'dir /sys 0755 0 0' 'dir /usr 0755 0 0' 'dir /usr/bin 0755 0 0' \
		'dir /usr/sbin 0755 0 0' \
		'nod /dev/console 0600 0 0 c 5 1' 'nod /dev/null 0666 0 0 c 1 3'
	printf 'file /bin/busybox %s 0755 0 0\n' "$busybox_build/busybox"
	for applet in cat ln mount mountpoint mkdir setsid sh sleep switch_root; do
		printf 'slink /bin/%s busybox 0777 0 0\n' "$applet"
	done
	printf 'file /init %s 0755 0 0\n' "$repo_root/initramfs/hikari-root/init"
	printf 'file /usr/sbin/hikari-usb-gadget %s 0755 0 0\n' \
		"$repo_root/initramfs/common/usr/sbin/hikari-usb-gadget"
} >"$list"
"$gen_init_cpio" -t 0 "$list" >"$archive"
gzip -n -9 -f "$archive"
sha256sum "$archive.gz"
printf 'initramfs: %s\n' "$archive.gz"
