#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
busybox_src=${BUSYBOX_SRC:-/home/paul/xperia/src/busybox}
busybox_build=${BUSYBOX_BUILD:-/home/paul/xperia/build/busybox-hikari}
initramfs_build=${INITRAMFS_BUILD:-/home/paul/xperia/build/hikari-initramfs}
initramfs_name=${INITRAMFS_NAME:-hikari-firstboot.cpio.gz}
cross_compile=${CROSS_COMPILE:-arm-linux-gnueabihf-}
jobs=${JOBS:-"$(nproc)"}
source_date_epoch=${SOURCE_DATE_EPOCH:-0}

case "$busybox_build" in /home/paul/xperia/build/*) ;; *) echo "BUSYBOX_BUILD must be below /home/paul/xperia/build" >&2; exit 1;; esac
case "$initramfs_build" in /home/paul/xperia/build/*) ;; *) echo "INITRAMFS_BUILD must be below /home/paul/xperia/build" >&2; exit 1;; esac
test -f "$busybox_src/Makefile" || { echo "missing external BusyBox source tree" >&2; exit 1; }
test -f "$repo_root/initramfs/hikari-firstboot/init" || { echo "missing project init" >&2; exit 1; }
[[ "$source_date_epoch" =~ ^[0-9]+$ ]] || { echo "SOURCE_DATE_EPOCH must be an integer" >&2; exit 1; }
[[ "$initramfs_name" != */* && "$initramfs_name" = *.cpio.gz ]] || { echo "INITRAMFS_NAME must be a .cpio.gz filename" >&2; exit 1; }

mkdir -p "$busybox_build" "$initramfs_build"
if [[ ! -f "$busybox_build/.config" ]]; then
  # BusyBox does not provide Linux's scripts/config helper.  Accepting the
  # upstream defaults here is deterministic and gives a diagnostic shell.
  yes '' | make -C "$busybox_src" O="$busybox_build" ARCH=arm CROSS_COMPILE="$cross_compile" defconfig
fi
if grep -q '^# CONFIG_STATIC is not set$' "$busybox_build/.config"; then
  sed -i 's/^# CONFIG_STATIC is not set$/CONFIG_STATIC=y/' "$busybox_build/.config"
fi
# BusyBox's current defconfig enables tc, whose obsolete CBQ UAPI is absent
# from the host cross headers.  It is not needed by the first-boot shell.
if grep -q '^CONFIG_TC=y$' "$busybox_build/.config"; then
  sed -i 's/^CONFIG_TC=y$/# CONFIG_TC is not set/' "$busybox_build/.config"
fi
make -C "$busybox_src" O="$busybox_build" ARCH=arm CROSS_COMPILE="$cross_compile" -j"$jobs" busybox

root=$(mktemp -d "$initramfs_build/root.XXXXXX")
trap 'rm -rf -- "$root"' EXIT
mkdir -p "$root/bin" "$root/dev" "$root/proc" "$root/sys" "$root/sbin"
install -m 0755 "$busybox_build/busybox" "$root/bin/busybox"
ln -s busybox "$root/bin/sh"
install -m 0755 "$repo_root/initramfs/hikari-firstboot/init" "$root/init"
# cpio records mtimes. Normalise only the disposable staging tree so equal
# source inputs yield an equal archive without modifying source files.
find "$root" -exec touch -h -d "@$source_date_epoch" {} +

(
  cd "$root"
  find . -print0 | LC_ALL=C sort -z | cpio --null -o -H newc --reproducible --quiet
) > "$initramfs_build/${initramfs_name%.gz}"
gzip -n -f -9 "$initramfs_build/${initramfs_name%.gz}"
sha256sum "$initramfs_build/$initramfs_name"
echo "initramfs: $initramfs_build/$initramfs_name"
