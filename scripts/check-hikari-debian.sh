#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Static acceptance checks. Physical boot remains a separate requirement.
set -euo pipefail

kernel_build=${KERNEL_BUILD:-/home/paul/xperia/build/linux-hikari-current}
rootfs=${ROOTFS_DIR:-/home/paul/xperia/build/hikari-rootfs-current}
archive=${INITRAMFS:-/home/paul/xperia/build/hikari-root-initramfs-current/hikari-root.cpio.gz}
config="$kernel_build/.config"
release=$(make -s -C /home/paul/xperia/src/linux O="$kernel_build" ARCH=arm kernelrelease)

require_config()
{
	grep -qx "$1" "$config" || { echo "missing kernel setting: $1" >&2; exit 1; }
}

for setting in \
	CONFIG_MODULES=y CONFIG_MODVERSIONS=y CONFIG_KEXEC=y \
	CONFIG_MMC=y CONFIG_MMC_BLOCK=y CONFIG_EXT4_FS=y \
	CONFIG_DRM_MSM=y CONFIG_DRM_MSM_MDP4=y \
	CONFIG_USB_CHIPIDEA=y CONFIG_USB_CHIPIDEA_HOST=y \
	CONFIG_USB_CHIPIDEA_UDC=y CONFIG_CONFIGFS_FS=y \
	CONFIG_USB_CONFIGFS=y CONFIG_USB_CONFIGFS_ACM=y \
	CONFIG_NFC=m CONFIG_BRCMFMAC=m CONFIG_BT=m \
	CONFIG_RMI4_CORE=m CONFIG_MPU3050_I2C=m CONFIG_BMA180=m
do
	require_config "$setting"
done

require_config '# CONFIG_USB_G_SERIAL is not set'

test -s "$kernel_build/arch/arm/boot/zImage"
test -s "$kernel_build/arch/arm/boot/dts/qcom/qcom-msm8260-sony-hikari.dtb"
test -s "$archive"
archive_list=$(gzip -dc "$archive" | cpio -it 2>/dev/null)
for member in init bin/busybox bin/mount bin/switch_root bin/setsid \
	usr/sbin/hikari-usb-gadget; do
	grep -qx "$member" <<<"$archive_list" || { echo "missing initramfs member: $member" >&2; exit 1; }
done

if [[ -e $rootfs/.hikari-debootstrap-complete ]]; then
	test -x "$rootfs/sbin/init"
	test -x "$rootfs/usr/local/sbin/hikari-kexec"
	test ! -e "$rootfs/etc/systemd/system/multi-user.target.wants/wpa_supplicant.service"
	while IFS= read -r package; do
		sudo awk -v wanted="$package" '
			$1 == "Package:" { current = $2 }
			$1 == "Status:" && current == wanted && $0 == "Status: install ok installed" {
				installed = 1
			}
			END { exit !installed }
		' "$rootfs/var/lib/dpkg/status" || {
			echo "missing rootfs package: $package" >&2
			exit 1
		}
	done < <(sed -e 's/#.*//' -e '/^[[:space:]]*$/d' \
		"$(dirname -- "${BASH_SOURCE[0]}")/../debian/packages.txt")
	test ! -d "$rootfs/lib/modules/$release/updates"
	diff -u \
		<(sort "$rootfs/lib/modules/$release/modules.order") \
		<(cd "$rootfs/lib/modules/$release" && find kernel -type f -name '*.ko' -print | sort)
	(cd "$rootfs/boot/hikari-next" && sha256sum -c SHA256SUMS)
elif [[ -d $rootfs ]]; then
	printf 'rootfs is still being built; skipping completed-rootfs checks\n' >&2
fi

printf 'HIKARI_DEBIAN_STATIC=PASS\nkernel_release=%s\n' "$release"
