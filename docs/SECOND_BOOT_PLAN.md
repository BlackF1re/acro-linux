# Second Hikari boot plan

The first attempt did not prove mainline boot.  Its two concrete pre-boot
defects were an omitted MSM8x60 SMEM reservation and an initramfs at
`0x42800000` overlapping the real upstream decompressor self-relocation
range.  This second local artifact corrects only those defects and adds
`HIKARI MAINLINE BOOT #2` / `HIKARI INITRAMFS STARTED` diagnostics.

## Candidate

The Sony ELF contains zImage plus appended Hikari DTB at `0x40408000`, native
initramfs at `0x42a00000`, and the private legacy RPM payload at `0x00020000`.
The kernel has `ARCH_QCOM_RESERVE_SMEM`, appended-DTB and ATAG-to-DT
compatibility enabled.  There is no standalone cmdline ELF segment.

No Hikari physical debug UART is proven: historical Fuji source names GPIO117
/ GPIO118 as generic UART pins but does not establish their GSBI or an exposed
connector.  `SERIAL_EARLYCON` is enabled but no guessed console route is sent.
USB gadget and ramoops are likewise not enabled.  Thus the external proof path
is host USB observation plus any visible target output; the initramfs markers
are definitive only if a console becomes available.  This controlled blind
attempt is acceptable only because the p3 rollback route is physically proven.

## Proposed, owner-gated procedure

Do not execute without fresh approval:

```sh
fastboot flash boot /home/paul/xperia/build/hikari-artifacts-g4/hikari-secondboot.elf
fastboot reboot
```

Abort on any unexpected S1Boot response, hash/size mismatch, USB instability,
or failed local gate.  If recovery is needed: **Power + Volume Up** forces
reset; then phone off + **Volume Up** + USB enters S1Boot.  Verify the original
hash and use only:

```sh
fastboot flash boot /home/paul/xperia/backups/hikari/20260901T111716Z/hikari-golden-backup-20260901T190000Z/hikari-original-p3-restore.elf
fastboot reboot
```

Never erase, use `fastboot boot`, or touch another partition.
