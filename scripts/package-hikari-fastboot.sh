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
  --output FILE [--ramdisk-addr 0x42c10000]
EOF
  exit 2
}

kernel_build=
zimage=
dtb=
ramdisk=
rpm=
output=
ramdisk_addr=0x42c10000
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
[[ -s $rpm ]] || { echo "RPM payload is empty: $rpm" >&2; exit 1; }
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

# The p3-derived rpm.segment used by the verified Hikari boot chain is the raw
# bytes of the legacy RPM PT_LOAD payload, not a standalone ELF file.  Do not
# mis-detect it with sony_elf.py inspect.  The range gate below validates that
# the raw payload fits at the verified 0x00020000 load address, and the final
# ELF verifier requires exactly three PT_LOAD segments after packaging.
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
# only the builder invocation. Also verify all three load addresses so a raw
# RPM input can never silently land in the wrong Sony ELF segment.
python3 - "$output" "$appended" "$ramdisk" "$rpm" <<'PY'
from pathlib import Path
import struct
import sys
elf = Path(sys.argv[1]).read_bytes()
expected_kernel = Path(sys.argv[2]).read_bytes()
expected_ramdisk = Path(sys.argv[3]).read_bytes()
expected_rpm = Path(sys.argv[4]).read_bytes()
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
expected = {
    0x40208000: expected_kernel,
    0x42c10000: expected_ramdisk,
    0x00020000: expected_rpm,
}
for ent in loads:
    _, off, _, paddr, filesz, _, _, _ = ent
    payload = elf[off:off + filesz]
    if paddr not in expected:
        raise SystemExit(f'unexpected PT_LOAD physical address 0x{paddr:08x}')
    if payload != expected[paddr]:
        raise SystemExit(f'PT_LOAD payload mismatch at 0x{paddr:08x}')
PY

sha256sum "$output"
echo "fastboot Sony ELF: $output"
echo 'NOTE: packaging succeeded only; this script did not access or flash a device.'
