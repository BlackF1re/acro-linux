#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Build the reproducible, redistributable Hikari development bundle. No Sony
# RPM firmware is embedded here and no device transport is invoked.
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
hikari_build_root=${HIKARI_BUILD_ROOT:-/home/paul/xperia/build}
kernel_src=${KERNEL_SRC:-/home/paul/xperia/src/linux}
busybox_src=${BUSYBOX_SRC:-/home/paul/xperia/src/busybox}
kernel_build=${KERNEL_BUILD:-"$hikari_build_root/linux-hikari-current"}
initramfs_build=${INITRAMFS_BUILD:-"$hikari_build_root/hikari-initramfs-current"}
initramfs=${INITRAMFS:-"$initramfs_build/hikari-firstboot.cpio.gz"}
a220_firmware_dir=${A220_FIRMWARE_DIR:-"$hikari_build_root/hikari-a220-firmware-current"}
artifact_dir=${ARTIFACT_DIR:-"$hikari_build_root/hikari-artifacts-current"}
kernel_fragment=${KERNEL_FRAGMENT:-"$repo_root/kernel/configs/hikari-boot6-display.fragment"}
require_usb_debug=${REQUIRE_USB_DEBUG:-1}
require_display_bringup=${REQUIRE_DISPLAY_BRINGUP:-1}
require_charging=${REQUIRE_CHARGING:-1}

mkdir -p "$hikari_build_root"
hikari_build_root=$(realpath -m -- "$hikari_build_root")
artifact_dir=$(realpath -m -- "$artifact_dir")
case "$artifact_dir" in "$hikari_build_root"/*) ;; *) echo "ARTIFACT_DIR must be below HIKARI_BUILD_ROOT=$hikari_build_root" >&2; exit 1;; esac
[[ ! -e $artifact_dir ]] || { echo "refusing to overwrite artifact directory: $artifact_dir" >&2; exit 1; }

git -C "$kernel_src" rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo 'KERNEL_SRC must be a Linux git worktree' >&2; exit 1; }
git -C "$busybox_src" rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo 'BUSYBOX_SRC must be a BusyBox git worktree' >&2; exit 1; }
python3 "$repo_root/tools/check_hikari_kernel_guards.py" --kernel-src "$kernel_src"

HIKARI_BUILD_ROOT="$hikari_build_root" KERNEL_SRC="$kernel_src" \
  KERNEL_FRAGMENT="$kernel_fragment" BUILD_DIR="$kernel_build" TARGETS=usr/ \
  REQUIRE_USB_DEBUG="$require_usb_debug" \
  REQUIRE_DISPLAY_BRINGUP="$require_display_bringup" \
  REQUIRE_CHARGING="$require_charging" \
  "$repo_root/scripts/build-hikari-kernel.sh"

"$repo_root/scripts/materialize-hikari-a220-firmware.sh" "$a220_firmware_dir"

HIKARI_BUILD_ROOT="$hikari_build_root" BUSYBOX_SRC="$busybox_src" \
  GEN_INIT_CPIO="$kernel_build/usr/gen_init_cpio" INITRAMFS_BUILD="$initramfs_build" \
  A220_FIRMWARE_DIR="$a220_firmware_dir" \
  "$repo_root/scripts/build-hikari-initramfs.sh"

HIKARI_BUILD_ROOT="$hikari_build_root" KERNEL_SRC="$kernel_src" \
  KERNEL_FRAGMENT="$kernel_fragment" BUILD_DIR="$kernel_build" \
  INITRAMFS_SOURCE="$initramfs" \
  TARGETS='zImage qcom/qcom-msm8260-sony-hikari.dtb qcom/qcom-msm8260-sony-hikari-gpu.dtb qcom/qcom-msm8260-sony-hikari-safe.dtb' \
  REQUIRE_USB_DEBUG="$require_usb_debug" \
  REQUIRE_DISPLAY_BRINGUP="$require_display_bringup" \
  REQUIRE_CHARGING="$require_charging" \
  "$repo_root/scripts/build-hikari-kernel.sh"

zimage="$kernel_build/arch/arm/boot/zImage"
dtb_display="$kernel_build/arch/arm/boot/dts/qcom/qcom-msm8260-sony-hikari.dtb"
dtb_gpu="$kernel_build/arch/arm/boot/dts/qcom/qcom-msm8260-sony-hikari-gpu.dtb"
dtb_safe="$kernel_build/arch/arm/boot/dts/qcom/qcom-msm8260-sony-hikari-safe.dtb"
for input in "$zimage" "$dtb_display" "$dtb_gpu" "$dtb_safe" "$initramfs" "$kernel_build/.config"; do
  [[ -f $input ]] || { echo "bundle input missing: $input" >&2; exit 1; }
done

"$repo_root/scripts/check-hikari-diagnostic-survival.sh" \
  --kernel-src "$kernel_src" --config "$kernel_build/.config" --dtb "$dtb_display"
"$repo_root/scripts/check-hikari-safe-profile.sh" \
  --config "$kernel_build/.config" --dtb "$dtb_safe"
"$repo_root/scripts/check-hikari-gpu-profile.sh" \
  --config "$kernel_build/.config" --dtb "$dtb_gpu"
if [[ $require_display_bringup == 1 ]]; then
  "$repo_root/scripts/check-hikari-display.sh" --config "$kernel_build/.config" --dtb "$dtb_display"
fi
if [[ $require_charging == 1 ]]; then
  "$repo_root/scripts/check-hikari-charging.sh" --config "$kernel_build/.config" --dtb "$dtb_display"
fi
"$repo_root/scripts/check-hikari-board-hardware.sh" --config "$kernel_build/.config" --dtb "$dtb_display"

mkdir -p "$artifact_dir/display" "$artifact_dir/gpu" "$artifact_dir/safe" "$artifact_dir/common"
install -m 0644 "$zimage" "$artifact_dir/common/zImage"
install -m 0644 "$initramfs" "$artifact_dir/common/hikari-firstboot.cpio.gz"
install -m 0644 "$kernel_build/.config" "$artifact_dir/common/kernel.config"
install -m 0644 "$dtb_display" "$artifact_dir/display/qcom-msm8260-sony-hikari.dtb"
install -m 0644 "$dtb_gpu" "$artifact_dir/gpu/qcom-msm8260-sony-hikari-gpu.dtb"
install -m 0644 "$dtb_safe" "$artifact_dir/safe/qcom-msm8260-sony-hikari-safe.dtb"
cat "$zimage" "$dtb_display" > "$artifact_dir/display/hikari-zImage-appended-dtb"
cat "$zimage" "$dtb_gpu" > "$artifact_dir/gpu/hikari-zImage-appended-dtb"
cat "$zimage" "$dtb_safe" > "$artifact_dir/safe/hikari-zImage-appended-dtb"

python3 - "$artifact_dir" <<'PY'
from pathlib import Path
import sys
root = Path(sys.argv[1])
zsize = (root / 'common/zImage').stat().st_size
for path in (root/'display/hikari-zImage-appended-dtb', root/'gpu/hikari-zImage-appended-dtb', root/'safe/hikari-zImage-appended-dtb'):
    data = path.read_bytes()
    if data[zsize:zsize + 4] != b'\xd0\x0d\xfe\xed':
        raise SystemExit(f'{path}: FDT magic is missing at the zImage boundary')
PY

repo_head=$(git -C "$repo_root" rev-parse HEAD 2>/dev/null || printf unknown)
kernel_head=$(git -C "$kernel_src" rev-parse HEAD)
busybox_head=$(git -C "$busybox_src" rev-parse HEAD)
cat > "$artifact_dir/BUILD-MANIFEST.txt" <<EOF
artifact_type=Hikari mainline development bundle
project_commit=$repo_head
kernel_commit=$kernel_head
busybox_commit=$busybox_head
kernel_base=$(sed -n 's/^LINUX_BASE=//p' "$repo_root/kernel/source.lock")
busybox_base=$(sed -n 's/^BUSYBOX_BASE=//p' "$repo_root/initramfs/source.lock")
a220_firmware_ref=$(sed -n 's/^LINUX_FIRMWARE_REF=//p' "$repo_root/firmware/a220/source.lock")
profile_display=full Hikari hardware and experimental display bring-up; Adreno disabled
profile_gpu=display profile plus source-backed Adreno A220 node and exact Sony MSM8x60 OPPs
profile_safe=USB/ramoops diagnostic fallback with multimedia island disabled
fastboot_ready=no (Sony RPM firmware intentionally not embedded in this public bundle)
EOF
(
  cd "$artifact_dir"
  find common display gpu safe -type f -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS
)
printf 'HIKARI_BUNDLE=PASS\nartifact_dir=%s\n' "$artifact_dir"
