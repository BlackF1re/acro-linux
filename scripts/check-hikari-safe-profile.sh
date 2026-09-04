#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Static gate for the fallback DTB that keeps the verified USB console path
# while deliberately suppressing experimental multimedia probing.
set -euo pipefail

usage() {
  echo "usage: $0 --config PATH --dtb PATH" >&2
  exit 2
}

config=
dtb=
while (($#)); do
  case "$1" in
    --config) config=${2:?}; shift 2 ;;
    --dtb) dtb=${2:?}; shift 2 ;;
    *) usage ;;
  esac
done
[[ -f $config && -f $dtb ]] || usage
command -v fdtget >/dev/null || { echo 'fdtget is required' >&2; exit 1; }

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

# First prove that the fallback did not damage the known-good USB gadget and
# persistent diagnostic foundation.
"$repo_root/scripts/check-hikari-boot5-interactive.sh" --config "$config" --dtb "$dtb"
"$repo_root/scripts/check-hikari-persistent-ram.sh" --config "$config" --dtb "$dtb"

for path in \
  /clock-controller@4000000 \
  /display-controller@5100000 \
  /dsi@4700000 \
  /dsi-phy@47000f0 \
  /interconnect-afab \
  /interconnect-sfab \
  /interconnect-mmfab \
  /interconnect-dfab; do
  state=$(fdtget "$dtb" "$path" status 2>/dev/null || true)
  [[ $state == disabled ]] || {
    echo "HIKARI_SAFE_PROFILE=FAIL $path status=${state:-missing}" >&2
    exit 1
  }
done

# The LCD sink is on GSBI8 and its absolute path is inherited from the common
# SoC description, so locate it by its unique unit-address/name rather than
# baking another bus path into this gate.
dts=$(mktemp)
trap 'rm -f "$dts"' EXIT
dtc -q -I dtb -O dts "$dtb" > "$dts"
python3 - "$dts" <<'PY'
from pathlib import Path
import re
import sys

text = Path(sys.argv[1]).read_text()
match = re.search(r'backlight@40\s*\{(?P<body>.*?)\n\s*\};', text, re.S)
if not match:
    raise SystemExit('HIKARI_SAFE_PROFILE=FAIL backlight@40 node missing')
body = match.group('body')
if not re.search(r'status\s*=\s*"disabled"\s*;', body):
    raise SystemExit('HIKARI_SAFE_PROFILE=FAIL backlight@40 is not disabled')
PY

echo 'HIKARI_SAFE_PROFILE=PASS'
echo 'usb=retained; ramoops=retained; mmcc/mdp/dsi/phy/backlight/multimedia-fabrics=disabled'
