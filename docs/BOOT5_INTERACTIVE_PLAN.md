# BOOT #5 interactive procedure

This is a proposed future physical procedure. It is not authorization to
flash. Preserve the verified BOOT #4 hand-off: zImage `0x40208000`, initramfs
`0x42a00000`, SMEM `0x40000000-0x401fffff`, appended Hikari DTB, RPM payload,
and ramoops `0x7ffe0000/0x20000/ECC=0`.

## Preflight

1. Verify the exact BOOT #5 ELF hash, size, Sony-ELF validator, appended-DTB,
   memory, SMEM and ramoops checks.
2. Verify the original p3 restore ELF hash and retain it locally.
3. Start the documented usbipd AutoBind/auto-attach process for the actual
   physical BUSID; do not use an Android or Sony serial as an identifier.
4. Enter S1Boot only by the verified hardware method and verify `0fce:0dde`
   plus `fastboot devices`.

## Proposed run and observation

```sh
fastboot flash boot /home/paul/xperia/build/hikari-artifacts-g7-ulpi/hikari-boot5-interactive-ulpi.elf
fastboot reboot
```

Do not issue a second flash. For at least 120 seconds watch `lsusb`, host
kernel events and `/dev/ttyACM*`. If ACM appears, run
`./scripts/connect-hikari-console.sh`; use read-only probes first. USB ACM
acceptance requires a real host `ttyACM`, `ttyGS0` and interactive shell.

The final BOOT #5 DT sets HSUSB1 to `dr_mode = "peripheral"`, with no
`extcon` or `usb-role-switch` dependency.  The MSM8x60 ULPI vendor
initialisation patch is present in the external kernel worktree, and PID 1
will preserve a one-time UDC/`ttyGS*` snapshot in ramoops before its periodic
markers.  These are local-build facts, not device results.

If there is no usable interface, use the proven forced-reset and rollback
route: **Power + Volume Up**, then phone-off **Volume Up + USB**, verify
S1Boot, verify the original ELF hash, flash only logical `boot` with the
original p3 artifact, and reboot. Capture ramoops through TWRP before allowing
Android to boot if a post-mortem is needed. No erase, format, update or other
partition operation is part of this procedure.
