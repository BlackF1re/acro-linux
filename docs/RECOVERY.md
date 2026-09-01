# Recovery and experimental-boot safety

## Current position

The physical-device work was read-only. No external recovery-partition
payload, bootloader-state payload, or sensitive partition payload has been
separately inspected, parsed, interpreted, extracted, exposed, or committed.
Offline p3 analysis did extract its non-sensitive bootrec controller and the
packaged recovery ramdisk solely to characterize the recovery path; it did not
inspect p11. Later C2 work sequentially read the complete accessible
`/dev/block/mmcblk0` user area into private recovery media, so p1--p15 (including potentially
TA-related, radio/NV, or calibration-bearing bytes) are physically covered by
that private stream.  The legacy kernel did not expose eMMC boot0, boot1, or
RPMB nodes; those areas are not covered. The recovery *environment* is
reachable, but its storage layout and suitability as an independent rollback
route were not established by that capture.

A follow-up read-only check found the legacy `/fstab.semc` and
`/init.semc.rc`, but no `/system/etc/recovery.fstab`,
`/system/etc/install-recovery.sh`, `/system/recovery-from-boot.p`,
`/recovery.fstab`, or `/cache/recovery/command` in the running system.  This is
evidence only that those common Android recovery artifacts are absent from the
checked paths; it neither proves nor rules out a Sony FOTAKernel-style route,
a separate recovery partition, or recovery code embedded in another boot path.
One owner-approved, non-destructive recovery entry has now been observed. It
is **TWRP 2.6.3.0**, directly identified by its recovery binary and runtime
log; `ro.twrp.boot=1` was also present. See the sanitized [recovery
characterization](../research/device/current/boot/recovery-characterization.md).
The older Android-path check remains useful negative evidence only.

The known partition-role evidence is intentionally narrow: p3 is referenced as
legacy `/boot`; p1 has a legacy `tad` reference; p10, p12–p15 have the roles
documented in [PARTITIONS.md](PARTITIONS.md).  All other unconfirmed roles are
UNKNOWN.  This is not enough to authorize any write.

The running Android property `ro.bootloader=unknown` is not a lock-state
attestation. A later physical fastboot session did observe `secure: no`, but
the legacy S1Boot `unlocked` variable is empty. Owner-provided unlock history
is consistent evidence, not a replacement for a standard attestation.

Offline analysis of the confirmed p3 image shows a bootrec controller in its
ramdisk. On a recovery decision it reads an ELF from `mmcblk0p11`, extracts its
ramdisk, and executes that ramdisk's `/init`. p3 also contains a packaged
TeamWin recovery ramdisk, but the controller explicitly replaces it from p11
on this path. p11 itself was not read or extracted. This proves an external
FOTA/recovery-payload reference, not the current p11 payload's identity, a
separate recovery partition, or a route independent of p3. See the
[sanitized p3 bootrec evidence](../research/device/current/boot/p3-bootrec-sanitized.txt).

## Recovery selection from the original p3

The original p3 bootrec controller gives a directly derived recovery selector:
it opens `/dev/input/event0`, waits for a **fresh** event for three seconds,
and takes the p11 recovery branch if it received one (or if its cache recovery
flag exists). Direct input evidence identifies that event device as
`keypad-pmic-fuji`; the matching historical Hikari keypad source maps it to
**Volume Up**. The operational sequence is therefore repeated Volume-Up
presses from immediately before normal boot begins through its first 3–5
seconds. A button held only before bootrec opens the event device may not
produce the required event. The controller transiently shows red and blue LEDs
during the window and blue after it chooses recovery.

This is `VERIFIED_FROM_CURRENT_P3_ARTIFACT` for the controller behaviour, with
the exact key identity corroborated by a historical source. It is not yet
`VERIFIED_DEVICE` as a direct S1Boot-to-recovery procedure: the attempted
sequence subsequently booted legacy Android instead. A later manual TWRP entry
also came after Android had run, so it could not preserve the secondboot
post-mortem buffer. See the [post-mortem record](../research/device/current/boot/secondboot-postmortem.md).

TWRP is therefore `VERIFIED_DEVICE` as a reachable recovery environment, while
its physical storage, whether it survives a p3 replacement, and whether it is
an independent rollback route remain `UNKNOWN`. It must not be used as the
sole rollback guarantee for a p3 replacement.

## Mandatory gate before a future write

The project owner must explicitly approve each destructive stage.  A proposed
stage must include:

1. exact connected-device identification and current partition-layout check;
2. recovery/restore route proved independently of the target being changed;
3. verified backups of critical accessible storage, with hashes and restore
   procedure;
4. single-partition whitelist, expected image hash and format validation;
5. planned early/persistent/serial diagnostics and a rollback decision point.

Never include TA, bootloader areas, partition tables, modem/baseband, radio/NV,
calibration, recovery, or unknown partitions in a generic flashing operation.
The only candidate for a later narrowly-scoped experiment is the confirmed
legacy boot-role p3, and even that is prohibited until every gate above and
explicit owner approval are satisfied.

## Logging plan

The legacy dmesg records a `ram_console` allocation at `0x7ffe0000` (128 KiB),
which is evidence of a legacy persistent-log facility, not proof that a modern
kernel can reuse it unchanged.  Future work should first determine current
ramoops/pstore support and the bootloader’s preservation behaviour.  It must
not reserve addresses by assumption or modify the current phone while this
research authorization remains read-only.
