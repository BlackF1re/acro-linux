# Hikari p3 rollback evidence

This document describes a proposed recovery route.  It does not authorize a
write and no p3 write has been performed on this handset.

## Evidence chain

| Claim | Evidence level | Evidence and limit |
| --- | --- | --- |
| S1Boot fastboot can be entered independently of Android | `VERIFIED_DEVICE` | The physical Volume-Up USB path enumerated this handset as Sony S1Boot Fastboot (`0fce:0dde`). |
| LT26 `/boot` is `mmcblk0p3` | `VERIFIED_VENDOR_SOURCE` | Official historical AOSP/Sony LT26 [`recovery.fstab`](https://android.googlesource.com/device/sony/lt26/+/8213cd2eabf386629f56cc1ac6b8102ffd0671eb/recovery.fstab) states `/boot emmc /dev/block/mmcblk0p3`.  The handset's sanitized legacy fstab separately maps p3 to its legacy boot role. |
| LT26 build output is a Sony boot ELF intended for fastboot flashing | `HISTORICAL_SOURCE` | The same AOSP LT26 revision's [`custombootimg.mk`](https://android.googlesource.com/device/sony/lt26/+/8213cd2eabf386629f56cc1ac6b8102ffd0671eb/custombootimg.mk) creates `boot.img` with `mkelf.py`; historical acro S installation material directly uses `fastboot flash boot boot.img`. |
| S1Boot treats `boot` as a flash partition name on this generation | `HISTORICAL_SOURCE` | Historical Xperia S1Boot logs record `Flash of partition 'boot' requested` for that command.  This is generation evidence, not an observation of a write on this phone. |
| Exact legacy p3 restore bytes exist | `VERIFIED_DEVICE` | Private offline p3 copy: 20,971,520 bytes, SHA-256 `c59be74873aa32a8422adf9b5402254b2acae619f7dc97bd50fc0e120984d0c1`. |

## Classification

`FASTBOOT_P3_RESTORE` is **`STRONGLY_SUPPORTED_HISTORICAL_SOURCE`**:
the authoritative LT26 partition mapping, historical Sony ELF build flow,
historical acro S command, physical independent S1Boot entry, and preserved
original p3 form a coherent restoration route.

It is **not** `VERIFIED_DEVICE` as a restore operation: no `fastboot flash`
write has been intentionally tested on this exact handset.  A first approved
write must retain the original p3 artifact and use only the `boot` target; no
erase, partition-table operation, or other partition is part of this route.

`fastboot boot` remains **`UNKNOWN`**.  It is neither needed nor proposed for
rollback.

## Operational boundary

The original p3 is a private artifact outside Git.  Sensitive raw backup data
was not parsed or exposed.  The first physical boot procedure and its abort
conditions are recorded in [FIRST_PHYSICAL_BOOT.md](FIRST_PHYSICAL_BOOT.md);
that procedure still requires a separate explicit owner approval.
