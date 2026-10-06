# BOOT to SYSTEM handoff

`VERIFIED_DEVICE`: the small single-core BOOT kernel loads the SMP Hikari
kernel, DTB and initramfs from the `HIKARI_ROOT` microSD partition. The
BOOT→SYSTEM transition passed repeated physical runs; the SYSTEM starts both
Scorpion cores and mounts the card by filesystem label, not by a variable
`mmcblk` number.

BOOT is kept as the immutable recovery environment. Test kernels are staged
under the card's separate SYSTEM bundle path and selected only after a normal
reboot to BOOT. Do not kexec from the running SMP SYSTEM: MSM8x60 has no
`cpu_kill` operation proving CPU1 has fully returned to bootloader state.

The first-stage kernel is UP (`CONFIG_SMP=n`); SYSTEM is SMP. This follows the
ARM kexec/hotplug contract rather than bypassing it with a dummy CPU shutdown
callback. USB console reconnects across the handoff. Peripheral acceptance
after kexec remains subsystem-specific; see [BOOT.md](../../../../docs/BOOT.md).
