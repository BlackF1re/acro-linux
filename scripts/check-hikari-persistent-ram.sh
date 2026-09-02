#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Offline-only gate for the temporary Hikari early-boot persistent console.
set -euo pipefail

config=
dtb=
while [[ $# -gt 0 ]]; do
  case "$1" in
    --config) config=$2; shift 2 ;;
    --dtb) dtb=$2; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

[[ -f "$config" && -f "$dtb" ]] || {
  echo "--config and --dtb must name regular files" >&2
  exit 2
}
command -v fdtget >/dev/null || {
  echo "fdtget is required to validate the built DTB" >&2
  exit 1
}

for required in CONFIG_PSTORE=y CONFIG_PSTORE_RAM=y CONFIG_PSTORE_CONSOLE=y; do
  grep -qx "$required" "$config" || {
    echo "persistent diagnostics lacks $required" >&2
    exit 1
  }
done
grep -qx '# CONFIG_PSTORE_COMPRESS is not set' "$config" || {
  echo "compressed pstore is not part of the console-only boot #4 design" >&2
  exit 1
}

node=/reserved-memory/ramoops@7ffe0000
[[ "$(fdtget -t s "$dtb" "$node" compatible)" == ramoops ]] || {
  echo "ramoops compatible is missing from $node" >&2
  exit 1
}
[[ "$(fdtget -t x "$dtb" "$node" reg)" == "7ffe0000 20000" ]] || {
  echo "ramoops reg must be 0x7ffe0000/0x20000" >&2
  exit 1
}
[[ "$(fdtget -t x "$dtb" "$node" console-size)" == 20000 ]] || {
  echo "ramoops console-size must consume the full 0x20000 region" >&2
  exit 1
}
[[ "$(fdtget -t x "$dtb" "$node" ecc-size)" == 0 ]] || {
  echo "ramoops ecc-size must remain zero for legacy TWRP compatibility" >&2
  exit 1
}
if fdtget "$dtb" "$node" no-map >/dev/null 2>&1; then
  echo "ramoops must not use no-map: the console writer needs the mapping" >&2
  exit 1
fi

echo "HIKARI_PERSISTENT_RAM=PASS"
echo "ramoops=0x7ffe0000+0x20000 console-only ecc=0"
