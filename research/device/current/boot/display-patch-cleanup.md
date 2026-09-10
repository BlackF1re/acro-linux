# Hikari display patch cleanup candidate (2026-09-11)

Implementation state: `IMPLEMENTING`; physical state: `NOT_VERIFIED`.

The physically accepted 0066 source stack contained five MSM IOMMU experiment
patches that no longer had a runtime consumer after MDP moved to contiguous
physical CMA scanout. The cleanup candidate removes patches 0040–0042 and
0063–0064 from the production series and archives them under
`research/patches/retired-display-iommu/`.

Patch 0039 remains because it documents the correct MSM8660-compatible binding.
Both physical MDP IOMMU provider nodes remain in the board DTS as hardware
inventory, but are explicitly disabled. MDP remains detached from them and
retains the physically accepted CMA scanout path from patch 0065.

The cleanup intentionally does not squash independent clock, DSI, panel,
interconnect, vblank or scanout fixes merely to reduce the patch count. Those
changes represent distinct upstream-reviewable units and remain exercised by
the accepted display path.

The clean series materialized on pinned Linux base
`786262be6048deab760f68c8acc2c85607165894`; its resulting kernel source head
is `3b2e20de0d4933465b57b6a913fb70d5a3e26057`. All 60 production patches
applied. The materializer's MMCC correction, display finalization, MMCC source,
display source and AS3676 source gates passed.

The cleanup kernel was built from a byte-identical copy of the accepted 0066
kernel configuration. A tree comparison found no changes under DRM/MSM, the
panel driver or `mmcc-msm8660.c`; the only materialized source changes are the
retired IOMMU driver/binding experiments and the explicit provider-node disable
status. Display, MMCC, USB recovery, ramoops, kernel-source, safe-profile,
GPU-profile, charging and board-hardware gates passed.

The boot-only candidate is:

```text
/home/paul/xperia/build/hikari-artifacts-display-cleanup-0060-20260911/display/hikari-display-fastboot.elf
size:    13,382,219 bytes
SHA-256: 0f08c2f67b6e210c0f45ebe9c228d5fff6e1e48bafe8313066be814764b015bf
```

Its Sony ELF has exactly three load segments at the accepted addresses
`0x40208000`, `0x42c10000` and `0x00020000`. The ARM decompressor, appended
DTB, initramfs, RPM, SMEM and ramoops ranges do not overlap.

The accepted 0066 artifact remains untouched and is the rollback control.
Physical status remains `NOT_VERIFIED` until the cleanup candidate passes a
device boot with readable 720x1280 fbcon, active DRM scanout and no display or
kernel errors.
