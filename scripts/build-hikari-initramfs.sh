#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
busybox_src=${BUSYBOX_SRC:-/home/paul/xperia/src/busybox}
busybox_build=${BUSYBOX_BUILD:-/home/paul/xperia/build/busybox-hikari}
initramfs_build=${INITRAMFS_BUILD:-/home/paul/xperia/build/hikari-initramfs}
initramfs_name=${INITRAMFS_NAME:-hikari-firstboot.cpio.gz}
gen_init_cpio=${GEN_INIT_CPIO:-/home/paul/xperia/build/linux-hikari/usr/gen_init_cpio}
cross_compile=${CROSS_COMPILE:-arm-linux-gnueabihf-}
jobs=${JOBS:-"$(nproc)"}
source_date_epoch=${SOURCE_DATE_EPOCH:-0}

case "$busybox_build" in /home/paul/xperia/build/*) ;; *) echo "BUSYBOX_BUILD must be below /home/paul/xperia/build" >&2; exit 1;; esac
case "$initramfs_build" in /home/paul/xperia/build/*) ;; *) echo "INITRAMFS_BUILD must be below /home/paul/xperia/build" >&2; exit 1;; esac
test -f "$busybox_src/Makefile" || { echo "missing external BusyBox source tree" >&2; exit 1; }
test -f "$repo_root/initramfs/hikari-firstboot/init" || { echo "missing project init" >&2; exit 1; }
test -x "$gen_init_cpio" || { echo "missing executable gen_init_cpio: $gen_init_cpio" >&2; exit 1; }
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

# Generate the canonical applet-link tree from this already-built BusyBox.
# `make install` reads BusyBox's generated applet metadata; it does not add an
# applet or execute the ARM binary on the host. This is a host build-time step,
# not a PID-1 workaround.
busybox_install="$initramfs_build/busybox-install"
rm -rf -- "$busybox_install"
make -C "$busybox_src" O="$busybox_build" ARCH=arm CROSS_COMPILE="$cross_compile" \
  CONFIG_PREFIX="$busybox_install" install

list="$initramfs_build/${initramfs_name%.gz}.list"
archive="$initramfs_build/${initramfs_name%.gz}"

# Generate the archive through the kernel initramfs file-list mechanism.  It
# can encode device nodes without host privileges, unlike mknod in a staging
# directory.  /dev/console must exist before the kernel runs /init; devtmpfs
# is mounted by PID 1 only afterwards.
{
  printf '%s\n' \
    'dir /bin 0755 0 0' \
    'dir /dev 0755 0 0' \
    'dir /proc 0755 0 0' \
    'dir /run 0755 0 0' \
    'dir /sbin 0755 0 0' \
    'dir /sys 0755 0 0' \
    'dir /usr 0755 0 0' \
    'dir /usr/bin 0755 0 0' \
    'dir /usr/sbin 0755 0 0'
  printf 'file /bin/busybox %s 0755 0 0\n' "$busybox_build/busybox"
  # Preserve BusyBox's canonical applet paths rather than curating a fragile
  # hand-maintained list. The installed BusyBox binary is omitted: the archive
  # copy above is authoritative. Targets must remain relative archive paths.
  while IFS= read -r -d '' link; do
    rel=${link#"$busybox_install"/}
    target=$(readlink -- "$link")
    resolved=$(readlink -f -- "$link")
    [[ "$target" != /* && "$resolved" = "$busybox_install/bin/busybox" ]] || {
      echo "unsafe BusyBox applet symlink: $rel -> $target" >&2
      exit 1
    }
    printf 'slink /%s %s 0777 0 0\n' "$rel" "$target"
  done < <(find "$busybox_install" -type l -print0 | sort -z)
  printf '%s\n' \
    'nod /dev/console 0600 0 0 c 5 1' \
    'nod /dev/null 0666 0 0 c 1 3'
  printf 'file /init %s 0755 0 0\n' "$repo_root/initramfs/hikari-firstboot/init"
} > "$list"

"$gen_init_cpio" -t "$source_date_epoch" "$list" > "$archive"
gzip -n -f -9 "$archive"
"$repo_root/scripts/check-hikari-initramfs.sh" "$initramfs_build/$initramfs_name"
sha256sum "$initramfs_build/$initramfs_name"
echo "initramfs: $initramfs_build/$initramfs_name"
