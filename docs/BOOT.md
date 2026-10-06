# Boot architecture

## Current design

Sony S1Boot loads one rescue ELF from eMMC p3 (`boot`). Its UP kernel and
initramfs display the banner ending in **BOOT**, expose a local/USB shell and
stop. It never starts the microSD system automatically.

At the `BOOT #` prompt:

- `hikari-system` mounts `LABEL=HIKARI_ROOT`, verifies
  `/boot/hikari-next/SHA256SUMS`, loads the SMP kernel/DTB/initramfs with
  kexec and enters it.
- `hikari-receive-system` receives a checksum-bearing SYSTEM kernel and
  matching modules over USB NCM. XMODEM is a fallback.
- `hikari-receive-rootfs SHA256` verifies a canonical Debian archive received
  over USB NCM and extracts it with Debian's GNU tar. BusyBox tar is forbidden
  here because it rejects valid usr-merge links such as
  `/sbin/init -> ../lib/systemd/systemd`.
- `reboot` and `poweroff` do what their names state.

The Debian stage prints a banner ending in **SYSTEM**. `hikari-boot` performs
a normal reboot; S1Boot reloads p3 and BOOT stops at its prompt. Direct SMP
SYSTEM-to-BOOT kexec is intentionally not used because MSM8x60 cannot prove
CPU1 has been safely returned to the bootloader state.

BOOT is recovery-capable, not a second copy of Debian. SYSTEM holds the normal
package-managed userspace, kernel modules and development tools. Kernel, DT and
module updates use the separate SYSTEM bundle path and need no p3 write.

## Fixed facts and safety

- p3 is the 20 MiB Sony ELF boot partition. Treat it as immutable during
  normal development; select test kernels from the microSD SYSTEM bundle path.
- The current ELF uses kernel `0x40208000`, ramdisk `0x41800000` and the
  preserved RPM payload at `0x00020000`.
- Keep the verified original p3 image and recovery material available. No BOOT
  write is part of the normal development path.
- p1, p2, p5-p11, eMMC boot0/boot1 and RPMB are never installation targets.
- pstore/ramoops is retained for failures that remove display and USB.

See [PARTITIONS.md](PARTITIONS.md) and [RECOVERY.md](RECOVERY.md).
