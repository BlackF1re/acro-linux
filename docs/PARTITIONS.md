# Partition map

This is the exact user-area map of the physical handset. It has been checked
three ways: live target-Linux MBR/EBR parsing, live kernel sysfs partition
objects, and an offline fdisk/sfdisk audit of the complete pre-experiment
backup. All three agree on the 15,634,268,160-byte device and every start and
size. Filesystem detection was read-only. Device identifiers and UUIDs are not
recorded.

| Part | Start (512-B sectors) | Sectors | Size | MBR type | Established role / confidence |
| --- | ---: | ---: | ---: | ---: | --- |
| p1 | 1 | 4,096 | 2 MiB | `0xf0` | TA-related opaque store: exact-device legacy `tad` is passed this device. `VERIFIED_DEVICE`; payload not inspected. |
| p2 | 4,097 | 1,024 | 512 KiB | `0x4d` | SBL1 according to Qualcomm LK's type map. `VERIFIED_UPSTREAM` type meaning; exact payload not inspected. Boot flag set. |
| p3 | 8,192 | 40,960 | 20 MiB | `0x48` | `boot`: exact-device fstab, Qualcomm LK type map, and physical S1 fastboot mapping all agree. `VERIFIED_DEVICE`. |
| p4 | 49,152 | 30,486,528 | 14.54 GiB | `0x05` | Extended container for p5--p15; not a payload filesystem. `VERIFIED_DEVICE`. |
| p5 | 50,176 | 1,024 | 512 KiB | `0x46` | TZ according to Qualcomm LK's type map. Exact payload not inspected. |
| p6 | 53,248 | 6,144 | 3 MiB | `0x4a` | modem_st1 according to Qualcomm LK's type map. Treat as radio-critical. |
| p7 | 61,440 | 6,144 | 3 MiB | `0x4b` | modem_st2 according to Qualcomm LK's type map. Treat as radio-critical. |
| p8 | 69,632 | 6,144 | 3 MiB | `0x58` | `UNKNOWN`; vendor/secure area. |
| p9 | 77,824 | 10,240 | 5 MiB | `0x70` | `UNKNOWN`; vendor/secure area. |
| p10 | 90,112 | 16,384 | 8 MiB | `0x83` | `/data/idd`, ext4. `VERIFIED_DEVICE`. |
| p11 | 106,496 | 32,768 | 16 MiB | `0xf0` | FOTA/recovery payload referenced by the p3 bootrec controller. `VERIFIED_DEVICE` role relationship; independence from p3 remains `UNKNOWN`. |
| p12 | 139,264 | 2,097,152 | 1 GiB | `0x83` | Android `/system`, ext4. `VERIFIED_DEVICE`. |
| p13 | 2,236,416 | 512,000 | 250 MiB | `0x83` | Android `/cache`, ext4. `VERIFIED_DEVICE`. |
| p14 | 2,748,416 | 4,194,304 | 2 GiB | `0x83` | Android `/data`, ext4. `VERIFIED_DEVICE`. |
| p15 | 6,942,720 | 23,592,960 | 11.25 GiB | `0x0c` | Non-removable shared storage (`sdcard0`), vfat. `VERIFIED_DEVICE`. |

No filesystem label is present on p10 or p12--p15, and no by-name symlink
directory or MTD device was exposed. The role names above are evidence-backed
descriptions, not filesystem labels. Generic fdisk names for Sony type `0xf0`
must not be used to infer a role.

The eMMC also exposes 2 MiB `boot0` and `boot1` hardware regions; they were not
read and are absent from the user-area backup. RPMB was not inspected. p1--p11,
boot0, boot1 and RPMB are excluded from Linux installation targets. In
particular p2, p5--p9 may contain the boot/security/radio chain, p3 is the
working Sony ELF, and p11 is part of the observed recovery relationship.

## Safe Linux storage conclusion

The large-data candidates are p12--p15 only. Reusing any of them destroys the
corresponding Android data. The lowest-risk internal-root layout does **not**
change the MBR/EBR at all: after a separately approved backup/restore test,
reformat only p15 as ext4 and place the Debian root there, while retaining a
known-good Sony ELF in p3. That operation should not replace S1Boot/fastboot,
whose critical regions are outside p15, but this is a design conclusion rather
than authorization to write it. Recovery independence from p3 is still
unknown, so p3 and its verified restore path remain mandatory controls.

For bring-up, microSD is safer than any internal conversion: a stable p3
bootstrap can mount a Debian root from the removable card. The card path must
first pass physical detection and read/write tests under target Linux; no
`mmcblk1` was present during the 2026-09-14 audit.

Raw evidence: [mainline-partition-audit-20260914.txt](../research/device/current/storage/mainline-partition-audit-20260914.txt),
[backup-offline-validation.txt](../research/device/current/storage/backup-offline-validation.txt),
[partition-map-evidence.md](../research/device/current/storage/partition-map-evidence.md),
[fstab-semc-extract.txt](../research/device/current/storage/fstab-semc-extract.txt),
and [init-semc-extract.txt](../research/device/current/storage/init-semc-extract.txt).
