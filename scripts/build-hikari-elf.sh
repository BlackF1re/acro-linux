#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Build a local-only first-boot Sony ELF prototype.  This script has no phone
# transport, fastboot, ADB, or flashing code.
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
kernel_build=${KERNEL_BUILD:-/home/paul/xperia/build/linux-hikari}
initramfs=${INITRAMFS:-/home/paul/xperia/build/hikari-initramfs/hikari-firstboot.cpio.gz}
rpm=${RPM_PAYLOAD:-/home/paul/xperia/p3-offline-analysis.rSjNfb/rpm.segment}
artifact_dir=${ARTIFACT_DIR:-/home/paul/xperia/build/hikari-artifacts}
output=${OUTPUT:-$artifact_dir/hikari-firstboot.elf}
p3_limit=$((20 * 1024 * 1024))

case "$artifact_dir" in /home/paul/xperia/build/*) ;; *) echo "ARTIFACT_DIR must be below /home/paul/xperia/build" >&2; exit 1;; esac
case "$output" in "$artifact_dir"/*) ;; *) echo "OUTPUT must be below ARTIFACT_DIR" >&2; exit 1;; esac
test -f "$rpm" || { echo "RPM_PAYLOAD must name the private legacy RPM payload" >&2; exit 1; }

"$repo_root/scripts/build-hikari-initramfs.sh"
INITRAMFS_SOURCE="$initramfs" "$repo_root/scripts/build-hikari-kernel.sh"

zimage="$kernel_build/arch/arm/boot/zImage"
dtb="$kernel_build/arch/arm/boot/dts/qcom/qcom-msm8260-sony-hikari.dtb"
test -f "$zimage" && test -f "$dtb" || { echo "kernel build did not produce zImage and Hikari DTB" >&2; exit 1; }
mkdir -p "$artifact_dir"
kernel_with_dtb="$artifact_dir/hikari-zImage-appended-dtb"
test ! -e "$kernel_with_dtb" || { echo "refusing to overwrite $kernel_with_dtb" >&2; exit 1; }
test ! -e "$output" || { echo "refusing to overwrite $output" >&2; exit 1; }
cat "$zimage" "$dtb" > "$kernel_with_dtb"
dtb_size=$(stat -c %s "$dtb")
tail -c "$dtb_size" "$kernel_with_dtb" | cmp -s - "$dtb" || { echo "appended DTB validation failed" >&2; exit 1; }

python3 "$repo_root/tools/sony_elf.py" build \
  --kernel "$kernel_with_dtb" --ramdisk "$initramfs" --rpm "$rpm" \
  --output "$output" --kernel-addr 0x40208000 --ramdisk-addr 0x41800000 \
  --rpm-addr 0x00020000 --limit "$p3_limit"
readelf -h "$output"
readelf -l "$output"
sha256sum "$output"
echo "local-only artifact: $output"
