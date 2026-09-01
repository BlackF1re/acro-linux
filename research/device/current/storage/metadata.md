# Storage metadata

- Internal non-removable `mmcblk0`: 30,535,680 512-byte sectors
  (15,634,268,160 bytes / 15.6 GB decimal).
- Fifteen partitions are enumerated. No external microSD block device was
  present at collection time.
- Mounted, readable metadata: p10 → `/data/idd` (ext4), p12 → `/system`
  (ext4), p13 → `/cache` (ext4), p14 → `/data` (ext4), p15 → Android shared
  storage (`vfat` via vold/FUSE). No raw partition contents were read.

| Partition | Size (KiB) | Observed role |
|---|---:|---|
| p1 | 2,048 | opaque TA/tad-related reference; contents not read |
| p2 | 512 | unknown vendor partition |
| p3 | 20,480 | `/boot` in fstab.semc (recovery-only entry) |
| p4 | 1 | extended-partition container |
| p5 | 512 | unknown vendor partition |
| p6–p8 | 3,072 each | unknown vendor partitions |
| p9 | 5,120 | unknown vendor partition |
| p10 | 8,192 | mounted `/data/idd` |
| p11 | 16,384 | unknown vendor partition |
| p12 | 1,048,576 | mounted `/system` |
| p13 | 256,000 | mounted `/cache` |
| p14 | 2,097,152 | mounted `/data` |
| p15 | 11,796,480 | mounted shared storage (vfat) |

`busybox fdisk -l` was used solely to read the partition table. Its generic
type labels must not be interpreted as Sony partition names. In particular,
no inference about modem/NV, calibration, or recovery locations is safe from
this collection alone. The p1 tad reference and p3 boot role are separately
established by the selected safe fstab/init excerpts.

Evidence: [fstab-semc-extract.txt](fstab-semc-extract.txt) and
[init-semc-extract.txt](init-semc-extract.txt).

Evidence: `VERIFIED_DEVICE` for sizes and currently mounted roles;
`UNKNOWN` for the names/purpose of unlabelled partitions.
