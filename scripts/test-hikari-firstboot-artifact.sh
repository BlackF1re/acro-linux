#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Offline validation only: no ADB, fastboot, USB, or device commands.
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
artifact=${ARTIFACT:-/home/paul/xperia/build/hikari-artifacts-g4/hikari-secondboot.elf}
kernel_build=${KERNEL_BUILD:-/home/paul/xperia/build/linux-hikari-second}
kernel_with_dtb=${KERNEL_WITH_DTB:-/home/paul/xperia/build/hikari-artifacts-g4/hikari-zImage-appended-dtb}
dtb=${DTB:-/home/paul/xperia/build/linux-hikari-second/arch/arm/boot/dts/qcom/qcom-msm8260-sony-hikari.dtb}
zimage=${ZIMAGE:-/home/paul/xperia/build/linux-hikari-second/arch/arm/boot/zImage}
initramfs=${INITRAMFS:-/home/paul/xperia/build/hikari-initramfs-second/hikari-secondboot.cpio.gz}
ramdisk_addr=${RAMDISK_ADDR:-0x42a00000}
kernel_addr=${KERNEL_ADDR:-0x40408000}
p3=${ORIGINAL_P3:-/home/paul/xperia/p3-offline-analysis.rSjNfb/mmcblk0p3.img}
expected_p3_sha256=c59be74873aa32a8422adf9b5402254b2acae619f7dc97bd50fc0e120984d0c1
p3_limit=$((20 * 1024 * 1024))
rpm=${RPM_PAYLOAD:-/home/paul/xperia/p3-offline-analysis.rSjNfb/rpm.segment}

for input in "$artifact" "$kernel_with_dtb" "$zimage" "$dtb" "$initramfs" "$p3" "$rpm"; do
  test -f "$input" || { echo "missing offline input: $input" >&2; exit 1; }
done
test "$(stat -c %s "$p3")" -eq "$p3_limit" || { echo "unexpected original p3 size" >&2; exit 1; }
test "$(sha256sum "$p3" | awk '{print $1}')" = "$expected_p3_sha256" || { echo "original p3 hash mismatch" >&2; exit 1; }
test "$(stat -c %s "$artifact")" -le "$p3_limit" || { echo "artifact exceeds p3 capacity" >&2; exit 1; }
grep -qx 'CONFIG_ARCH_QCOM_RESERVE_SMEM=y' "$kernel_build/.config" || { echo "SMEM reservation is missing" >&2; exit 1; }
grep -qx 'CONFIG_ARM_APPENDED_DTB=y' "$kernel_build/.config" || { echo "appended DTB support is missing" >&2; exit 1; }
grep -qx 'CONFIG_ARM_ATAG_DTB_COMPAT=y' "$kernel_build/.config" || { echo "ATAG-to-DT compatibility is missing" >&2; exit 1; }
dtb_size=$(stat -c %s "$dtb")
zimage_size=$(stat -c %s "$zimage")
head -c "$zimage_size" "$kernel_with_dtb" | cmp -s - "$zimage" || { echo "appended input does not begin with the built zImage" >&2; exit 1; }
tail -c "$dtb_size" "$kernel_with_dtb" | cmp -s - "$dtb" || { echo "DTB is not the final appended input" >&2; exit 1; }
test "$(od -An -tx1 -j "$zimage_size" -N 4 "$kernel_with_dtb" | tr -d '[:space:]')" = d00dfeed || { echo "FDT header missing at appended-DTB boundary" >&2; exit 1; }
"$repo_root/scripts/check-hikari-firstboot-memory.sh" --kernel-build "$kernel_build" --zimage "$zimage" --dtb "$dtb" --ramdisk "$initramfs" --ramdisk-addr "$ramdisk_addr" --kernel-load "$kernel_addr" --rpm "$rpm"
python3 "$repo_root/tools/sony_elf.py" inspect "$artifact" --limit "$p3_limit"
echo "offline first-boot artifact checks: PASS"
