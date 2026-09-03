#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Build a local-only first-boot Sony ELF prototype.  This script has no phone
# transport, fastboot, ADB, or flashing code.
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
kernel_build=${KERNEL_BUILD:-/home/paul/xperia/build/linux-hikari-current}
kernel_src=${KERNEL_SRC:-/home/paul/xperia/src/linux}
kernel_fragment=${KERNEL_FRAGMENT:-$repo_root/kernel/configs/hikari-boot6-display.fragment}
initramfs=${INITRAMFS:-/home/paul/xperia/build/hikari-initramfs-current/hikari-firstboot.cpio.gz}
initramfs_build=${INITRAMFS_BUILD:-/home/paul/xperia/build/hikari-initramfs-current}
initramfs_name=${INITRAMFS_NAME:-$(basename -- "$initramfs")}
rpm=${RPM_PAYLOAD:-/home/paul/xperia/p3-offline-analysis.rSjNfb/rpm.segment}
artifact_dir=${ARTIFACT_DIR:-/home/paul/xperia/build/hikari-artifacts-current}
output=${OUTPUT:-$artifact_dir/hikari-current.elf}
require_display_bringup=${REQUIRE_DISPLAY_BRINGUP:-1}
require_usb_debug=${REQUIRE_USB_DEBUG:-1}
require_charging=${REQUIRE_CHARGING:-1}
ramdisk_addr=${RAMDISK_ADDR:-0x42a00000}
kernel_addr=${KERNEL_ADDR:-0x40208000}
p3_limit=$((20 * 1024 * 1024))

case "$artifact_dir" in /home/paul/xperia/build/*) ;; *) echo "ARTIFACT_DIR must be below /home/paul/xperia/build" >&2; exit 1;; esac
case "$output" in "$artifact_dir"/*) ;; *) echo "OUTPUT must be below ARTIFACT_DIR" >&2; exit 1;; esac
test -f "$rpm" || { echo "RPM_PAYLOAD must name the private legacy RPM payload" >&2; exit 1; }
python3 "$repo_root/tools/check_hikari_kernel_guards.py" --kernel-src "$kernel_src"

# Prime the one canonical kernel output tree first.  Besides validating the
# configuration this builds usr/gen_init_cpio, which a fresh initramfs build
# needs before CONFIG_INITRAMFS_SOURCE can point back at the resulting archive.
KERNEL_SRC="$kernel_src" KERNEL_FRAGMENT="$kernel_fragment" \
  BUILD_DIR="$kernel_build" \
  TARGETS=usr/gen_init_cpio \
  REQUIRE_USB_DEBUG="$require_usb_debug" \
  REQUIRE_DISPLAY_BRINGUP="$require_display_bringup" \
  REQUIRE_CHARGING="$require_charging" \
  "$repo_root/scripts/build-hikari-kernel.sh"
GEN_INIT_CPIO="$kernel_build/usr/gen_init_cpio" \
  INITRAMFS_BUILD="$initramfs_build" INITRAMFS_NAME="$initramfs_name" \
  "$repo_root/scripts/build-hikari-initramfs.sh"
KERNEL_SRC="$kernel_src" KERNEL_FRAGMENT="$kernel_fragment" \
  BUILD_DIR="$kernel_build" INITRAMFS_SOURCE="$initramfs" \
  REQUIRE_USB_DEBUG="$require_usb_debug" \
  REQUIRE_DISPLAY_BRINGUP="$require_display_bringup" \
  REQUIRE_CHARGING="$require_charging" \
  "$repo_root/scripts/build-hikari-kernel.sh"

zimage="$kernel_build/arch/arm/boot/zImage"
dtb="$kernel_build/arch/arm/boot/dts/qcom/qcom-msm8260-sony-hikari.dtb"
test -f "$zimage" && test -f "$dtb" || { echo "kernel build did not produce zImage and Hikari DTB" >&2; exit 1; }
if [[ $require_display_bringup == 1 ]]; then
	"$repo_root/scripts/check-hikari-display.sh" --config "$kernel_build/.config" --dtb "$dtb"
fi
if [[ $require_charging == 1 ]]; then
  "$repo_root/scripts/check-hikari-charging.sh" --config "$kernel_build/.config" --dtb "$dtb"
fi
mkdir -p "$artifact_dir"
kernel_with_dtb="$artifact_dir/hikari-zImage-appended-dtb"
test ! -e "$kernel_with_dtb" || { echo "refusing to overwrite $kernel_with_dtb" >&2; exit 1; }
test ! -e "$output" || { echo "refusing to overwrite $output" >&2; exit 1; }
cp -- "$zimage" "$kernel_with_dtb"
dd if="$dtb" of="$kernel_with_dtb" oflag=append conv=notrunc status=none
dtb_size=$(stat -c %s "$dtb")
zimage_size=$(stat -c %s "$zimage")
test "$zimage_size" -gt 0 || { echo "zImage is empty" >&2; exit 1; }
head -c "$zimage_size" "$kernel_with_dtb" | cmp -s - "$zimage" || {
  echo "appended kernel input does not begin with the built zImage" >&2
  exit 1
}
tail -c "$dtb_size" "$kernel_with_dtb" | cmp -s - "$dtb" || { echo "appended DTB validation failed" >&2; exit 1; }
test "$(od -An -tx1 -j "$zimage_size" -N 4 "$kernel_with_dtb" | tr -d '[:space:]')" = d00dfeed || {
  echo "appended input does not contain an FDT header at the DTB boundary" >&2
  exit 1
}

"$repo_root/scripts/check-hikari-firstboot-memory.sh" \
  --kernel-build "$kernel_build" --zimage "$zimage" --dtb "$dtb" \
  --ramdisk "$initramfs" --ramdisk-addr "$ramdisk_addr" \
  --kernel-load "$kernel_addr" --rpm "$rpm"
"$repo_root/scripts/check-hikari-persistent-ram.sh" \
  --config "$kernel_build/.config" --dtb "$dtb"
if [[ $require_display_bringup == 1 ]]; then
	"$repo_root/scripts/check-hikari-display.sh" --config "$kernel_build/.config" --dtb "$dtb"
fi

python3 "$repo_root/tools/sony_elf.py" build \
  --kernel "$kernel_with_dtb" --ramdisk "$initramfs" --rpm "$rpm" \
  --output "$output" --kernel-addr "$kernel_addr" --ramdisk-addr "$ramdisk_addr" \
  --rpm-addr 0x00020000 --limit "$p3_limit"
python3 - "$output" "$zimage" "$dtb" "$kernel_addr" <<'PY'
import struct
import sys

artifact, zimage, dtb, kernel_addr = sys.argv[1:]
kernel_addr = int(kernel_addr, 0)
with open(artifact, 'rb') as f:
    data = f.read()
with open(zimage, 'rb') as f:
    zdata = f.read()
with open(dtb, 'rb') as f:
    ddata = f.read()

ehdr = struct.unpack_from('<16sHHIIIIIHHHHHH', data)
phoff, phentsize, phnum = ehdr[5], ehdr[9], ehdr[10]
segments = []
for index in range(phnum):
    offset = phoff + index * phentsize
    segments.append(struct.unpack_from('<IIIIIIII', data, offset))
kernel = next((entry for entry in segments if entry[0] == 1 and entry[2] == kernel_addr), None)
if kernel is None:
    raise SystemExit(f'Sony ELF has no kernel segment at configured load address 0x{kernel_addr:08x}')
_, offset, _, _, filesz, _, _, _ = kernel
payload = data[offset:offset + filesz]
if payload != zdata + ddata:
    raise SystemExit('Sony ELF kernel payload is not exactly zImage followed by the Hikari DTB')
if payload[len(zdata):len(zdata) + 4] != b'\xd0\x0d\xfe\xed':
    raise SystemExit('Sony ELF kernel payload lacks FDT magic at the appended-DTB boundary')
print('SONY_ELF_APPENDED_DTB=PASS')
PY
readelf -h "$output"
readelf -l "$output"
sha256sum "$output"
echo "local-only artifact: $output"
