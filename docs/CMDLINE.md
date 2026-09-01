# Hikari legacy command-line provenance

## Established facts

The confirmed current p3 Sony ELF has three loadable segments only: kernel,
gzip ramdisk, and RPM-marked ELF. There is no segment with Sony's historical
`P_FLAGS_CMDLINE` flag (`0x20000000`). Therefore p3 does not supply a
standalone ELF command-line payload. This is `VERIFIED_DEVICE` through the
private offline p3 analysis; its sanitized metadata is
[current-boot-elf-metadata.txt](../research/device/current/boot/current-boot-elf-metadata.txt).

The current legacy zImage contains an `IKCFG_ST` marker but no recoverable
`IKCFG_ED` trailer. The standard extractor cannot recover a valid gzip kernel
configuration from it, so the current values of `CONFIG_CMDLINE`,
`CONFIG_CMDLINE_FORCE`, `CONFIG_ARM_APPENDED_DTB`, and related options are
`UNKNOWN`.

## Evidence-ranked mechanisms

| Mechanism | Evidence | Status |
| --- | --- | --- |
| Bootloader `ATAG_CMDLINE` | Plausible for this board-file/ATAG-era platform; no current bootloader record was captured | `HYPOTHESIS` |
| Built-in kernel command line | Historical OpenSEMC `fuji_hikari_row_defconfig` sets `CONFIG_CMDLINE="androidboot.hardware=semc androidboot.baseband=msm"` and `CONFIG_CMDLINE_EXTEND=y`; it is not the current kernel configuration | `HISTORICAL_SOURCE` |
| Standalone Sony ELF cmdline segment | Absent in the actual p3 ELF | `VERIFIED_DEVICE` absent |
| Appended DTB / ATAG-to-DT handling | No current zImage configuration was recoverable | `UNKNOWN` |

Userspace properties and `androidboot.*` consumers do not establish the source
of the kernel's `/proc/cmdline`; they are downstream interpretation only.

## Target consequence

The first target kernel must own an explicit, documented cmdline strategy. It
must not assume that this S1Boot accepts a Sony ELF cmdline segment. The chosen
strategy is recorded separately in [DT_BOOT.md](DT_BOOT.md) and remains a
local-build proposal until a phone experiment is separately approved.
