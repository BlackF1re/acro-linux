#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# End-to-end local Hikari build: create the redistributable bundle first, then
# package display, GPU and USB-safe Sony ELF32 artifacts from a caller-supplied
# RPM firmware segment. No device transport or flashing is performed.
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
hikari_build_root=${HIKARI_BUILD_ROOT:-/home/paul/xperia/build}
kernel_build=${KERNEL_BUILD:-"$hikari_build_root/linux-hikari-current"}
kernel_src=${KERNEL_SRC:-/home/paul/xperia/src/linux}
busybox_src=${BUSYBOX_SRC:-/home/paul/xperia/src/busybox}
initramfs_build=${INITRAMFS_BUILD:-"$hikari_build_root/hikari-initramfs-current"}
initramfs=${INITRAMFS:-"$initramfs_build/hikari-firstboot.cpio.gz"}
rpm=${RPM_PAYLOAD:-/home/paul/xperia/p3-offline-analysis.rSjNfb/rpm.segment}
artifact_dir=${ARTIFACT_DIR:-"$hikari_build_root/hikari-artifacts-current"}
display_output=${OUTPUT:-"$artifact_dir/display/hikari-display-fastboot.elf"}
gpu_output=${GPU_OUTPUT:-"$artifact_dir/gpu/hikari-gpu-fastboot.elf"}
safe_output=${SAFE_OUTPUT:-"$artifact_dir/safe/hikari-safe-fastboot.elf"}

[[ -f $rpm ]] || { echo 'RPM_PAYLOAD must name the private/appropriately licensed LT26 RPM firmware payload' >&2; exit 1; }

HIKARI_BUILD_ROOT="$hikari_build_root" KERNEL_SRC="$kernel_src" BUSYBOX_SRC="$busybox_src" \
  KERNEL_BUILD="$kernel_build" INITRAMFS_BUILD="$initramfs_build" INITRAMFS="$initramfs" \
  ARTIFACT_DIR="$artifact_dir" \
  "$repo_root/scripts/build-hikari-bundle.sh"

for profile in display gpu safe; do
  case "$profile" in
    display) dtb="$artifact_dir/display/qcom-msm8260-sony-hikari.dtb"; output="$display_output" ;;
    gpu) dtb="$artifact_dir/gpu/qcom-msm8260-sony-hikari-gpu.dtb"; output="$gpu_output" ;;
    safe) dtb="$artifact_dir/safe/qcom-msm8260-sony-hikari-safe.dtb"; output="$safe_output" ;;
  esac
  "$repo_root/scripts/package-hikari-fastboot.sh" \
    --kernel-build "$kernel_build" \
    --zimage "$artifact_dir/common/zImage" \
    --dtb "$dtb" \
    --ramdisk "$artifact_dir/common/hikari-firstboot.cpio.gz" \
    --rpm "$rpm" \
    --output "$output"
done

sed -i 's/^fastboot_ready=.*/fastboot_ready=yes (caller supplied RPM firmware; redistribution rights are not inferred)/' \
  "$artifact_dir/BUILD-MANIFEST.txt"
(
  cd "$artifact_dir"
  find common display gpu safe -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS
)
printf 'HIKARI_FASTBOOT_ARTIFACTS=PASS\ndisplay=%s\ngpu=%s\nsafe=%s\n' "$display_output" "$gpu_output" "$safe_output"
