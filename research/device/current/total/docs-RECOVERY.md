# Recovery and experimental-boot safety

## Current position

This repository contains only read-only reconnaissance.  No recovery image,
partition contents, bootloader state, TA contents, radio/NV data or calibration
contents have been read.  No recovery route is therefore proven today.

The known partition-role evidence is intentionally narrow: p3 is referenced as
legacy `/boot`; p1 has a legacy `tad` reference; p10, p12–p15 have the roles
documented in [PARTITIONS.md](PARTITIONS.md).  All other unconfirmed roles are
UNKNOWN.  This is not enough to authorize any write.

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
