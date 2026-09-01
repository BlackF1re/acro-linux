# Current Hikari legacy boot format

Offline analysis was limited to confirmed `mmcblk0p3` legacy `/boot` in the
private C2 golden backup, never the phone or sensitive/unknown partitions.

| Field | Value |
| --- | --- |
| Start | sector 8,192, offset 4,194,304 bytes |
| Length | 40,960 sectors, 20,971,520 bytes (20 MiB) |
| SHA-256 | `c59be74873aa32a8422adf9b5402254b2acae619f7dc97bd50fc0e120984d0c1` |
| Container | ELF32 LE, `ET_EXEC`, ARM, no section headers |
| Outer entry | `0x40208000` |

| # | File offset | Load address | Size | `p_flags` | Identification |
| ---: | ---: | ---: | ---: | ---: | --- |
| 0 | `0x001000` | `0x40208000` | `0x662d90` | `0x00000000` | ARM Linux zImage |
| 1 | `0x663d90` | `0x41800000` | `0x396549` | `0x80000000` | gzip ramdisk |
| 2 | `0x9fa2d9` | `0x00020000` | `0x1d3e8` | `0x01000000` | nested ARM ELF, RPM-marked |

Payloads are contiguous from `0x1000`. The final partition slack is not
interpreted. Historical Sony `mkelf.py` explains the RAMDISK and RPM flag
values; physical addresses/sizes are `VERIFIED_DEVICE`. No standalone cmdline
segment (`PT_NOTE` with Sony cmdline flag) exists; exact cmdline handling is
`UNKNOWN`. No p3 payload is included in Git or this directory.
