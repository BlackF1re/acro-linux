#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Fetch only the redistributable upstream linux-firmware files required by
# Adreno A220.  The release tag is pinned in firmware/a220/source.lock.
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
out=${1:-${HIKARI_BUILD_ROOT:-/home/paul/xperia/build}/hikari-a220-firmware-current}
# shellcheck source=/dev/null
source "$repo_root/firmware/a220/source.lock"

[[ $LINUX_FIRMWARE_REF != main && -n $LINUX_FIRMWARE_REF ]] || {
  echo 'refusing an unpinned linux-firmware ref' >&2
  exit 1
}
mkdir -p "$out"
out=$(realpath -m -- "$out")

for rel in $A220_FIRMWARE_FILES; do
  dest="$out/$rel"
  mkdir -p "$(dirname -- "$dest")"
  case "$rel" in
    qcom/leia_pm4_470.fw) expected=$A220_PM4_SHA256 ;;
    qcom/leia_pfp_470.fw) expected=$A220_PFP_SHA256 ;;
    *) echo "missing locked digest for $rel" >&2; exit 1 ;;
  esac
  if [[ -s $dest ]] && printf '%s  %s\n' "$expected" "$dest" | sha256sum -c - >/dev/null; then
    continue
  fi
  url="$LINUX_FIRMWARE_RAW/$LINUX_FIRMWARE_REF/$rel"
  python3 - "$url" "$dest" <<'PY'
from pathlib import Path
import sys
import tempfile
import urllib.request

url, dst = sys.argv[1], Path(sys.argv[2])
req = urllib.request.Request(url, headers={"User-Agent": "acro-linux-hikari-build/1"})
with urllib.request.urlopen(req, timeout=60) as r:
    data = r.read()
if len(data) < 256:
    raise SystemExit(f"firmware payload unexpectedly short: {url} ({len(data)} bytes)")
with tempfile.NamedTemporaryFile(dir=dst.parent, delete=False) as f:
    f.write(data)
    tmp = Path(f.name)
tmp.chmod(0o644)
tmp.replace(dst)
PY
done

printf '%s  %s\n' "$A220_PM4_SHA256" "$out/qcom/leia_pm4_470.fw" | sha256sum -c -
printf '%s  %s\n' "$A220_PFP_SHA256" "$out/qcom/leia_pfp_470.fw" | sha256sum -c -
echo "A220_FIRMWARE=PASS ref=$LINUX_FIRMWARE_REF dir=$out"
