#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
hikari_build_root=${HIKARI_BUILD_ROOT:-/home/paul/xperia/build}
busybox_src=${BUSYBOX_SRC:-/home/paul/xperia/src/busybox}
busybox_build=${BUSYBOX_BUILD:-"$hikari_build_root/busybox-hikari-current"}
initramfs_build=${INITRAMFS_BUILD:-"$hikari_build_root/hikari-initramfs-current"}
initramfs_name=${INITRAMFS_NAME:-hikari-firstboot.cpio.gz}
gen_init_cpio=${GEN_INIT_CPIO:-"$hikari_build_root/linux-hikari-current/usr/gen_init_cpio"}
a220_firmware_dir=${A220_FIRMWARE_DIR:-"$hikari_build_root/hikari-a220-firmware-current"}
cross_compile=${CROSS_COMPILE:-arm-linux-gnueabihf-}
jobs=${JOBS:-"$(nproc)"}
source_date_epoch=${SOURCE_DATE_EPOCH:-0}

mkdir -p "$hikari_build_root"
hikari_build_root=$(realpath -m -- "$hikari_build_root")
busybox_build=$(realpath -m -- "$busybox_build")
initramfs_build=$(realpath -m -- "$initramfs_build")
a220_firmware_dir=$(realpath -m -- "$a220_firmware_dir")
for output in "$busybox_build" "$initramfs_build" "$a220_firmware_dir"; do
  case "$output" in "$hikari_build_root"/*) ;; *) echo "output must be below HIKARI_BUILD_ROOT=$hikari_build_root: $output" >&2; exit 1;; esac
done
test -f "$busybox_src/Makefile" || { echo "missing external BusyBox source tree" >&2; exit 1; }
test -f "$repo_root/initramfs/hikari-firstboot/init" || { echo "missing project init" >&2; exit 1; }
helpers='hikari-diag hikari-display-diag hikari-power-diag hikari-gpu-diag'
for helper in $helpers; do
  test -f "$repo_root/initramfs/hikari-firstboot/usr/sbin/$helper" || {
    echo "missing project diagnostic helper: $helper" >&2
    exit 1
  }
done
test -x "$gen_init_cpio" || { echo "missing executable gen_init_cpio: $gen_init_cpio" >&2; exit 1; }
[[ "$source_date_epoch" =~ ^[0-9]+$ ]] || { echo "SOURCE_DATE_EPOCH must be an integer" >&2; exit 1; }
[[ "$initramfs_name" != */* && "$initramfs_name" = *.cpio.gz ]] || { echo "INITRAMFS_NAME must be a .cpio.gz filename" >&2; exit 1; }

if [[ ! -s "$a220_firmware_dir/qcom/leia_pm4_470.fw" || ! -s "$a220_firmware_dir/qcom/leia_pfp_470.fw" ]]; then
  "$repo_root/scripts/materialize-hikari-a220-firmware.sh" "$a220_firmware_dir"
fi

mkdir -p "$busybox_build" "$initramfs_build"
if [[ ! -f "$busybox_build/.config" ]]; then
  (
    set +o pipefail
    yes '' | make -C "$busybox_src" O="$busybox_build" ARCH=arm CROSS_COMPILE="$cross_compile" defconfig
  )
fi
if grep -q '^# CONFIG_STATIC is not set$' "$busybox_build/.config"; then
  sed -i 's/^# CONFIG_STATIC is not set$/CONFIG_STATIC=y/' "$busybox_build/.config"
fi
if grep -q '^CONFIG_TC=y$' "$busybox_build/.config"; then
  sed -i 's/^CONFIG_TC=y$/# CONFIG_TC is not set/' "$busybox_build/.config"
fi
make -C "$busybox_src" O="$busybox_build" ARCH=arm CROSS_COMPILE="$cross_compile" -j"$jobs" busybox

busybox_install="$initramfs_build/busybox-install"
rm -rf -- "$busybox_install"
make -C "$busybox_src" O="$busybox_build" ARCH=arm CROSS_COMPILE="$cross_compile" \
  CONFIG_PREFIX="$busybox_install" install

list="$initramfs_build/${initramfs_name%.gz}.list"
archive="$initramfs_build/${initramfs_name%.gz}"
{
  printf '%s\n' \
    'dir /bin 0755 0 0' \
    'dir /dev 0755 0 0' \
    'dir /lib 0755 0 0' \
    'dir /lib/firmware 0755 0 0' \
    'dir /lib/firmware/qcom 0755 0 0' \
    'dir /proc 0755 0 0' \
    'dir /run 0755 0 0' \
    'dir /sbin 0755 0 0' \
    'dir /sys 0755 0 0' \
    'dir /usr 0755 0 0' \
    'dir /usr/bin 0755 0 0' \
    'dir /usr/sbin 0755 0 0'
  printf 'file /bin/busybox %s 0755 0 0\n' "$busybox_build/busybox"
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
  printf 'file /lib/firmware/qcom/leia_pm4_470.fw %s 0644 0 0\n' "$a220_firmware_dir/qcom/leia_pm4_470.fw"
  printf 'file /lib/firmware/qcom/leia_pfp_470.fw %s 0644 0 0\n' "$a220_firmware_dir/qcom/leia_pfp_470.fw"
  printf 'file /init %s 0755 0 0\n' "$repo_root/initramfs/hikari-firstboot/init"
  for helper in $helpers; do
    printf 'file /usr/sbin/%s %s 0755 0 0\n' "$helper" \
      "$repo_root/initramfs/hikari-firstboot/usr/sbin/$helper"
  done
} > "$list"

"$gen_init_cpio" -t "$source_date_epoch" "$list" > "$archive"
gzip -n -f -9 "$archive"
"$repo_root/scripts/check-hikari-initramfs.sh" "$initramfs_build/$initramfs_name"
sha256sum "$initramfs_build/$initramfs_name"
echo "initramfs: $initramfs_build/$initramfs_name"
