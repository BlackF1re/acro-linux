#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Materialize the exact BusyBox source used by the Hikari diagnostic initramfs.
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
lock="$repo_root/initramfs/source.lock"
out=${1:-/home/paul/xperia/src/busybox-hikari-materialized}
[[ -r $lock ]] || { echo "missing BusyBox source lock: $lock" >&2; exit 1; }
# shellcheck disable=SC1090
source "$lock"

command -v git >/dev/null || { echo 'git is required' >&2; exit 1; }
if [[ -e $out ]]; then
  echo "refusing to overwrite existing BusyBox tree: $out" >&2
  exit 2
fi
mkdir -p "$(dirname -- "$out")"
git init "$out" >/dev/null
git -C "$out" remote add upstream "$BUSYBOX_REMOTE"
git -C "$out" fetch --no-tags --depth=1 upstream "$BUSYBOX_BASE"
git -C "$out" checkout --detach FETCH_HEAD >/dev/null
actual=$(git -C "$out" rev-parse HEAD)
[[ $actual == "$BUSYBOX_BASE" ]] || { echo "BusyBox source mismatch: $actual" >&2; exit 3; }
printf 'Hikari BusyBox materialized successfully.\nBase: %s\nTree: %s\n' "$actual" "$out"
