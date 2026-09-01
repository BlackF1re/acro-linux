#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Offline-only Hikari boot-range gate.  It never invokes a device transport.
#
# The name is retained because earlier first-boot tooling calls it.  Its model
# is deliberately based on the current ARM compressed/head.S relocation path,
# rather than rejecting every source/destination overlap outright.
set -euo pipefail

kernel_build=
zimage=
dtb=
ramdisk=
ramdisk_addr=
kernel_load=
rpm=

while [[ $# -gt 0 ]]; do
  case "$1" in
    --kernel-build) kernel_build=$2; shift 2 ;;
    --zimage) zimage=$2; shift 2 ;;
    --dtb) dtb=$2; shift 2 ;;
    --ramdisk) ramdisk=$2; shift 2 ;;
    --ramdisk-addr) ramdisk_addr=$2; shift 2 ;;
    --kernel-load) kernel_load=$2; shift 2 ;;
    --rpm) rpm=$2; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

for value in "$kernel_build" "$zimage" "$dtb" "$ramdisk" "$ramdisk_addr" "$kernel_load" "$rpm"; do
  [[ -n "$value" ]] || { echo "missing required argument" >&2; exit 2; }
done
for input in "$kernel_build/.config" "$kernel_build/vmlinux" \
  "$kernel_build/arch/arm/boot/compressed/vmlinux" "$zimage" "$dtb" "$ramdisk" "$rpm"; do
  [[ -f "$input" ]] || { echo "missing offline input: $input" >&2; exit 1; }
done

config=$kernel_build/.config
grep -qx 'CONFIG_PHYS_OFFSET=0x40000000' "$config" || { echo "PHYS_OFFSET is not the MSM8x60 physical RAM-base candidate" >&2; exit 1; }
grep -qx '# CONFIG_ARCH_MULTIPLATFORM is not set' "$config" || { echo "ARCH_MULTIPLATFORM must be disabled to make the explicit decompressor address effective" >&2; exit 1; }
grep -qx '# CONFIG_AUTO_ZRELADDR is not set' "$config" || { echo "AUTO_ZRELADDR must be disabled for this unaligned RAM base" >&2; exit 1; }
grep -qx 'CONFIG_ARCH_QCOM_RESERVE_SMEM=y' "$config" || { echo "ARCH_QCOM_RESERVE_SMEM is required by upstream for MSM8x60; rebuild before deployment" >&2; exit 1; }
grep -qx 'CONFIG_ARM_APPENDED_DTB=y' "$config" || { echo "ARM_APPENDED_DTB is required by the selected Hikari boot strategy" >&2; exit 1; }
grep -qx 'CONFIG_ARM_ATAG_DTB_COMPAT=y' "$config" || { echo "ARM_ATAG_DTB_COMPAT is required for the legacy S1Boot compatibility strategy" >&2; exit 1; }
grep -qx 'CONFIG_PAGE_OFFSET=0xC0000000' "$config" || { echo "unexpected PAGE_OFFSET" >&2; exit 1; }

python3 - "$kernel_build/vmlinux" "$kernel_build/arch/arm/boot/compressed/vmlinux" \
  "$zimage" "$dtb" "$ramdisk" "$ramdisk_addr" "$kernel_load" "$rpm" <<'PY'
import subprocess
import sys

vmlinux, compressed, zimage, dtb, ramdisk, ramdisk_addr, kernel_load, rpm = sys.argv[1:]

def size(path):
    with open(path, 'rb') as f:
        f.seek(0, 2)
        return f.tell()

def symbols(path):
    out = subprocess.check_output(['nm', '-n', path], text=True)
    result = {}
    for line in out.splitlines():
        fields = line.split()
        if len(fields) == 3:
            result[fields[2]] = int(fields[0], 16)
    return result

def align(value, boundary):
    return (value + boundary - 1) & -boundary

def show(name, start, end):
    if end <= start:
        raise SystemExit(f'invalid {name} range')
    print(f'{name}: 0x{start:08x}-0x{end - 1:08x} ({end - start} bytes)')

def overlap(a, b):
    return a[0] < b[1] and b[0] < a[1]

ram_start, ram_end = 0x40000000, 0x42e00000
smem_end = ram_start + 0x00200000
page_offset = 0xc0000000
zimage_load = int(kernel_load, 0)
ramdisk_start = int(ramdisk_addr, 0)
rpm_start = 0x00020000

# ARCH_QCOM_RESERVE_SMEM selects TEXT_OFFSET=0x00208000 in the pinned
# upstream ARM Makefile.  That is 2 MiB plus 32 KiB after the physical
# MSM8x60 RAM base.  A different address needs a separately reviewed model.
expected_load = smem_end + 0x8000
if zimage_load != expected_load:
    raise SystemExit(
        f'kernel load 0x{zimage_load:08x} is not the SMEM-safe expected '
        f'address 0x{expected_load:08x}'
    )

main = symbols(vmlinux)
comp = symbols(compressed)
for name in ('_end',):
    if name not in main:
        raise SystemExit(f'missing {name} in vmlinux')
for name in ('restart', 'reloc_code_end', '_edata', '_end'):
    if name not in comp:
        raise SystemExit(f'missing {name} in compressed vmlinux')

kernel_end = zimage_load + (main['_end'] - page_offset)
zimage_end = zimage_load + size(zimage)
dtb_end = zimage_end + size(dtb)
ramdisk_end = ramdisk_start + size(ramdisk)
rpm_end = rpm_start + size(rpm)

# In arch/arm/boot/compressed/head.S, when the final uncompressed image would
# overwrite the executing zImage, the code copies its restart..r6 interval to
# immediately after the final image. r6 is extended by appended DTB bytes.
# The 256-byte-aligned relocation code reserve matches the head.S arithmetic;
# retain an extra 128 KiB for its local BSS/stack/malloc safety margin.
restart = comp['restart']
reloc_reserve = align(comp['reloc_code_end'] - restart, 256)
relocated_start = align(kernel_end + reloc_reserve, 256)
relocated_end = relocated_start + (dtb_end - (zimage_load + restart)) + 128 * 1024

ranges = {
    'Qualcomm SMEM reserve': (ram_start, smem_end),
    'compressed zImage input': (zimage_load, zimage_end),
    'appended DTB input': (zimage_end, dtb_end),
    'decompressed kernel': (zimage_load, kernel_end),
    'relocated decompressor + appended DTB': (relocated_start, relocated_end),
    'initramfs': (ramdisk_start, ramdisk_end),
    'RPM payload': (rpm_start, rpm_end),
}

if zimage_load < smem_end:
    raise SystemExit('compressed zImage begins in the mandatory MSM8x60 SMEM reserve')
for name in ('compressed zImage input', 'appended DTB input', 'decompressed kernel',
             'relocated decompressor + appended DTB', 'initramfs'):
    start, end = ranges[name]
    if not (smem_end <= start < end <= ram_end):
        raise SystemExit(f'{name} is not wholly inside the modeled first RAM bank outside SMEM')
if rpm_end > ram_start:
    raise SystemExit('RPM payload unexpectedly reaches System RAM')

# The source image overlaps its final output on purpose.  Current ARM
# compressed/head.S implements a backwards self-relocation before inflate;
# validate the *relocated* runtime range against the other payloads.
if not overlap(ranges['compressed zImage input'], ranges['decompressed kernel']):
    raise SystemExit('unexpected layout: expected zImage/decompressed-kernel overlap was not observed')
for left, right in (
    ('relocated decompressor + appended DTB', 'initramfs'),
    ('relocated decompressor + appended DTB', 'Qualcomm SMEM reserve'),
    ('decompressed kernel', 'initramfs'),
    ('appended DTB input', 'initramfs'),
):
    if overlap(ranges[left], ranges[right]):
        raise SystemExit(f'{left} overlaps {right}')

for name in ('Qualcomm SMEM reserve', 'compressed zImage input', 'appended DTB input',
             'decompressed kernel', 'relocated decompressor + appended DTB', 'initramfs',
             'RPM payload'):
    show(name, *ranges[name])
print(f'compressed relocation reserve: {reloc_reserve} bytes')
print('ARM_ZIMAGE_SELF_RELOCATION=REQUIRED_AND_ACCOUNTED_FOR')
print('THIRD_BOOT_MEMORY_SAFETY=PASS')
PY
