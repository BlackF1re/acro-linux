# Read-only recovery characterization

Date: 2026-09-01. Following owner approval, Android entered recovery once via
`adb reboot recovery`. No install, flash, wipe, format, restore, sideload,
manual mount, partitioning, or touchscreen action was performed by the project.

- USB enumerated as `0fce:6176`, Xperia Acro S; ADB reported `recovery`.
- The recovery kernel reported `3.4.0-Elite-1.5+` on ARMv7.
- `/proc/partitions` exposed the established `mmcblk0` p1--p15 topology.
- Its own recovery runtime mounted p13 and p15 read-write. This was observed,
  not requested or modified by the project.
- Direct recovery binary/log evidence identifies **TWRP 2.6.3.0**;
  `ro.twrp.boot=1` was also present.

The collected cmdline was sanitized; serial-derived and TA-related arguments
are omitted. Recovery-log serial-derived backup paths were not retained.

`adb reboot` did not complete a transition to Android and no safe recovery CLI
reboot command was identified. The owner then selected **Reboot System**. ADB
confirmed return to `LT26w` / `fuji`, `ScrubbModRom KK4.4.2 v.1.4.1`, and the
same `3.4.0-Elite-1.5+` legacy kernel.

This does not identify the partition or boot path that loads TWRP. Its
independence from p3 remains `UNKNOWN`; it is not an independently proven
rollback route for a p3 replacement.
