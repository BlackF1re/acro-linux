# Second Hikari boot plan and result

The first attempt did not prove mainline boot.  Its two concrete pre-boot
defects were an omitted MSM8x60 SMEM reservation and an initramfs at
`0x42800000` overlapping the real upstream decompressor self-relocation
range.  This second local artifact corrects only those defects and adds
`HIKARI MAINLINE BOOT #2` / `HIKARI INITRAMFS STARTED` diagnostics.

## Executed candidate

The Sony ELF contains zImage plus appended Hikari DTB at `0x40408000`, native
initramfs at `0x42a00000`, and the private legacy RPM payload at `0x00020000`.
The kernel has `ARCH_QCOM_RESERVE_SMEM`, appended-DTB and ATAG-to-DT
compatibility enabled.  There is no standalone cmdline ELF segment.

No Hikari physical debug UART is proven: historical Fuji source names GPIO117
/ GPIO118 as generic UART pins but does not establish their GSBI or an exposed
connector.  `SERIAL_EARLYCON` is enabled but no guessed console route is sent.
USB gadget remains outside this early-boot scope.  The second attempt itself
therefore remained externally blind.  Its successor is not: boot #4 adds a
standard mainline ramoops console at the physically observed legacy
`ram_console` range, with a TWRP `/proc/last_kmsg` and host-side raw-memory
capture procedure documented in [PERSISTENT_LOGGING.md](PERSISTENT_LOGGING.md)
and [BOOT4_POSTMORTEM_PLAN.md](BOOT4_POSTMORTEM_PLAN.md).  The rollback route
is physically proven, but a new boot #4 deployment still requires separate
owner approval.

The owner-approved second attempt was executed once. S1Boot accepted the
logical `boot` flash and reported the expected p3 mapping, but the subsequent
120-second observation produced no target-Linux marker, ADB, fastboot, or new
USB target. The owner observed a black, unresponsive handset and recovered it
with **Power + Volume Up**. The exact original p3 was then restored through
S1Boot; Android returned normally. Thus `BOOT_PROOF=NOT_OBSERVED` and
`SECOND_MAINLINE_BOOT=NOT_VERIFIED`; no particular kernel failure stage is
established.

The post-mortem capture did not preserve the failed boot: TWRP's only
`/proc/last_kmsg` belongs to a later legacy Android/recovery transition.
See [secondboot post-mortem](../research/device/current/boot/secondboot-postmortem.md).

## Historical owner-gated procedure

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

Never erase, use `fastboot boot`, or touch another partition. This procedure
is historical and must not be reused without a new artifact and explicit owner
approval.

## Next diagnostic boundary

The third local-only iteration corrects and host-side validates the probable
double-applied SMEM offset described in
[FIRST_BOOT_MEMORY.md](FIRST_BOOT_MEMORY.md). A later physical attempt still
needs explicit owner approval and a stronger diagnostics route; the historical
Hikari mainline trace identifies `ttyMSM0` at `0x19c40000` as a possible
route, but no accessible Hikari UART path has yet been proven.
