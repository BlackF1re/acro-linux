#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Install a public key into a mounted/built rootfs.  Key material is never
# copied into the repository.
set -euo pipefail

rootfs=${1:-/home/paul/xperia/build/hikari-rootfs-current}
public_key=${2:-${HOME}/.ssh/id_ed25519.pub}
[[ $rootfs == /home/paul/xperia/build/* || $rootfs == /mnt/* ]] || {
	echo "refusing unexpected rootfs path: $rootfs" >&2
	exit 1
}
test -d "$rootfs/etc" || { echo "not a rootfs: $rootfs" >&2; exit 1; }
test -s "$public_key" || { echo "missing public key: $public_key" >&2; exit 1; }

sudo install -d -o root -g root -m 0700 "$rootfs/root/.ssh"
sudo install -o root -g root -m 0600 "$public_key" \
	"$rootfs/root/.ssh/authorized_keys"
echo "installed SSH public key in $rootfs"
