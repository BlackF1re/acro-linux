#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Produce the checksum-bearing kernel/module archive consumed by BOOT.
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
hikari_build_root=${HIKARI_BUILD_ROOT:-/home/paul/xperia/build}
kernel_build=${KERNEL_BUILD:-$hikari_build_root/linux-hikari-current}
initramfs=${INITRAMFS:-$hikari_build_root/hikari-root-initramfs-current/hikari-root.cpio.gz}
artifact_dir=${ARTIFACT_DIR:-$hikari_build_root/hikari-debian-current}
rootfs=${ROOTFS_DIR:-$hikari_build_root/hikari-rootfs-current}
output=${OUTPUT:-$artifact_dir/hikari-system-update.tar}
dtb=$kernel_build/arch/arm/boot/dts/qcom/qcom-msm8260-sony-hikari.dtb
zimage=$kernel_build/arch/arm/boot/zImage

for input in "$zimage" "$dtb" "$initramfs"; do
	test -s "$input" || { echo "missing SYSTEM input: $input" >&2; exit 1; }
done
release_file=$rootfs/boot/hikari-next/kernel-release
test -s "$release_file" || { echo "missing kernel release: $release_file" >&2; exit 1; }
kernel_release=$(<"$release_file")
test -d "$rootfs/lib/modules/$kernel_release" || {
	echo "missing modules for $kernel_release" >&2
	exit 1
}
mkdir -p "$artifact_dir"
staging=$(mktemp -d "$artifact_dir/.system-update.XXXXXX")
trap 'find "$staging" -depth -delete 2>/dev/null || true' EXIT
install -m 0644 "$zimage" "$staging/zImage"
install -m 0644 "$dtb" "$staging/qcom-msm8260-sony-hikari.dtb"
install -m 0644 "$initramfs" "$staging/hikari-root.cpio.gz"
install -m 0644 "$release_file" "$staging/kernel-release"
tar -C "$rootfs" -czf "$staging/modules.tar.gz" "lib/modules/$kernel_release"
(cd "$staging" && sha256sum zImage qcom-msm8260-sony-hikari.dtb \
	hikari-root.cpio.gz kernel-release modules.tar.gz >SHA256SUMS)
tar -C "$staging" -cf "$output.new" \
	zImage qcom-msm8260-sony-hikari.dtb hikari-root.cpio.gz kernel-release \
	modules.tar.gz SHA256SUMS
mv -f "$output.new" "$output"
sha256sum "$output"
printf 'SYSTEM update: %s\n' "$output"
