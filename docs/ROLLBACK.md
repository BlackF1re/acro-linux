# Hikari p3 rollback evidence

This document records the physically used recovery route. It is evidence of
two approved restorations after failed native-Linux attempts; it is not
standing authorization for another write.

## Evidence chain

| Claim | Evidence level | Evidence and limit |
| --- | --- | --- |
| S1Boot fastboot can be entered independently of Android | `VERIFIED_DEVICE` | The physical Volume-Up USB path enumerated this handset as Sony S1Boot Fastboot (`0fce:0dde`). |
| LT26 `/boot` is `mmcblk0p3` | `VERIFIED_VENDOR_SOURCE` | Official historical AOSP/Sony LT26 [`recovery.fstab`](https://android.googlesource.com/device/sony/lt26/+/8213cd2eabf386629f56cc1ac6b8102ffd0671eb/recovery.fstab) states `/boot emmc /dev/block/mmcblk0p3`.  The handset's sanitized legacy fstab separately maps p3 to its legacy boot role. |
| LT26 build output is a Sony boot ELF intended for fastboot flashing | `HISTORICAL_SOURCE` | The same AOSP LT26 revision's [`custombootimg.mk`](https://android.googlesource.com/device/sony/lt26/+/8213cd2eabf386629f56cc1ac6b8102ffd0671eb/custombootimg.mk) creates `boot.img` with `mkelf.py`; historical acro S installation material directly uses `fastboot flash boot boot.img`. |
| S1Boot accepts `fastboot flash boot` on this handset | `VERIFIED_DEVICE` | The two failed experiments and their rollbacks reported `Flash of partition 'boot' requested`, `S1 partID 0x00000003`, and blocks `0x00002000-0x0000bfff`, then `Flash operation complete`. Sanitized records are under `research/device/current/boot/`. |
| Exact legacy p3 restore bytes exist | `VERIFIED_DEVICE` | Private offline p3 copy: 20,971,520 bytes, SHA-256 `c59be74873aa32a8422adf9b5402254b2acae619f7dc97bd50fc0e120984d0c1`. |

## Classification

`FASTBOOT_P3_RESTORE`, `PHYSICAL_FASTBOOT_P3_RESTORE`,
`FAILED_MAINLINE_BOOT_ROLLBACK`, and `ROLLBACK_AFTER_SECOND_BOOT` are
**`VERIFIED_DEVICE`**. After hardware S1Boot entry remained available following
each unusable experimental p3, the exact original p3 ELF was accepted through
the logical `boot` target and the ScrubbModRom Android baseline booted normally.
This directly establishes a repeatably working p3 rollback route for this
handset and exact restore artifact.

The write response corroborates the historical LT26 p3 mapping, but it does
not make writes to another logical target or partition safe. Future writes
remain owner-gated and must use only a verified artifact and `boot` target.

`fastboot boot` remains **`UNKNOWN`**.  It is neither needed nor proposed for
rollback.

## Operational boundary

The original p3 is a private artifact outside Git. Sensitive raw backup data
was not parsed or exposed. Both historical attempts and their completed
rollbacks are recorded in [FIRST_PHYSICAL_BOOT.md](FIRST_PHYSICAL_BOOT.md) and
[SECOND_BOOT_PLAN.md](SECOND_BOOT_PLAN.md).

For a future boot #4 diagnostic attempt, recovery capture is part of the
rollback procedure: after restoring original p3, enter TWRP before Android and
capture its preserved previous console before reading the live persistent-RAM
area.  The precise owner-gated sequence is in
[BOOT4_POSTMORTEM_PLAN.md](BOOT4_POSTMORTEM_PLAN.md).  This addition does not
broaden the logical-`boot` whitelist or authorize a flash.
