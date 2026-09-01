# Partition map

This map was produced without reading raw partition contents. Sizes and sector
starts came from sysfs; roles came only from mounted filesystems and fstab.semc.

| Partition | Start (512-byte sectors) | Size | Established legacy role |
| --- | ---: | ---: | --- |
| p1 | 1 | 2 MiB | Opaque TA-related storage reference: legacy tad receives this block device. Contents not separately inspected; its bytes are only present in the private sequential raw backup. |
| p2 | 4097 | 512 KiB | UNKNOWN |
| p3 | 8192 | 20 MiB | boot (fstab.semc, recovery-only entry) |
| p4 | 49152 | 1 KiB | UNKNOWN |
| p5 | 50176 | 512 KiB | UNKNOWN |
| p6 | 53248 | 3 MiB | UNKNOWN |
| p7 | 61440 | 3 MiB | UNKNOWN |
| p8 | 69632 | 3 MiB | UNKNOWN |
| p9 | 77824 | 5 MiB | UNKNOWN |
| p10 | 90112 | 8 MiB | /data/idd, ext4 |
| p11 | 106496 | 16 MiB | FOTA/recovery payload referenced by the p3 bootrec controller; p11 payload itself was not read |
| p12 | 139264 | 1 GiB | /system, ext4 |
| p13 | 2236416 | 250 MiB | /cache, ext4 |
| p14 | 2748416 | 2 GiB | /data, ext4 |
| p15 | 6942720 | 11.25 GiB | non-removable shared storage (sdcard0), vfat |

No by-name symlink directory and no MTD device was exposed. There is no safe
basis to map the remaining vendor partitions. They remain UNKNOWN,
particularly possible radio/NV, calibration, baseband, recovery, or
bootloader storage. The lack of an identified recovery partition is not
evidence that recovery does not exist.

Raw evidence: [partition-map-evidence.md](../research/device/current/storage/partition-map-evidence.md),
[fstab-semc-extract.txt](../research/device/current/storage/fstab-semc-extract.txt),
and [init-semc-extract.txt](../research/device/current/storage/init-semc-extract.txt).
