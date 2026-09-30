#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Build one reusable Debian armhf root tree. The output directory is updated in
# place; no timestamped copies or package caches are retained inside it.
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../debian/source.lock
source "$repo_root/debian/source.lock"
rootfs=${ROOTFS_DIR:-/home/paul/xperia/build/hikari-rootfs-current}
qemu_arm=${QEMU_ARM:-/usr/bin/qemu-arm}
keyring=${DEBIAN_KEYRING:-/usr/share/keyrings/debian-archive-keyring.gpg}
packages=$(sed -e 's/#.*//' -e '/^[[:space:]]*$/d' "$repo_root/debian/packages.txt" | paste -sd, -)
wgetrc="$repo_root/debian/wgetrc"

[[ $rootfs == /home/paul/xperia/build/* ]] || { echo 'ROOTFS_DIR must remain below /home/paul/xperia/build' >&2; exit 1; }
command -v debootstrap >/dev/null
test -x "$qemu_arm" || { echo "missing static qemu-arm: $qemu_arm" >&2; exit 1; }
test -s "$keyring" || { echo "missing Debian archive keyring: $keyring" >&2; exit 1; }

if [[ ! -e "$rootfs/.hikari-debootstrap-first-stage" ]]; then
	[[ ! -e $rootfs || -e $rootfs/.hikari-debootstrap-owned || \
		-z $(find "$rootfs" -mindepth 1 -maxdepth 1 -print -quit) ]] || {
		echo "refusing incomplete/non-Hikari rootfs: $rootfs" >&2
		exit 1
	}
	mkdir -p "$rootfs"
	sudo touch "$rootfs/.hikari-debootstrap-owned"
	sudo env WGETRC="$wgetrc" \
		debootstrap --foreign --variant="$DEBIAN_VARIANT" --arch="$DEBIAN_ARCH" \
		--keyring="$keyring" --include="$packages" \
		"$DEBIAN_SUITE" "$rootfs" "$DEBIAN_MIRROR"
	sudo touch "$rootfs/.hikari-debootstrap-first-stage"
fi
if [[ ! -e "$rootfs/.hikari-debootstrap-complete" ]]; then
	if [[ -x "$rootfs/debootstrap/debootstrap" ]]; then
		sudo install -m 0755 "$qemu_arm" "$rootfs/usr/bin/qemu-arm-static"
		sudo env DEBIAN_FRONTEND=noninteractive \
			chroot "$rootfs" /usr/bin/qemu-arm-static /debootstrap/debootstrap --second-stage
	else
		# A successful second stage removes /debootstrap. The controlling host
		# process can be interrupted between that removal and our marker write,
		# especially while qemu-user is slow. Only recover when dpkg confirms
		# that no package remains in a non-installed state.
		test -s "$rootfs/var/lib/dpkg/status"
		if sudo awk '
			/^Package: / { package = $2 }
			/^Status: / && $0 != "Status: install ok installed" {
				print package ": " $0 > "/dev/stderr"
				bad = 1
			}
			END { exit bad }
		' "$rootfs/var/lib/dpkg/status"; then
			echo 'recovering completed debootstrap second stage'
		else
			echo 'debootstrap state is incomplete and cannot be resumed safely' >&2
			exit 1
		fi
	fi
	sudo touch "$rootfs/.hikari-debootstrap-complete"
fi

# Converge an already-created canonical rootfs when the explicit package
# manifest grows. This keeps one tree reusable instead of forcing another
# debootstrap copy. Avoid apt I/O entirely when every requested package is
# already installed.
missing_packages=()
while IFS= read -r package; do
	if ! sudo awk -v wanted="$package" '
		$1 == "Package:" { current = $2 }
		$1 == "Status:" && current == wanted && $0 == "Status: install ok installed" {
			installed = 1
		}
		END { exit !installed }
	' "$rootfs/var/lib/dpkg/status"; then
		missing_packages+=("$package")
	fi
done < <(sed -e 's/#.*//' -e '/^[[:space:]]*$/d' "$repo_root/debian/packages.txt")
if ((${#missing_packages[@]})); then
	sudo install -m 0755 "$qemu_arm" "$rootfs/usr/bin/qemu-arm-static"
	sudo chroot "$rootfs" /usr/bin/qemu-arm-static \
		/usr/bin/apt-get update
	sudo env DEBIAN_FRONTEND=noninteractive \
		chroot "$rootfs" /usr/bin/qemu-arm-static \
		/usr/bin/apt-get install --no-install-recommends -y \
		"${missing_packages[@]}"
fi

sudo install -D -m 0644 "$repo_root/debian/etc/hostname" "$rootfs/etc/hostname"
sudo install -D -m 0644 "$repo_root/debian/etc/fstab" "$rootfs/etc/fstab"
sudo install -D -m 0644 "$repo_root/debian/etc/systemd/system/hikari-console.service" \
	"$rootfs/etc/systemd/system/hikari-console.service"
sudo install -D -m 0755 "$repo_root/debian/usr/local/sbin/hikari-kexec" \
	"$rootfs/usr/local/sbin/hikari-kexec"
sudo ln -sfn ../hikari-console.service "$rootfs/etc/systemd/system/multi-user.target.wants/hikari-console.service"
# Debian enables the system-wide supplicant during package configuration.
# Bring-up networking is explicit and on-demand, so retain the binary and
# D-Bus activation metadata but remove boot-time service enablement.
sudo rm -f \
	"$rootfs/etc/systemd/system/multi-user.target.wants/wpa_supplicant.service" \
	"$rootfs/etc/systemd/system/dbus-fi.w1.wpa_supplicant1.service"
printf 'hikari\n' | sudo tee "$rootfs/etc/hostname" >/dev/null
printf '127.0.0.1 localhost\n127.0.1.1 hikari\n' | sudo tee "$rootfs/etc/hosts" >/dev/null
printf 'deb %s %s main\n' "$DEBIAN_MIRROR_DEFAULT" "$DEBIAN_SUITE" | \
	sudo tee "$rootfs/etc/apt/sources.list" >/dev/null

# Bring-up only: permit a physical USB/display console without shipping a
# password. Network login is not installed or enabled by this manifest.
sudo sed -i 's#^root:[^:]*:#root::#' "$rootfs/etc/shadow"
sudo rm -f "$rootfs/usr/bin/qemu-arm-static"
sudo find "$rootfs/var/cache/apt" "$rootfs/var/lib/apt/lists" \
	-mindepth 1 -delete
sudo find "$rootfs/var/log" -type f -exec truncate -s 0 {} +
printf 'rootfs: %s\n' "$rootfs"
sudo du -sh "$rootfs"
