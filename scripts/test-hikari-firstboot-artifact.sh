#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Offline validation only: no ADB, fastboot, USB, or device commands.
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
artifact=${ARTIFACT:-/home/paul/xperia/build/hikari-artifacts/hikari-firstboot.elf}
kernel_with_dtb=${KERNEL_WITH_DTB:-/home/paul/xperia/build/hikari-artifacts/hikari-zImage-appended-dtb}
dtb=${DTB:-/home/paul/xperia/build/linux-hikari/arch/arm/boot/dts/qcom/qcom-msm8260-sony-hikari.dtb}
p3=${ORIGINAL_P3:-/home/paul/xperia/p3-offline-analysis.rSjNfb/mmcblk0p3.img}
expected_p3_sha256=c59be74873aa32a8422adf9b5402254b2acae619f7dc97bd50fc0e120984d0c1
p3_limit=$((20 * 1024 * 1024))

for input in "$artifact" "$kernel_with_dtb" "$dtb" "$p3"; do
  test -f "$input" || { echo "missing offline input: $input" >&2; exit 1; }
done
test "$(stat -c %s "$p3")" -eq "$p3_limit" || { echo "unexpected original p3 size" >&2; exit 1; }
test "$(sha256sum "$p3" | awk '{print $1}')" = "$expected_p3_sha256" || { echo "original p3 hash mismatch" >&2; exit 1; }
test "$(stat -c %s "$artifact")" -le "$p3_limit" || { echo "artifact exceeds p3 capacity" >&2; exit 1; }
dtb_size=$(stat -c %s "$dtb")
tail -c "$dtb_size" "$kernel_with_dtb" | cmp -s - "$dtb" || { echo "DTB is not the final appended input" >&2; exit 1; }
python3 "$repo_root/tools/sony_elf.py" inspect "$artifact" --limit "$p3_limit"
echo "offline first-boot artifact checks: PASS"
