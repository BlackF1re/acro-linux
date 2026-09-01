# First physical Hikari boot procedure

This is an operational proposal only.  It requires a new explicit owner
approval before any command in the write or reboot sections is run.

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
7. Re-run the host-only artifact validator.  It must report
   `FIRST_BOOT_MEMORY_SAFETY=PASS` and no ELF/DTB/p3 validation failure.

## Proposed single-partition experiment

Only after the owner approves this exact artifact and preflight result:

```sh
fastboot flash boot /home/paul/xperia/build/hikari-artifacts-g3/hikari-firstboot.elf
fastboot reboot
```

The first artifact uses a native BusyBox initramfs and emits
`HIKARI MAINLINE EARLY BOOT` and `HIKARI INITRAMFS STARTED` on any available
kernel console.  It does not rely on display, GPU, touch, a guessed ramoops
region, or Android userspace.

## Rollback

Hardware entry is independent of Android:

```text
phone off/reset → hold Volume Up → connect USB
→ verify 0fce:0dde and fastboot devices
→ verify the original restore SHA-256 on the host
```

Then, and only with owner approval, restore just p3's `boot` target:

```sh
fastboot flash boot /home/paul/xperia/backups/hikari/20260901T111716Z/hikari-golden-backup-20260901T190000Z/hikari-original-p3-restore.elf
fastboot reboot
```

Never use `erase`, `flashall`, a partition-table command, or another partition
in either direction.  This restore mapping is strongly supported by historical
LT26 evidence but has not yet been write-tested on this handset; see
[ROLLBACK.md](ROLLBACK.md).

## Abort conditions

Abort before any write if USB identity is unexpected, fastboot is unstable,
the device identity or partition layout differs, either SHA-256 differs, the
experimental image exceeds p3, any host validation fails, or S1Boot returns an
unexpected response.  Stop and collect evidence rather than trying a second
operation or a different bootloader command.
