#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Atomically refresh the one Sony ELF used to enter the Debian architecture.
# This packages only local files and never invokes adb, fastboot or a device.
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
hikari_build_root=${HIKARI_BUILD_ROOT:-/home/paul/xperia/build}
kernel_build=${KERNEL_BUILD:-"$hikari_build_root/linux-hikari-current"}
initramfs=${INITRAMFS:-"$hikari_build_root/hikari-root-initramfs-current/hikari-root.cpio.gz"}
rpm=${RPM_PAYLOAD:-/home/paul/xperia/p3-offline-analysis.rSjNfb/rpm.segment}
artifact_dir=${ARTIFACT_DIR:-"$hikari_build_root/hikari-debian-current"}
output=${OUTPUT:-"$artifact_dir/hikari-debian-fastboot.elf"}
zimage="$kernel_build/arch/arm/boot/zImage"
dtb="$kernel_build/arch/arm/boot/dts/qcom/qcom-msm8260-sony-hikari.dtb"

hikari_build_root=$(realpath -m -- "$hikari_build_root")
artifact_dir=$(realpath -m -- "$artifact_dir")
output=$(realpath -m -- "$output")
case "$artifact_dir" in "$hikari_build_root"/*) ;; *) echo 'artifact directory outside HIKARI_BUILD_ROOT' >&2; exit 1;; esac
case "$output" in "$artifact_dir"/*) ;; *) echo 'output outside ARTIFACT_DIR' >&2; exit 1;; esac

mkdir -p "$artifact_dir"
staging=$(mktemp -d "$artifact_dir/.hikari-debian-elf.XXXXXX")
cleanup()
{
	find "$staging" -depth -delete 2>/dev/null || true
}
trap cleanup EXIT

"$repo_root/scripts/package-hikari-fastboot.sh" \
	--kernel-build "$kernel_build" \
	--zimage "$zimage" \
	--dtb "$dtb" \
	--ramdisk "$initramfs" \
	--rpm "$rpm" \
	--output "$staging/hikari-debian-fastboot.elf"

# Packaging and all layout checks succeeded, so replace only the generated
# current artifact. The previous file remains intact if packaging fails.
install -m 0644 "$staging/hikari-debian-fastboot.elf" "$output"
output_name=${output#"$artifact_dir"/}
(cd "$artifact_dir" && sha256sum "$output_name") >"$artifact_dir/SHA256SUMS"
printf 'HIKARI_DEBIAN_ELF=PASS\nartifact=%s\n' "$output"
