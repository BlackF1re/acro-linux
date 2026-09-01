# Read-only recovery characterization

Date: 2026-09-01. Following owner approval, Android entered recovery once via `adb reboot recovery`. No install, flash, wipe, format, restore, sideload, manual mount, partitioning, or touchscreen action was performed by the project.

## Direct observations

- USB enumerated as `0fce:6176`, Xperia Acro S; ADB reported `recovery`.
- The recovery kernel reported `3.4.0-Elite-1.5+` on ARMv7.
- `/proc/partitions` exposed the established `mmcblk0` p1--p15 topology.
- Its own recovery runtime mounted p13 and p15 read-write. This was observed, not requested or modified by the project; therefore this pass does not claim an immutable recovery filesystem snapshot.
- Direct recovery binary/log evidence identifies **TWRP 2.6.3.0**. The runtime property `ro.twrp.boot=1` was also present.

The command line was collected only in sanitized form; serial-derived and TA-related boot arguments are omitted. Recovery log lines with a serial-derived backup path were not retained.

## Exit

`adb reboot` from this TWRP runtime did not complete a transition to Android,
and no safe recovery command-line reboot tool was identified. The owner then
selected the normal **Reboot System** UI action. Android subsequently returned
over ADB as `LT26w` / `fuji`, running the same observed
`ScrubbModRom KK4.4.2 v.1.4.1` and `3.4.0-Elite-1.5+` legacy kernel. This is an
ordinary reboot only; it is not evidence that TWRP is independent of p3.

## What this does not prove

The current runtime alone does not identify the partition or boot path that loads TWRP. Historical LT26 material says recovery is triggered from a boot image, and the TWRP binary contains injection-related strings, but neither proves the installation layout on this handset. Thus recovery independence from p3 is `UNKNOWN`, and TWRP is not yet an independently proven rollback route for a p3 replacement.
