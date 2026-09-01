# Hikari Device-Tree boot strategy

## Legacy constraint

The observed legacy boot is board-file/ATAG-era. Its Sony ELF contains no DTB
or standalone cmdline segment. S1Boot DTB hand-off has not been proven, so a
separate ELF DTB segment must not be invented.

## First local-build strategy

The evidence-backed working hypothesis for a first native kernel is:

```
S1Boot -> Sony ELF -> ARM zImage with appended Hikari DTB -> native initramfs
```

The target kernel will be configured with `CONFIG_ARM_APPENDED_DTB` and the
Hikari DTB will be appended by local build tooling. `CONFIG_ARM_ATAG_DTB_COMPAT`
is retained only as a compatibility aid for legacy bootloader ATAG memory and
cmdline information, not as proof that an ATAG will be present. The native
initramfs supplies `/init`; no Android userspace or Android HAL participates.

This is a first-boot **candidate**, not `VERIFIED_DEVICE`: its compatibility
with the exact S1Boot, decompressor placement, supplied ATAGs, and target
memory layout must be tested only after a separate deployment approval.

## Rejected assumptions

- No Sony ELF DTB segment is evidenced in the current p3.
- No S1Boot DTB-passing capability is assumed.
- The legacy Hikari kernel's actual appended-DTB configuration is unknown
  because its embedded configuration could not be recovered.
- Values from MSM8960 Xperia devices are not used.

## Provenance

The outer ELF observation is in [BOOT_FORMAT.md](BOOT_FORMAT.md). The
historical LT26 `mkelf.py` source documents kernel/ramdisk/RPM/cmdline flags,
but not a Hikari DTB segment. Current upstream ARM supports appended DTB and
ATAG-to-DT compatibility; its exact selected revision is recorded in
[SOURCES.md](SOURCES.md).
