# First physical Hikari boot procedure and result

The exact approved first attempt below was executed on 2026-09-02. It produced
no unmistakable mainline proof of life and was rolled back successfully. It
must not be repeated; a later attempt requires a new approved artifact and a
new owner approval.

## Preflight

1. Charge the battery sufficiently; do not begin a low-battery experiment.
2. Confirm the private golden backup and original restore artifact exist:
   `/home/paul/xperia/backups/hikari/20260901T111716Z/hikari-golden-backup-20260901T190000Z/hikari-original-p3-restore.elf`.
3. Confirm the restore artifact is exactly 20,971,520 bytes and SHA-256
   `c59be74873aa32a8422adf9b5402254b2acae619f7dc97bd50fc0e120984d0c1`.
4. Start the documented USBIPD AutoBind/auto-attach workflow in
   [HOST_USB.md](HOST_USB.md).  In fastboot, confirm `0fce:0dde` and that
   `fastboot devices` shows the expected single handset without recording its
   serial.
5. Confirm the device identity is LT26w/Fuji before the Android-to-fastboot
   transition, and confirm the recorded p3 capacity remains 20 MiB.
6. Confirm the experimental ELF below is 11,937,605 bytes and SHA-256
   `467d08a2fbafe86c61f5422946115a899f3bfa559f429d79dd13f9867ceb046f`.
7. The then-current host-only validator reported `FIRST_BOOT_MEMORY_SAFETY=PASS`
   before the attempt. Post-attempt review invalidated that gate because it did
   not require MSM8x60 SMEM reservation; do not use this historical result for
   another write.

## Executed single-partition experiment

The approved artifact was written once through the only permitted target:

```sh
fastboot flash boot /home/paul/xperia/build/hikari-artifacts-g3/hikari-firstboot.elf
fastboot reboot
```

The first artifact uses a native BusyBox initramfs and emits
`HIKARI MAINLINE EARLY BOOT` and `HIKARI INITRAMFS STARTED` on any available
kernel console.  It does not rely on display, GPU, touch, a guessed ramoops
region, or Android userspace.

## Executed rollback

Hardware entry is independent of Android:

```text
phone off/reset → hold Volume Up → connect USB
→ verify 0fce:0dde and fastboot devices
→ verify the original restore SHA-256 on the host
```

The original p3 was then restored through just p3's `boot` target. S1Boot
reported `Flash operation complete`, and Android returned to the recorded
legacy baseline. The exact sanitized command result is in
[`first-mainline-rollback-sanitized.txt`](../research/device/current/boot/first-mainline-rollback-sanitized.txt).

```sh
fastboot flash boot /home/paul/xperia/backups/hikari/20260901T111716Z/hikari-golden-backup-20260901T190000Z/hikari-original-p3-restore.elf
fastboot reboot
```

Never use `erase`, `flashall`, a partition-table command, or another partition
in either direction. This restore mapping is now `VERIFIED_DEVICE`; see
[ROLLBACK.md](ROLLBACK.md).

## Observed result and forced recovery

S1Boot accepted the experimental ELF and reported a successful `boot` flash.
After `fastboot reboot`, the host observed no ADB, fastboot, new target USB
device, or project boot marker during 120 seconds; no Linux display output was
observed. The owner observed a black screen and an unresponsive handset.
This does not identify a kernel panic or a specific failure stage.

An ordinary Power hold did not recover the hung handset. **Power + Volume Up**
forced reset/shutdown (`VERIFIED_DEVICE` operational observation). This differs
from S1Boot entry, which remains phone off + Volume Up + USB. See
[HOST_USB.md](HOST_USB.md). The complete sanitized attempt record is
[`first-mainline-boot-attempt-sanitized.txt`](../research/device/current/boot/first-mainline-boot-attempt-sanitized.txt).

## Abort conditions

Abort before any write if USB identity is unexpected, fastboot is unstable,
the device identity or partition layout differs, either SHA-256 differs, the
experimental image exceeds p3, any host validation fails, or S1Boot returns an
unexpected response.  Stop and collect evidence rather than trying a second
operation or a different bootloader command.

## Second-attempt cross-reference

The later, separately approved second artifact was also accepted by S1Boot but
produced no observable target-Linux proof during 120 seconds. The same exact
original p3 restore completed and Android returned. Its post-mortem buffer was
not preserved because Android ran before TWRP capture; see
[SECOND_BOOT_PLAN.md](SECOND_BOOT_PLAN.md) and the sanitized
[post-mortem record](../research/device/current/boot/secondboot-postmortem.md).
