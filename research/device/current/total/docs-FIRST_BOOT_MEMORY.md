# First Hikari native-boot memory safety

## Inputs

The legacy kernel names System RAM ranges `0x40200000-0x42dfffff` (44 MiB) and
`0x48000000-0x6e5fffff` (614 MiB). These are `VERIFIED_DEVICE` legacy resource
ranges, not a byte-complete inventory of the nominal 1 GiB. See
[MEMORY_MAP.md](MEMORY_MAP.md).

The current legacy Sony ELF places its zImage at `0x40208000`, ramdisk at
`0x41800000`, and RPM ELF at `0x00020000`. Those are observed legacy ranges,
not automatically safe target ranges.

## Current local-build rule

The initial DTS states only the two observed RAM banks and does not reserve a
new ramoops region. The local validator rejects overlapping ELF payloads and
the p3-size limit, but cannot prove decompressor relocation or bootloader
reservations. Therefore a built local artifact is not deployable evidence.

The current local-only ELF prototype has input ranges
`0x40208000+0x0a380e0`, `0x41800000+0x10c2d2`, and
`0x00020000+0x1d3e8` (RPM). Its first two payload ranges lie within the first
observed legacy RAM bank and do not overlap one another; the RPM range lies
outside System RAM. This is an ELF input-range check only: decompressed-kernel
placement and firmware ownership are still not established.

Before any owner-approved device experiment, validate all of the following
against the exact artifact and current upstream decompressor behaviour:

1. zImage input/load/decompression ranges;
2. appended DTB range and resulting FDT placement;
3. initramfs range;
4. RPM segment range and ownership;
5. all target reserved-memory nodes;
6. a ramoops region only after it is shown not to overlap firmware or RAM.

No legacy multimedia carveout is copied mechanically, and no mainline memory
claim is made from the legacy map alone.
