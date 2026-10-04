#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Reconstruct the Hikari kernel tree from a pinned Linus base plus the
# repository-owned subsystem patch series. No device
# access is performed.
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
lock="$repo_root/kernel/source.lock"
out=${1:-/home/paul/xperia/src/linux-hikari-materialized}

[[ -r $lock ]] || { echo "missing source lock: $lock" >&2; exit 1; }
# shellcheck disable=SC1090
source "$lock"
series="$repo_root/$PATCH_SERIES"
linux_source=${LINUX_SOURCE_CACHE:-$LINUX_REMOTE}

command -v git >/dev/null || { echo 'git is required' >&2; exit 1; }
[[ -r $series ]] || { echo "missing patch series: $series" >&2; exit 1; }

mapfile -t patches < <(sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "$series")
if (( ${#patches[@]} == 0 )); then
  echo 'Hikari patch series is empty.' >&2
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
git -C "$out" remote add upstream "$linux_source"
git -C "$out" fetch --no-tags --depth=1 upstream "$LINUX_BASE"
git -C "$out" checkout --detach FETCH_HEAD >/dev/null
git -C "$out" switch -c hikari >/dev/null

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

  # Imported patches normally carry blob identity, allowing git-am to recover
  # context through a three-way application when the pinned base moves.
  am_args=(--3way --keep-cr --committer-date-is-author-date)

  if ! git -C "$out" am "${am_args[@]}" "$patch"; then
    # Some project-exported patches intentionally lack a usable preimage blob
    # in their Index line.  In that case --3way cannot synthesize an ancestor,
    # even though the textual diff applies exactly to the pinned predecessor.
    # Retry without --3way; git-am still preserves the original mail author.
    git -C "$out" am --abort >/dev/null 2>&1 || true
    if ! git -C "$out" am --keep-cr --committer-date-is-author-date "$patch"; then
      echo "failed while applying $rel" >&2
      echo "inspect $out, then run: git -C '$out' am --abort" >&2
      exit 4
    fi
  fi
done

# All strict transform and integration results are now in the subsystem series.
# Their original scripts/exports remain available for historical provenance.

"$repo_root/scripts/check-msm8660-mmcc-source.sh" "$out"
python3 "$repo_root/scripts/check-hikari-display-source.py" "$out"
"$repo_root/scripts/check-hikari-as3676-source.sh" "$out"
"$repo_root/scripts/prepare-hikari-kernel-tree.sh" "$out"

"$repo_root/scripts/check-hikari-kernel-source.sh" "$out"

printf 'Hikari kernel materialized successfully.\n'
printf 'Base: %s\n' "$LINUX_BASE"
printf 'HEAD: %s\n' "$(git -C "$out" rev-parse HEAD)"
printf 'Tree: %s\n' "$out"
printf 'Imported patches: %d\n' "${#patches[@]}"
