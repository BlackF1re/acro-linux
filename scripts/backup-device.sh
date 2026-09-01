#!/usr/bin/env bash
# Read-only golden backup for the connected Hikari.  There is deliberately no
# restore counterpart: restoration needs a separate, owner-approved workflow.
set -euo pipefail

device=${1:-/dev/block/mmcblk0}
destination=${2:?usage: $0 /dev/block/mmcblk0 /absolute/path/outside/repository}
adb_bin=${ADB:-adb}
script_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
repository_root=$(git -C "$script_dir/.." rev-parse --show-toplevel)
sector_size=512
chunk_mib=16
chunk_bytes=$((chunk_mib * 1024 * 1024))
safety_margin_bytes=$((4 * 1024 * 1024))

fail() { printf 'backup-device: %s\n' "$*" >&2; exit 1; }

case "$device" in
  /dev/block/mmcblk0|/dev/block/mmcblk0boot0|/dev/block/mmcblk0boot1) ;;
  *) fail "source is not in the explicit read-only whitelist: $device" ;;
esac
[ "$(realpath -m "$destination")" = "$destination" ] || fail "destination must be an absolute canonical path"
case "$destination" in
  /dev/*|"$repository_root"/*) fail "destination must be outside /dev and the repository" ;;
esac
case "$destination" in
  /home/paul/xperia/backups/*) ;;
  *) fail "destination must be below /home/paul/xperia/backups" ;;
esac
[ "${destination##*.}" != partial ] || fail "destination must be a final image name, not a partial marker"
[ ! -e "$destination" ] || fail "destination already exists"

"$adb_bin" get-state | grep -qx device || fail "ADB device is not ready"
"$adb_bin" shell 'su -c id' | tr -d '\r' | grep -q 'uid=0(root)' || fail "root read access is unavailable"
"$adb_bin" shell 'getprop ro.product.device' | tr -d '\r' | grep -qx LT26w || fail "connected device is not LT26w"
"$adb_bin" shell 'getprop ro.product.board' | tr -d '\r' | grep -qx fuji || fail "connected device is not the Fuji board"

sector_count=$("$adb_bin" shell "su -c \"test -b '$device' && cat /sys/class/block/\$(basename '$device')/size\"" | tr -d '\r')
case "$sector_count" in ''|*[!0-9]*) fail "could not obtain a numeric source size for $device";; esac
source_bytes=$((sector_count * sector_size))
[ "$source_bytes" -gt 0 ] || fail "source size is zero"
[ $((chunk_bytes % sector_size)) -eq 0 ] || fail "chunk size is not sector aligned"
[ $((source_bytes % sector_size)) -eq 0 ] || fail "source size is not sector aligned"
chunk_sectors=$((chunk_bytes / sector_size))
if [ "$device" = /dev/block/mmcblk0 ]; then
  [ "$source_bytes" -eq 15634268160 ] || fail "mmcblk0 size does not match the recorded Hikari eMMC user area"
fi

destination_dir=$(dirname "$destination")
[ -d "$destination_dir" ] || fail "destination directory does not exist"
available_bytes=$(df -B1 --output=avail "$destination_dir" | tail -n 1 | tr -d ' ')
required_bytes=$((source_bytes + chunk_bytes + safety_margin_bytes))
[ "$available_bytes" -ge "$required_bytes" ] || fail "insufficient free space: need $required_bytes bytes, have $available_bytes"

umask 077
partial="$destination.partial"
part="$destination.chunk.partial"
[ ! -e "$partial" ] || fail "stale partial image exists: $partial"
[ ! -e "$part" ] || fail "stale temporary chunk exists: $part"

cleanup() {
  rm -f -- "$part"
}
trap cleanup EXIT INT TERM HUP

: > "$partial"
chmod 0600 "$partial"

# ADB on this legacy Android has no exec-out and allocates a CRLF-translating
# shell PTY.  Base64 makes the transport text-safe; gzip keeps each 16 MiB
# chunk below its output limit.  The host validates every decompressed chunk
# before it can be appended to the image.
chunks=$(((sector_count + chunk_sectors - 1) / chunk_sectors))
for ((index=0; index<chunks; index++)); do
  skip_sectors=$((index * chunk_sectors))
  remaining_sectors=$((sector_count - skip_sectors))
  wanted_sectors=$((remaining_sectors < chunk_sectors ? remaining_sectors : chunk_sectors))
  offset_bytes=$((skip_sectors * sector_size))
  wanted_bytes=$((wanted_sectors * sector_size))

  [ $((offset_bytes % sector_size)) -eq 0 ] || fail "chunk $index offset is not sector aligned"
  [ $((wanted_bytes % sector_size)) -eq 0 ] || fail "chunk $index size is not sector aligned"
  [ "$wanted_sectors" -gt 0 ] || fail "chunk $index has no sectors to read"

  "$adb_bin" shell "su -c \"dd if='$device' bs=$sector_size skip='$skip_sectors' count='$wanted_sectors' 2>/dev/null | busybox gzip -1 | busybox base64\"" | base64 -d | gzip -d > "$part"
  [ "$(stat -c %s "$part")" -eq "$wanted_bytes" ] || fail "chunk $index has an unexpected length"
  cat "$part" >> "$partial"
  : > "$part"
  if (( (index + 1) % 25 == 0 || index + 1 == chunks )); then
    printf 'chunk %d/%d: %d bytes\n' "$((index + 1))" "$chunks" "$(stat -c %s "$partial")"
  fi
done

[ "$(stat -c %s "$partial")" -eq "$source_bytes" ] || fail "final image length differs from source"
mv -- "$partial" "$destination"
sha256sum "$destination" > "$destination.sha256"
chmod 0600 "$destination" "$destination.sha256"
printf 'completed: %s (%s bytes)\n' "$destination" "$source_bytes"
