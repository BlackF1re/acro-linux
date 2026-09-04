#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Reconstruct the Hikari kernel tree from a pinned Linus base plus the
# repository-owned patch series and strict project corrections. No device
# access is performed.
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

# Project correction #37 is expressed as a strict source transform instead of
# a hand-authored mail patch. The transform aborts unless every historical
# value is exactly the one verified in the imported v1 source, then we record
# the result as a deterministic kernel commit.
python3 "$repo_root/scripts/apply-msm8660-mmcc-corrections.py" "$out"
git -C "$out" add drivers/clk/qcom/mmcc-msm8660.c
if git -C "$out" diff --cached --quiet; then
  echo 'MMCC correction produced no diff; refusing ambiguous materialization' >&2
  exit 5
fi
GIT_AUTHOR_NAME=BlackF1re \
GIT_AUTHOR_EMAIL=55582873+BlackF1re@users.noreply.github.com \
GIT_AUTHOR_DATE=2026-09-04T20:30:00+03:00 \
GIT_COMMITTER_NAME="Hikari Patch Materializer" \
GIT_COMMITTER_EMAIL=hikari-materializer@localhost \
GIT_COMMITTER_DATE=2026-09-04T20:30:00+03:00 \
git -C "$out" commit -q -m $'clk: qcom: correct MSM8x60 MMCC branch mappings\n\nMatch exact Sony/CAF MSM8x60 VPE, ROT, IMEM and VCODEC branch mappings and remove unsupported critical semantics from optional multimedia branches.\n\nSigned-off-by: BlackF1re <55582873+BlackF1re@users.noreply.github.com>'

# Project correction #38 closes the remaining source-verifiable Hikari panel
# mismatches.  Sony's MDV22 profile requires BGR channel order in the MSM DSI
# host and a specific regulator/reset/LCD_PWR_EN sequence.  Keep this as a
# strict transform so a future upstream change fails loudly instead of
# silently dropping the board quirk.
python3 "$repo_root/scripts/apply-hikari-display-finalization.py" "$out"
git -C "$out" add \
  drivers/gpu/drm/msm/dsi/dsi_host.c \
  drivers/gpu/drm/panel/panel-renesas-r63306-tmd-mdv22.c
if git -C "$out" diff --cached --quiet; then
  echo 'Hikari display finalization produced no diff; refusing ambiguous materialization' >&2
  exit 6
fi
GIT_AUTHOR_NAME=BlackF1re \
GIT_AUTHOR_EMAIL=55582873+BlackF1re@users.noreply.github.com \
GIT_AUTHOR_DATE=2026-09-04T17:30:00+03:00 \
GIT_COMMITTER_NAME="Hikari Patch Materializer" \
GIT_COMMITTER_EMAIL=hikari-materializer@localhost \
GIT_COMMITTER_DATE=2026-09-04T17:30:00+03:00 \
git -C "$out" commit -q -m $'drm: msm: finalize Hikari MDV22 signalling\n\nMatch the Sony Hikari MDV22 BGR channel order and reproduce the exact reset/LCD power sequencing around panel initialization and shutdown.\n\nSigned-off-by: BlackF1re <55582873+BlackF1re@users.noreply.github.com>'

# Project correction #39 expands the already Hikari-specific AS3676 driver
# from LCD-only support to every source-backed LED output used on this board.
# The precondition checker refuses to replace an unexpected historical driver.
python3 "$repo_root/scripts/apply-hikari-as3676-leds.py" "$out"
git -C "$out" add drivers/video/backlight/as3676-backlight.c drivers/video/backlight/Kconfig
if git -C "$out" diff --cached --quiet; then
  echo 'Hikari AS3676 LED correction produced no diff; refusing ambiguous materialization' >&2
  exit 7
fi
GIT_AUTHOR_NAME=BlackF1re \
GIT_AUTHOR_EMAIL=55582873+BlackF1re@users.noreply.github.com \
GIT_AUTHOR_DATE=2026-09-04T18:20:00+03:00 \
GIT_COMMITTER_NAME="Hikari Patch Materializer" \
GIT_COMMITTER_EMAIL=hikari-materializer@localhost \
GIT_COMMITTER_DATE=2026-09-04T18:20:00+03:00 \
git -C "$out" commit -q -m $'leds: as3676: expose Hikari button and RGB outputs\n\nKeep LCD sinks 1/2/6 and add the exact Sony Hikari button RGB1/2/3 group plus notification sinks 41/42/43 through the Linux LED class.\n\nSigned-off-by: BlackF1re <55582873+BlackF1re@users.noreply.github.com>'

"$repo_root/scripts/check-msm8660-mmcc-source.sh" "$out"
python3 "$repo_root/scripts/check-hikari-display-source.py" "$out"
"$repo_root/scripts/check-hikari-as3676-source.sh" "$out"
"$repo_root/scripts/prepare-hikari-kernel-tree.sh" "$out"

printf 'Hikari kernel materialized successfully.\n'
printf 'Base: %s\n' "$LINUX_BASE"
printf 'HEAD: %s\n' "$(git -C "$out" rev-parse HEAD)"
printf 'Tree: %s\n' "$out"
printf 'Imported patches: %d\n' "${#patches[@]}"
