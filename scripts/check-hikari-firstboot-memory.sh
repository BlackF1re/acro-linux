#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Offline-only first-boot range gate.  It never invokes a device transport.
set -euo pipefail

kernel_build=
zimage=
dtb=
ramdisk=
ramdisk_addr=
rpm=

while [[ $# -gt 0 ]]; do
  case "$1" in
    --kernel-build) kernel_build=$2; shift 2 ;;
    --zimage) zimage=$2; shift 2 ;;
    --dtb) dtb=$2; shift 2 ;;
    --ramdisk) ramdisk=$2; shift 2 ;;
    --ramdisk-addr) ramdisk_addr=$2; shift 2 ;;
    --rpm) rpm=$2; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

for value in "$kernel_build" "$zimage" "$dtb" "$ramdisk" "$ramdisk_addr" "$rpm"; do
  [[ -n "$value" ]] || { echo "missing required argument" >&2; exit 2; }
done
for input in "$kernel_build/.config" "$kernel_build/vmlinux" "$zimage" "$dtb" "$ramdisk" "$rpm"; do
  [[ -f "$input" ]] || { echo "missing offline input: $input" >&2; exit 1; }
done

config=$kernel_build/.config
grep -qx 'CONFIG_PHYS_OFFSET=0x40200000' "$config" || { echo "PHYS_OFFSET is not the verified Hikari RAM base" >&2; exit 1; }
grep -qx '# CONFIG_ARCH_MULTIPLATFORM is not set' "$config" || { echo "ARCH_MULTIPLATFORM must be disabled to make the explicit decompressor address effective" >&2; exit 1; }
grep -qx '# CONFIG_AUTO_ZRELADDR is not set' "$config" || { echo "AUTO_ZRELADDR must be disabled for this unaligned RAM base" >&2; exit 1; }
grep -qx 'CONFIG_PAGE_OFFSET=0xC0000000' "$config" || { echo "unexpected PAGE_OFFSET" >&2; exit 1; }

python3 - "$kernel_build/vmlinux" "$zimage" "$dtb" "$ramdisk" "$ramdisk_addr" "$rpm" <<'PY'
import subprocess
import sys

vmlinux, zimage, dtb, ramdisk, ramdisk_addr, rpm = sys.argv[1:]
def size(path):
    with open(path, 'rb') as f:
        f.seek(0, 2)
        return f.tell()
def symbol(name):
    out = subprocess.check_output(['nm', '-n', vmlinux], text=True)
    for line in out.splitlines():
        fields = line.split()
        if len(fields) == 3 and fields[2] == name:
            return int(fields[0], 16)
    raise SystemExit(f'missing {name} in vmlinux')
def show(name, start, length):
    end = start + length
    print(f'{name}: 0x{start:08x}-0x{end - 1:08x} ({length} bytes)')
    return start, end

ram_start, ram_end = 0x40200000, 0x42e00000
kernel_load = 0x40208000
page_offset = 0xc0000000
kernel_end = kernel_load + (symbol('_end') - page_offset)
z_end = kernel_load + size(zimage)
dtb_end = z_end + size(dtb)
ramdisk_start = int(ramdisk_addr, 0)
ramdisk_end = ramdisk_start + size(ramdisk)
rpm_start = 0x00020000
rpm_end = rpm_start + size(rpm)

assert kernel_load == ram_start + 0x8000
for name, start, end in (
    ('zImage input', kernel_load, z_end),
    ('appended DTB input', z_end, dtb_end),
    ('decompressed kernel', kernel_load, kernel_end),
    ('initramfs', ramdisk_start, ramdisk_end),
):
    if not (ram_start <= start < end <= ram_end):
        raise SystemExit(f'{name} is outside verified first RAM bank')
show('zImage input', kernel_load, size(zimage))
show('appended DTB input', z_end, size(dtb))
show('decompressed kernel', kernel_load, kernel_end - kernel_load)
show('initramfs', ramdisk_start, size(ramdisk))
show('RPM payload', rpm_start, size(rpm))
if rpm_end > ram_start:
    raise SystemExit('RPM payload unexpectedly reaches System RAM')
if kernel_end > ramdisk_start:
    raise SystemExit('decompressed kernel overlaps initramfs')

# head.S permits up to 1 MiB appended-DTB working space; conservatively keep
# that whole interval clear before the initramfs too.
workspace_end = kernel_end + 1024 * 1024
show('conservative decompressor/DTB workspace reserve', kernel_end, workspace_end - kernel_end)
if workspace_end > ramdisk_start:
    raise SystemExit('conservative decompressor/DTB workspace overlaps initramfs')
if ramdisk_end > ram_end:
    raise SystemExit('initramfs exceeds verified first RAM bank')
print('FIRST_BOOT_MEMORY_SAFETY=PASS')
PY
