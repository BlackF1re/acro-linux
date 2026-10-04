#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Read-only production source provenance gate; all changes belong in patches.
set -euo pipefail
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source "$repo_root/kernel/source.lock"
kernel_src=${1:-/home/paul/xperia/src/linux-hikari-current}
actual=$(git -C "$kernel_src" rev-parse 'HEAD^{tree}')
if [[ $actual != "$HIKARI_PREPARED_TREE" ]] ||
   ! git -C "$kernel_src" diff --quiet HEAD ||
   [[ -n $(git -C "$kernel_src" ls-files --others --exclude-standard) ]]; then
  echo "kernel source is not the clean locked patch result: $kernel_src" >&2
  echo 'Export/update the owning subsystem patch and verify the locked tree first.' >&2
  exit 1
fi
printf 'HIKARI_PATCH_ONLY_SOURCE=PASS tree=%s\n' "$actual"
