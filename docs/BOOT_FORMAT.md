# Current Hikari legacy boot format

## Scope and provenance

This analysis is limited to the confirmed `mmcblk0p3` legacy `/boot` range in the private C2 golden backup. It did not read the phone again and did not inspect any sensitive/unknown partition. The p3 extraction was performed in a private temporary directory outside Git.

| Field | Value |
| --- | --- |
| Start | sector 8,192 (512-byte sectors), offset 4,194,304 bytes |
| Length | 40,960 sectors, 20,971,520 bytes (20 MiB) |
| SHA-256 | `c59be74873aa32a8422adf9b5402254b2acae619f7dc97bd50fc0e120984d0c1` |
| Container | ELF32, little-endian, `ET_EXEC`, ARM, no section-header table |
| Outer entry | `0x40208000` |

The complete sanitized machine-readable metadata is [current-boot-elf-metadata.txt](../research/device/current/boot/current-boot-elf-metadata.txt). No p3 image or payload data is in the repository.

## Verified-device outer ELF layout

| # | File offset | Load address (vaddr=paddr) | Size | `p_flags` | Identification |
| ---: | ---: | ---: | ---: | ---: | --- |
| 0 | `0x001000` | `0x40208000` | `0x662d90` | `0x00000000` | ARM Linux zImage |
| 1 | `0x663d90` | `0x41800000` | `0x396549` | `0x80000000` | gzip ramdisk |
| 2 | `0x9fa2d9` | `0x00020000` | `0x1d3e8` | `0x01000000` | nested ARM ELF, RPM-marked |

The three payloads begin at `0x1000` and are contiguous: there are no gaps between them. The final partition space is not interpreted as a required format feature. The third payload is itself an ELF32 ARM executable with entry `0x00020000`.

Historical Sony `mkelf.py` defines `0x80000000` as the RAMDISK flag and `0x01000000` as the Qualcomm MSM8x60 RPM flag. That makes the legacy source a strong explanation of the flags observed in the physical p3 artifact; the addresses and sizes above remain `VERIFIED_DEVICE` rather than inferred values.

## Cmdline and construction

The current p3 has exactly three `PT_LOAD` program headers. It has no `PT_NOTE` segment carrying Sony's `P_FLAGS_CMDLINE` flag, so a standalone ELF cmdline segment is absent. The exact source and handling of the current kernel command line are therefore `UNKNOWN`; no command-line payload was retained.

The historical LT26 AOSP configuration constructs an analogous `boot.elf` as kernel, gzip ramdisk, and RPM firmware using `mkelf.py`. It provides useful format provenance, but its ramdisk address (`0x41300000`) conflicts with this Hikari p3's directly observed `0x41800000`. Future Hikari artifacts must use the verified Hikari value unless later physical evidence supersedes it.

## Implications, not authorization

This is a legacy Android artifact, not a target-Linux image specification. A future artifact proposal must independently validate its exact size, all segments, firmware licensing/provenance, diagnostics, and rollback path before any owner-approved write. `fastboot boot` support remains `UNKNOWN`; no image has been sent to this phone.

## Sources

- [AOSP LT26 custombootimg.mk, commit 8213cd2eabf386629f56cc1ac6b8102ffd0671eb](https://android.googlesource.com/device/sony/lt26/%2B/8213cd2eabf386629f56cc1ac6b8102ffd0671eb/custombootimg.mk)
- [AOSP LT26 mkelf.py introduction, commit b644924c93b3c89e0e6f3aeeb85fb9a23147350f](https://android.googlesource.com/device/sony/lt26/%2B/b644924c93b3c89e0e6f3aeeb85fb9a23147350f%5E!/)
