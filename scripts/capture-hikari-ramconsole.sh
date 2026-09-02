#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Read-only capture of the Hikari legacy ram_console physical range from TWRP.
set -euo pipefail
umask 077

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
private_root=/home/paul/xperia/research/private/hikari-recovery-debug
output_dir=${OUTPUT_DIR:-$private_root}
base=0x7ffe0000
bytes=131072
words=$((bytes / 4))

case "$output_dir" in
  "$private_root"|"$private_root"/*) ;;
  *) echo "OUTPUT_DIR must remain below $private_root" >&2; exit 1 ;;
esac
command -v adb >/dev/null || { echo "adb is required" >&2; exit 1; }
[[ "$(adb get-state 2>/dev/null || true)" == device ]] || {
  echo "ADB transport is not ready; this script does not select a device" >&2
  exit 1
}
adb shell '[ -c /dev/mem ] && command -v busybox >/dev/null' >/dev/null || {
  echo "TWRP must expose /dev/mem and busybox" >&2; exit 1;
}

mkdir -p "$output_dir"
stamp=$(date -u +%Y%m%dT%H%M%SZ)
raw="$output_dir/ram-console-$stamp.bin"
text="$output_dir/ram-console-$stamp.txt"
words_file="$output_dir/.ram-console-$stamp.words"
[[ ! -e "$raw" && ! -e "$text" && ! -e "$words_file" ]] || {
  echo "refusing to overwrite an existing capture" >&2; exit 1;
}
trap 'rm -f -- "$words_file"' EXIT

# TWRP's dd read() returns Bad address for this reserved range.  busybox
# devmem performs the same read-only 32-bit accesses; 32768 words is exactly
# 0x20000 bytes and no other physical range is addressed.
adb shell "i=0; while [ \"\$i\" -lt $words ]; do busybox devmem \$(( $base + i * 4 )) 32; i=\$((i + 1)); done" > "$words_file"
[[ "$(wc -l < "$words_file")" -eq "$words" ]] || {
  echo "incomplete /dev/mem word capture" >&2; exit 1;
}
python3 - "$words_file" "$raw" <<'PY'
import re
import struct
import sys

words = []
for line in open(sys.argv[1], encoding="ascii"):
    text = line.strip()
    if not re.fullmatch(r"0x[0-9a-fA-F]{1,8}", text):
        raise SystemExit(f"unexpected devmem output: {text!r}")
    words.append(int(text, 16))
if len(words) != 32768:
    raise SystemExit(f"expected 32768 words, got {len(words)}")
open(sys.argv[2], "wb").write(struct.pack("<32768I", *words))
PY
[[ "$(stat -c %s "$raw")" -eq "$bytes" ]] || {
  echo "raw capture has an unexpected size" >&2; exit 1;
}
sha256sum "$raw"
python3 "$repo_root/tools/hikari-persistent-ram.py" "$raw" --output "$text"
sha256sum "$text"
echo "read-only ram_console capture: $raw"
