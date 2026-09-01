# Recovery and experimental-boot safety

## Current position

This repository contains only read-only reconnaissance.  No recovery image,
bootloader state, or sensitive partition payload has been separately
inspected, parsed, interpreted, extracted, exposed, or committed.  Later C2
work did sequentially read the complete accessible `/dev/block/mmcblk0` user
area into private recovery media, so p1--p15 (including potentially
TA-related, radio/NV, or calibration-bearing bytes) are physically covered by
that private stream.  The legacy kernel did not expose eMMC boot0, boot1, or
RPMB nodes; those areas are not covered.  No recovery route is therefore
proven today.

A follow-up read-only check found the legacy `/fstab.semc` and
`/init.semc.rc`, but no `/system/etc/recovery.fstab`,
`/system/etc/install-recovery.sh`, `/system/recovery-from-boot.p`,
`/recovery.fstab`, or `/cache/recovery/command` in the running system.  This is
evidence only that those common Android recovery artifacts are absent from the
checked paths; it neither proves nor rules out a Sony FOTAKernel-style route,
a separate recovery partition, or recovery code embedded in another boot path.
One owner-approved, non-destructive recovery entry has now been observed. It
is **TWRP 2.6.3.0**, directly identified by its recovery binary and runtime
log; `ro.twrp.boot=1` was also present. See the canonical sanitized recovery
characterization in `research/device/current/boot/recovery-characterization.md`.
The older Android-path check remains useful negative evidence only.

The known partition-role evidence is intentionally narrow: p3 is referenced as
legacy `/boot`; p1 has a legacy `tad` reference; p10, p12–p15 have the roles
documented in [PARTITIONS.md](PARTITIONS.md).  All other unconfirmed roles are
UNKNOWN.  This is not enough to authorize any write.

The running Android property `ro.bootloader=unknown` is not a lock-state
attestation. A later physical fastboot session did observe `secure: no`, but
the legacy S1Boot `unlocked` variable is empty. Owner-provided unlock history
is consistent evidence, not a replacement for a standard attestation.

Current TWRP does **not** yet prove a separate recovery partition, FOTAKernel,
or a path independent of p3. Historical LT26 sources say recovery is triggered
from a boot image, and this TWRP binary has injection-related code, but the
installation layout of this handset remains UNKNOWN. It must not be used as the
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
