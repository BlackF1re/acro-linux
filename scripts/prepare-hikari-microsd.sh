#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Destructively prepare one explicitly named removable disk for Hikari Debian.
# This script is intentionally never called by the normal build workflow.
set -euo pipefail

device=${1:-}
confirm=${2:-}
rootfs=${ROOTFS_DIR:-/home/paul/xperia/build/hikari-rootfs-current}

usage()
{
	cat >&2 <<EOF
usage: sudo ${0##*/} /dev/DEVICE I-UNDERSTAND-THIS-ERASES-/dev/DEVICE

The entire explicitly named removable DEVICE is repartitioned. The script
refuses mounted disks, non-removable disks, and the disk backing host '/'.
EOF
	exit 2
}

[[ $EUID -eq 0 && $device == /dev/* ]] || usage
[[ $confirm == "I-UNDERSTAND-THIS-ERASES-$device" ]] || usage
[[ -b $device && $(lsblk -dnro TYPE "$device") == disk ]] || {
	echo "not a whole block device: $device" >&2
	exit 1
}
[[ $(lsblk -dnro RM "$device") == 1 ]] || {
	echo "refusing non-removable device: $device" >&2
	exit 1
}
[[ -x $rootfs/sbin/init ]] || { echo "not a Debian rootfs: $rootfs" >&2; exit 1; }

root_source=$(findmnt -nro SOURCE /)
root_parent=$(lsblk -no PKNAME "$root_source" 2>/dev/null | head -n1 || true)
[[ $device != "$root_source" && ${device#/dev/} != "$root_parent" ]] || {
	echo "refusing the disk backing host root: $device" >&2
	exit 1
}
if lsblk -nrpo MOUNTPOINT "$device" | grep -qE '/.+'; then
	echo "refusing device with mounted filesystems: $device" >&2
	lsblk -o NAME,SIZE,TYPE,RM,MOUNTPOINTS "$device" >&2
	exit 1
fi

size_bytes=$(blockdev --getsize64 "$device")
(( size_bytes >= 2 * 1024 * 1024 * 1024 )) || {
	echo 'microSD is smaller than 2 GiB' >&2
	exit 1
}

printf 'About to erase and populate this removable disk:\n'
lsblk -o NAME,MODEL,SERIAL,SIZE,TYPE,RM,MOUNTPOINTS "$device"
printf 'label: dos; start=4 MiB; filesystem: ext4 LABEL=HIKARI_ROOT\n'

printf 'label: dos\nstart=8192, type=83, bootable\n' | sfdisk --wipe always "$device"
partprobe "$device"
udevadm settle
case "$device" in
	*[0-9]) partition="${device}p1" ;;
	*) partition="${device}1" ;;
esac
for _ in $(seq 1 20); do
	[[ -b $partition ]] && break
	sleep 1
done
[[ -b $partition ]] || { echo "partition did not appear: $partition" >&2; exit 1; }

mkfs.ext4 -F -L HIKARI_ROOT -m 1 "$partition"
mount_dir=$(mktemp -d /mnt/hikari-root.XXXXXX)
cleanup()
{
	mountpoint -q "$mount_dir" && umount "$mount_dir" || true
	rmdir "$mount_dir" 2>/dev/null || true
}
trap cleanup EXIT
mount "$partition" "$mount_dir"
rsync -aHAX --numeric-ids --delete "$rootfs"/ "$mount_dir"/
sync
umount "$mount_dir"
trap - EXIT
rmdir "$mount_dir"
e2fsck -f -n "$partition"

printf 'HIKARI_MICROSD=PASS\ndevice=%s\npartition=%s\n' "$device" "$partition"
