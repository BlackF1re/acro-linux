#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Reconstruct the Hikari kernel tree from a pinned Linus base plus the
# repository-owned patch series. No device access is performed.
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
lock="$repo_root/kernel/source.lock"
out=${1:-/home/paul/xperia/src/linux-hikari-materialized}

[[ -r $lock ]] || { echo "missing source lock: $lock" >&2; exit 1; }
# shellcheck disable=SC1090
source "$lock"
series="$repo_root/$PATCH_SERIES"

command -v git >/dev/null || { echo 'git is required' >&2; exit 1; }
[[ -r $series ]] || { echo "missing patch series: $series" >&2; exit 1; }

mapfile -t patches < <(sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$series")
if (( ${#patches[@]} == 0 )); then
  echo 'Hikari patch series is empty.' >&2
  echo 'Import the historical worktree with scripts/export-hikari-kernel-patches.sh first.' >&2
  exit 2
fi

if [[ -e $out ]]; then
  if [[ ! -d $out/.git ]]; then
    echo "output exists and is not a git worktree: $out" >&2
    exit 1
  fi
  if [[ -n $(git -C "$out" status --porcelain=v1 --untracked-files=all) ]]; then
    echo "refusing to reuse dirty output worktree: $out" >&2
    exit 1
  fi
  current=$(git -C "$out" rev-parse HEAD)
  echo "output worktree already exists at $current; refusing implicit reset" >&2
  echo 'remove it explicitly or choose a different output path' >&2
  exit 3
fi

mkdir -p "$(dirname -- "$out")"
git init "$out" >/dev/null
git -C "$out" remote add upstream "$LINUX_REMOTE"
git -C "$out" fetch --no-tags --depth=1 upstream "$LINUX_BASE"
git -C "$out" checkout --detach FETCH_HEAD >/dev/null
git -C "$out" switch -c hikari >/dev/null

# git-am needs a committer identity even though every mail patch carries its
# own author. Keep the identity and committer date deterministic so repeated
# materializations produce the same reconstructed commit IDs.
git -C "$out" config user.name "Hikari Patch Materializer"
git -C "$out" config user.email "hikari-materializer@localhost"

for rel in "${patches[@]}"; do
  patch="$repo_root/kernel/patches/$rel"
  [[ -r $patch ]] || {
    echo "series references missing patch: $patch" >&2
    git -C "$out" am --abort >/dev/null 2>&1 || true
    exit 1
  }
  echo "Applying $rel"
  if ! git -C "$out" am --3way --keep-cr --committer-date-is-author-date "$patch"; then
    echo "failed while applying $rel" >&2
    echo "inspect $out, then run: git -C '$out' am --abort" >&2
    exit 4
  fi
done

# Fail closed on known MSM8x60 MMCC transcription regressions before board DT
# preparation or any expensive build. The rules are exact Sony/CAF hardware
# mappings, not Hikari-specific guesses.
"$repo_root/scripts/check-msm8660-mmcc-source.sh" "$out"

# The project DTS intentionally remains project-owned instead of becoming a
# permanent fork-only board file. Apply the idempotent DT/schema preparation
# after reconstructing and validating the kernel commit stack.
"$repo_root/scripts/prepare-hikari-kernel-tree.sh" "$out"

printf 'Hikari kernel materialized successfully.\n'
printf 'Base: %s\n' "$LINUX_BASE"
printf 'HEAD: %s\n' "$(git -C "$out" rev-parse HEAD)"
printf 'Tree: %s\n' "$out"
printf 'Patches: %d\n' "${#patches[@]}"
