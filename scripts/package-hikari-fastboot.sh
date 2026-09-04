#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Build a validated Sony ELF32 boot artifact from already-built inputs.
# This tool is deliberately offline-only: it never calls fastboot, adb or any
# other device transport.
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
usage: package-hikari-fastboot.sh \
  --kernel-build DIR --zimage FILE --dtb FILE --ramdisk FILE --rpm FILE \
  --output FILE [--ramdisk-addr 0x42a00000]
EOF
  exit 2
}

kernel_build=
zimage=
dtb=
ramdisk=
rpm=
output=
ramdisk_addr=0x42a00000
kernel_addr=0x40208000
rpm_addr=0x00020000
limit=$((20 * 1024 * 1024))
while (($#)); do
  case "$1" in
    --kernel-build) kernel_build=${2:?}; shift 2 ;;
    --zimage) zimage=${2:?}; shift 2 ;;
    --dtb) dtb=${2:?}; shift 2 ;;
    --ramdisk) ramdisk=${2:?}; shift 2 ;;
    --rpm) rpm=${2:?}; shift 2 ;;
    --output) output=${2:?}; shift 2 ;;
    --ramdisk-addr) ramdisk_addr=${2:?}; shift 2 ;;
    *) usage ;;
  esac
done
for value in "$kernel_build" "$zimage" "$dtb" "$ramdisk" "$rpm" "$output"; do
  [[ -n $value ]] || usage
done
for input in "$kernel_build/.config" "$kernel_build/vmlinux" "$zimage" "$dtb" "$ramdisk" "$rpm"; do
  [[ -f $input ]] || { echo "missing packaging input: $input" >&2; exit 1; }
done
[[ ! -e $output ]] || { echo "refusing to overwrite artifact: $output" >&2; exit 1; }

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
out_dir=$(dirname -- "$output")
mkdir -p "$out_dir"
appended=$(mktemp --tmpdir="$out_dir" .hikari-appended-dtb.XXXXXX)
trap 'rm -f "$appended"' EXIT
cat "$zimage" "$dtb" > "$appended"

# Reject an accidental non-DTB tail before constructing the ELF.
python3 - "$dtb" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
data = p.read_bytes()
if len(data) < 40 or data[:4] != b'\xd0\x0d\xfe\xed':
    raise SystemExit('DTB does not start with the FDT magic')
PY

# The exact RPM segment remains an explicit caller-owned input.  Validate that
# it at least has the legacy ARM ELF shape before embedding it; this does not
# make any redistribution claim about the binary.
python3 "$repo_root/tools/sony_elf.py" inspect "$rpm" >/dev/null

"$repo_root/scripts/check-hikari-firstboot-memory.sh" \
  --kernel-build "$kernel_build" \
  --zimage "$zimage" \
  --dtb "$dtb" \
  --ramdisk "$ramdisk" \
  --ramdisk-addr "$ramdisk_addr" \
  --kernel-load "$kernel_addr" \
  --rpm "$rpm"

python3 "$repo_root/tools/sony_elf.py" build \
  --kernel "$appended" \
  --ramdisk "$ramdisk" \
  --rpm "$rpm" \
  --output "$output" \
  --kernel-addr "$kernel_addr" \
  --ramdisk-addr "$ramdisk_addr" \
  --rpm-addr "$rpm_addr" \
  --limit "$limit"

# Verify that segment zero is byte-for-byte zImage+DTB, rather than trusting
# only the builder invocation.
python3 - "$output" "$appended" <<'PY'
from pathlib import Path
import struct
import sys
elf = Path(sys.argv[1]).read_bytes()
expected = Path(sys.argv[2]).read_bytes()
header = struct.Struct('<16sHHIIIIIHHHHHH')
ph = struct.Struct('<IIIIIIII')
fields = header.unpack_from(elf)
phoff, phentsize, phnum = fields[5], fields[9], fields[10]
loads = []
for i in range(phnum):
    ent = ph.unpack_from(elf, phoff + i * phentsize)
    if ent[0] == 1:
        loads.append(ent)
if len(loads) != 3:
    raise SystemExit(f'expected exactly 3 PT_LOAD segments, got {len(loads)}')
_, off, _, paddr, filesz, _, flags, _ = loads[0]
if paddr != 0x40208000 or flags != 0 or elf[off:off + filesz] != expected:
    raise SystemExit('kernel PT_LOAD does not match the requested zImage+DTB')
PY

sha256sum "$output"
echo "fastboot Sony ELF: $output"
echo 'NOTE: packaging succeeded only; this script did not access or flash a device.'
