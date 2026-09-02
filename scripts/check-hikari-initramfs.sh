#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Validate the archive that is actually embedded into a Hikari boot artifact.
set -euo pipefail

archive=${1:?usage: check-hikari-initramfs.sh INITRAMFS.cpio.gz}
test -f "$archive"

listing=$(gzip -cd -- "$archive" | cpio -itv 2>/dev/null)
for path in init bin/sh bin/mount bin/sleep bin/setsid bin/cttyhack bin/mkdir bin/cat bin/echo \
            dev proc sys; do
  printf '%s\n' "$listing" | grep -Eq "[[:space:]]${path}( |$| ->)" || {
    echo "Hikari initramfs missing $path" >&2
    exit 1
  }
done
printf '%s\n' "$listing" | grep -Eq '^crw-------.* dev/console$' || {
  echo 'Hikari initramfs has no c 5:1 /dev/console' >&2
  exit 1
}
printf '%s\n' "$listing" | grep -Eq '^crw-rw-rw-.* dev/null$' || {
  echo 'Hikari initramfs has no c 1:3 /dev/null' >&2
  exit 1
}

echo 'HIKARI_INITRAMFS_LAYOUT=PASS'
