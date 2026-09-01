# Partition-map evidence

Method: read-only sysfs partition metadata, /proc/mounts and /fstab.semc. No
raw block device was opened.

| Partition | Start sector | Sectors | Role evidence |
| --- | ---: | ---: | --- |
| mmcblk0p1 | 1 | 4096 | init.semc.rc invokes tad with this block device; opaque TA-related role only |
| mmcblk0p2 | 4097 | 1024 | no role evidence |
| mmcblk0p3 | 8192 | 40960 | fstab.semc: /boot, emmc, recoveryonly |
| mmcblk0p4 | 49152 | 2 | no role evidence |
| mmcblk0p5 | 50176 | 1024 | no role evidence |
| mmcblk0p6 | 53248 | 6144 | no role evidence |
| mmcblk0p7 | 61440 | 6144 | no role evidence |
| mmcblk0p8 | 69632 | 6144 | no role evidence |
| mmcblk0p9 | 77824 | 10240 | no role evidence |
| mmcblk0p10 | 90112 | 16384 | mounted ext4 at /data/idd |
| mmcblk0p11 | 106496 | 32768 | no role evidence |
| mmcblk0p12 | 139264 | 2097152 | fstab and mount: /system ext4 |
| mmcblk0p13 | 2236416 | 512000 | fstab and mount: /cache ext4 |
| mmcblk0p14 | 2748416 | 4194304 | fstab and mount: /data ext4 |
| mmcblk0p15 | 6942720 | 23592960 | fstab voldmanaged=sdcard0:15; mounted vfat shared storage |

No /dev/block/platform/*/by-name directory and no /proc/mtd entry were
present.
