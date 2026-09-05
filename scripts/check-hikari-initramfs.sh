#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Validate the archive that is actually embedded into a Hikari boot artifact.
set -euo pipefail

archive=${1:?usage: check-hikari-initramfs.sh INITRAMFS.cpio.gz}
test -f "$archive"

listing=$(gzip -cd -- "$archive" | cpio -itv 2>/dev/null)
for path in init bin/sh bin/mount bin/sleep bin/cttyhack bin/mkdir bin/cat bin/echo \
            bin/ls bin/uname bin/dmesg bin/ps usr/bin/setsid usr/bin/top sbin/getty \
            sbin/devmem sbin/ip sbin/ifconfig sbin/hwclock \
            usr/bin/free usr/bin/hexdump usr/bin/lsblk usr/bin/lsusb usr/bin/microcom \
            usr/sbin/i2cdetect usr/sbin/i2cdump usr/sbin/i2cget usr/sbin/i2ctransfer \
            usr/sbin/powertop \
            usr/sbin/hikari-diag usr/sbin/hikari-display-diag usr/sbin/hikari-power-diag \
            usr/sbin/hikari-gpu-diag \
            lib/firmware/qcom/leia_pm4_470.fw lib/firmware/qcom/leia_pfp_470.fw \
            dev proc sys; do
  printf '%s\n' "$listing" | grep -Eq "[[:space:]]${path}( |$| ->)" || {
    echo "Hikari initramfs missing $path" >&2
    exit 1
  }
done
for helper in hikari-diag hikari-display-diag hikari-power-diag hikari-gpu-diag; do
  printf '%s\n' "$listing" | grep -Eq "^-rwxr-xr-x.* usr/sbin/${helper}$" || {
    echo "Hikari initramfs missing executable diagnostic helper $helper" >&2
    exit 1
  }
done
for fw in leia_pm4_470.fw leia_pfp_470.fw; do
  printf '%s\n' "$listing" | grep -Eq "^-rw-r--r--.* lib/firmware/qcom/${fw}$" || {
    echo "Hikari initramfs missing readable A220 firmware $fw" >&2
    exit 1
  }
done
for link in bin/ls bin/uname bin/dmesg bin/ps bin/cttyhack; do
  printf '%s\n' "$listing" | grep -Eq " ${link} -> busybox$" || {
    echo "Hikari initramfs missing canonical BusyBox link $link -> busybox" >&2
    exit 1
  }
done
for link in usr/bin/setsid usr/bin/top; do
  printf '%s\n' "$listing" | grep -Eq " ${link} -> ../../bin/busybox$" || {
    echo "Hikari initramfs missing canonical BusyBox link $link -> ../../bin/busybox" >&2
    exit 1
  }
done
printf '%s\n' "$listing" | grep -Eq ' sbin/getty -> ../bin/busybox$' || {
  echo 'Hikari initramfs missing canonical BusyBox link sbin/getty -> ../bin/busybox' >&2
  exit 1
}
printf '%s\n' "$listing" | grep -Eq '^crw-------.* dev/console$' || {
  echo 'Hikari initramfs has no c 5:1 /dev/console' >&2
  exit 1
}
printf '%s\n' "$listing" | grep -Eq '^crw-rw-rw-.* dev/null$' || {
  echo 'Hikari initramfs has no c 1:3 /dev/null' >&2
  exit 1
}

echo 'HIKARI_INITRAMFS_LAYOUT=PASS'
