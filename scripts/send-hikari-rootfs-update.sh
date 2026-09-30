#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Stream the canonical rootfs to BOOT over USB NCM without retaining another
# long-lived copy in the space-constrained build directory.
set -euo pipefail

hikari_build_root=${HIKARI_BUILD_ROOT:-/home/paul/xperia/build}
rootfs=${ROOTFS_DIR:-$hikari_build_root/hikari-rootfs-current}
tty=${1:-/dev/ttyACM0}
test -c "$tty" || { echo "not a tty: $tty" >&2; exit 1; }
test -e "$rootfs/.hikari-debootstrap-owned" || { echo "not the canonical rootfs: $rootfs" >&2; exit 1; }
host_interface=$(ip -o link | awk '/link\/ether 02:86:60:00:00:01/ {sub(/:$/, "", $2); print $2; exit}')
[[ -n $host_interface ]] || { echo 'Hikari NCM interface not found' >&2; exit 1; }

umask 077
archive=$(mktemp "$hikari_build_root/.hikari-rootfs-update.XXXXXX.tar.gz")
trap 'find "$archive" -maxdepth 0 -delete 2>/dev/null || true' EXIT
sudo tar -C "$rootfs" --numeric-owner -czf - \
	--exclude='./dev/*' --exclude='./proc/*' --exclude='./run/*' \
	--exclude='./sys/*' --exclude='./tmp/*' \
	--exclude='./var/cache/apt/archives/*' --exclude='./var/log/*' . >"$archive"
checksum=$(sha256sum "$archive" | awk '{print $1}')

sudo ip link set "$host_interface" up
sudo ip address replace 192.168.77.1/30 dev "$host_interface"
acm_command="$(dirname -- "${BASH_SOURCE[0]}")/hikari-acm-command.py"
test -x "$acm_command" || { echo "missing ACM command helper: $acm_command" >&2; exit 1; }
sudo "$acm_command" --device "$tty" --no-read \
	hikari-receive-rootfs "$checksum"
sleep 1
nc -N 192.168.77.2 7778 <"$archive"
printf 'Rootfs transfer complete; BOOT is verifying and extracting it.\n'
