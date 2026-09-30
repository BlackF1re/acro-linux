#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Static acceptance checks. Physical boot remains a separate requirement.
set -euo pipefail

kernel_build=${KERNEL_BUILD:-/home/paul/xperia/build/linux-hikari-current}
rootfs=${ROOTFS_DIR:-/home/paul/xperia/build/hikari-rootfs-current}
archive=${INITRAMFS:-/home/paul/xperia/build/hikari-root-initramfs-current/hikari-root.cpio.gz}
config="$kernel_build/.config"
dtb="$kernel_build/arch/arm/boot/dts/qcom/qcom-msm8260-sony-hikari.dtb"
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
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
	CONFIG_USB_CONFIGFS=y CONFIG_USB_CONFIGFS_ACM=y CONFIG_USB_CONFIGFS_NCM=y \
	CONFIG_NAMESPACES=y CONFIG_UTS_NS=y CONFIG_IPC_NS=y CONFIG_PID_NS=y \
	CONFIG_NET_NS=y CONFIG_AUTOFS_FS=m CONFIG_BPF_SYSCALL=y \
	CONFIG_CGROUP_BPF=y CONFIG_NETFILTER=y CONFIG_NF_TABLES=m \
	CONFIG_NFC=m CONFIG_BRCMFMAC=m CONFIG_BT=m \
	CONFIG_BT_BNEP=m CONFIG_BT_RFCOMM=m CONFIG_BT_HIDP=m \
	CONFIG_QCOM_TSENS=y CONFIG_NVMEM_QCOM_QFPROM=y \
	CONFIG_RMI4_CORE=m CONFIG_MPU3050_I2C=m CONFIG_BMA180=m
do
	require_config "$setting"
done

require_config '# CONFIG_USB_G_SERIAL is not set'

test -s "$kernel_build/arch/arm/boot/zImage"
test -s "$dtb"
test -s "$archive"
"$repo_root/scripts/check-hikari-usb-dtb.sh" --config "$config" --dtb "$dtb"
"$repo_root/scripts/check-hikari-pstore.sh" --config "$config" --dtb "$dtb"
archive_list=$(gzip -dc "$archive" | cpio -it 2>/dev/null)
for member in init bin/busybox bin/blkid bin/mount bin/switch_root \
	lib/firmware/regulatory.db lib/firmware/regulatory.db.p7s \
	usr/sbin/hikari-console-launch usr/sbin/hikari-usb-gadget; do
	grep -qx "$member" <<<"$archive_list" || { echo "missing initramfs member: $member" >&2; exit 1; }
done
grep -Fq "printf '500\\n' >\"\$gadget/configs/c.1/MaxPower\"" \
	"$(dirname -- "${BASH_SOURCE[0]}")/../initramfs/common/usr/sbin/hikari-usb-gadget" || {
	echo 'USB gadget does not request the 500 mA enumerated USB 2.0 budget' >&2
	exit 1
}
! grep -Fq -- '--watch' \
	"$(dirname -- "${BASH_SOURCE[0]}")/../initramfs/hikari-root/init" || {
	echo 'SYSTEM initramfs still starts the obsolete USB polling watcher' >&2
	exit 1
}
grep -Fq 'ip address replace 192.168.77.2/30 dev usb0' \
	"$(dirname -- "${BASH_SOURCE[0]}")/../initramfs/hikari-root/init" || {
	echo 'SYSTEM initramfs does not configure its USB NCM address' >&2
	exit 1
}
grep -Fq 'SUBSYSTEM=="udc"' \
	"$(dirname -- "${BASH_SOURCE[0]}")/../debian/etc/udev/rules.d/70-hikari-usb-gadget.rules" || {
	echo 'SYSTEM rootfs is missing event-driven USB gadget rebinding' >&2
	exit 1
}
grep -Fq 'configuration_changed' \
	"$(dirname -- "${BASH_SOURCE[0]}")/../initramfs/common/usr/sbin/hikari-usb-gadget" || {
	echo 'USB gadget setup will not re-enumerate after adding SYSTEM functions' >&2
	exit 1
}
grep -Fq 'mount --bind /proc /system/proc' \
	"$(dirname -- "${BASH_SOURCE[0]}")/../initramfs/hikari-loader/usr/sbin/hikari-system" || {
	echo 'BOOT SYSTEM launcher does not expose /proc to kexec' >&2
	exit 1
}
[[ $(grep -c 'for file in .*modules.tar.gz.*SHA256SUMS' \
	"$(dirname -- "${BASH_SOURCE[0]}")/../initramfs/hikari-loader/usr/sbin/hikari-receive-system") -eq 2 ]] || {
	echo 'SYSTEM receiver does not atomically activate modules.tar.gz' >&2
	exit 1
}
rootfs_receiver="$(dirname -- "${BASH_SOURCE[0]}")/../initramfs/hikari-loader/usr/sbin/hikari-receive-rootfs"
grep -Fq 'chroot /system /usr/bin/tar -xzpf /.hikari-rootfs-update.tar.gz' \
	"$rootfs_receiver" || {
	echo 'rootfs receiver must preserve Debian symlinks with GNU tar' >&2
	exit 1
}
if grep -Eq '^[[:space:]]*tar[[:space:]].*-x' "$rootfs_receiver"; then
	echo 'rootfs receiver still extracts the Debian archive with BusyBox tar' >&2
	exit 1
fi

if [[ -e $rootfs/.hikari-debootstrap-complete ]]; then
	[[ $(stat -c '%u:%g' "$rootfs") == 0:0 ]] || {
		echo 'rootfs top-level directory must be owned by root:root' >&2
		exit 1
	}
	test -x "$rootfs/usr/bin/tar"
	[[ -L $rootfs/sbin/init && $(readlink "$rootfs/sbin/init") == ../lib/systemd/systemd ]]
	test -x "$(readlink -e "$rootfs/sbin/init")"
	test -x "$rootfs/usr/local/sbin/hikari-kexec"
	test -x "$rootfs/usr/local/sbin/hikari-boot"
	test -x "$rootfs/usr/local/sbin/hikari-usb-gadget"
	grep -qx 'LANG=C.UTF-8' "$rootfs/etc/default/locale"
	test -x "$rootfs/usr/local/sbin/check-hikari-wifi"
	test -f "$rootfs/etc/NetworkManager/system-connections/hikari-usb.nmconnection"
	grep -qx 'wifi.cloned-mac-address=stable' \
		"$rootfs/etc/NetworkManager/conf.d/20-hikari-wifi.conf"
	grep -qx 'options brcmfmac feature_disable=16' \
		"$rootfs/etc/modprobe.d/hikari-brcmfmac.conf"
	[[ $(stat -c '%a:%u:%g' \
		"$rootfs/etc/NetworkManager/system-connections/hikari-usb.nmconnection") == 600:0:0 ]]
	test ! -e "$rootfs/etc/systemd/system/multi-user.target.wants/wpa_supplicant.service"
	test ! -e "$rootfs/etc/systemd/system/multi-user.target.wants/systemd-networkd.service"
	test -L "$rootfs/etc/systemd/system/multi-user.target.wants/NetworkManager.service"
	test -L "$rootfs/etc/systemd/system/multi-user.target.wants/ssh.service"
	test -L "$rootfs/etc/systemd/system/sysinit.target.wants/systemd-timesyncd.service"
	test -L "$rootfs/etc/systemd/system/multi-user.target.wants/hikari-usb-gadget.service"
	test ! -e "$rootfs/etc/systemd/system/hikari-usb-gadget-watch.service"
	test ! -e "$rootfs/etc/systemd/system/multi-user.target.wants/hikari-usb-gadget-watch.service"
	test ! -e "$rootfs/usr/local/sbin/hikari-wifi"
	grep -qx 'PasswordAuthentication yes' \
		"$rootfs/etc/ssh/sshd_config.d/10-hikari.conf"
	grep -qx 'PermitEmptyPasswords yes' \
		"$rootfs/etc/ssh/sshd_config.d/10-hikari.conf"
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
