#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# One-time importer for the historical external Hikari kernel worktree.
# It never commits, pushes, rebases, resets or modifies the source worktree.
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
kernel_src=${1:-/home/paul/xperia/src/linux}
lock="$repo_root/kernel/source.lock"
patch_dir="$repo_root/kernel/patches"
series="$patch_dir/series"
manifest="$patch_dir/original-history.tsv"

[[ -r $lock ]] || { echo "missing source lock: $lock" >&2; exit 1; }
# shellcheck disable=SC1090
source "$lock"

command -v git >/dev/null || { echo 'git is required' >&2; exit 1; }
git -C "$kernel_src" rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "not a git worktree: $kernel_src" >&2
  exit 1
}

status=$(git -C "$kernel_src" status --porcelain=v1 --untracked-files=all)
if [[ -n $status ]]; then
  echo 'Refusing to export a dirty kernel worktree.' >&2
  printf '%s\n' "$status" >&2
  exit 2
fi

git -C "$kernel_src" cat-file -e "$LINUX_BASE^{commit}" 2>/dev/null || {
  echo "pinned base $LINUX_BASE is not present in $kernel_src" >&2
  exit 1
}
head=$(git -C "$kernel_src" rev-parse HEAD)
git -C "$kernel_src" merge-base --is-ancestor "$LINUX_BASE" "$head" || {
  echo "pinned base $LINUX_BASE is not an ancestor of HEAD $head" >&2
  exit 1
}

count=$(git -C "$kernel_src" rev-list --count "$LINUX_BASE..$head")
if (( count == 0 )); then
  echo "no commits exist above pinned base $LINUX_BASE" >&2
  exit 1
fi

mkdir -p "$patch_dir"
if find "$patch_dir" -maxdepth 1 -type f -name '*.patch' -print -quit | grep -q .; then
  echo "refusing to overwrite existing patch files in $patch_dir" >&2
  exit 3
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# --full-index/--binary keeps exact textual/binary diffs.  format-patch carries
# authorship, dates, subjects, bodies and trailers; git-am recreates that
# authored history on the pinned base without needing the old worktree.
git -C "$kernel_src" format-patch \
  --full-index --binary --no-signature --output-directory "$tmp" \
  "$LINUX_BASE..$head" >/dev/null

mapfile -t patches < <(find "$tmp" -maxdepth 1 -type f -name '*.patch' -printf '%f\n' | sort)
if (( ${#patches[@]} != count )); then
  echo "expected $count patches, generated ${#patches[@]}" >&2
  exit 1
fi

for name in "${patches[@]}"; do
  install -m 0644 "$tmp/$name" "$patch_dir/$name"
done

{
  echo '# Canonical Hikari kernel patch application order.'
  echo '# Generated from the historical external kernel worktree.'
  for name in "${patches[@]}"; do
    printf '%s\n' "$name"
  done
} > "$series"

{
  printf 'original_sha\tauthor_name\tauthor_email\tauthor_date\tsubject\n'
  git -C "$kernel_src" log --reverse \
    --format='%H%x09%an%x09%ae%x09%aI%x09%s' "$LINUX_BASE..$head"
} > "$manifest"

cat > "$patch_dir/export-metadata.txt" <<EOF
source_worktree=$kernel_src
linux_base=$LINUX_BASE
original_head=$head
commit_count=$count
exported_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF

printf 'Exported %d commits from %s..%s\n' "$count" "$LINUX_BASE" "$head"
printf 'Patch series: %s\n' "$series"
printf 'History map:  %s\n' "$manifest"
printf '%s\n' 'No source-tree commits, refs or files were modified.'
printf '%s\n' 'Review the generated files, then commit them in acro-linux.'
