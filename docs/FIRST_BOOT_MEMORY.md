# First Hikari native-boot memory gate

`FIRST_BOOT_MEMORY_SAFETY=BLOCKED` for a subsequent attempt.  The first
physical attempt did not yield proof of life, and post-attempt review found
that its host-side gate omitted a required MSM8x60 SMEM configuration.  This
does not prove that omission caused the failure, but it invalidates the prior
`PASS` as a gate for another write.

## Inputs and decompressor rule

Legacy-device evidence names the first System RAM bank as
`0x40200000-0x42dfffff`.  The prototype uses the physically observed Sony ELF
kernel address `0x40208000`, which is `0x8000` from that bank's beginning.

The first-attempt ARM configuration deliberately had:

```text
CONFIG_ARCH_MULTIPLATFORM=n
CONFIG_AUTO_ZRELADDR=n
CONFIG_PHYS_OFFSET=0x40200000
CONFIG_PAGE_OFFSET=0xc0000000
```

This is necessary: with the normal multiplatform `AUTO_ZRELADDR` algorithm,
`head.S` masks a zImage PC with `0xf8000000`; `0x40208000` would incorrectly
produce `0x40008000`, outside the observed first RAM bank.  The explicit
configuration instead gives `zreladdr = PHYS_OFFSET + TEXT_OFFSET`.

However, the first-attempt configuration omitted
`CONFIG_ARCH_QCOM_RESERVE_SMEM=y`.  Current upstream
`arch/arm/mach-qcom/Kconfig` says that this reserves the first 2 MiB of System
RAM and is required on MSM8x60; `arch/arm/Makefile` then selects
`TEXT_OFFSET=0x00208000`.  The built first-attempt decompressor confirms
`zreladdr=0x40208000`, so that required reservation was not active.  A new
candidate must enable the option, rebuild, and prove
`zreladdr=0x40408000`; it must not reuse the first artifact.

That corrected output address alone is not enough. With the currently observed
Sony ELF input address (`0x40208000`) and the current compressed-image size,
the compressed zImage plus appended DTB intersects the proposed decompressed
kernel interval beginning at `0x40408000`. Current upstream decompressor code
does contain input-relocation handling, but that path has not been proved for
this S1Boot/ELF combination. The host gate therefore rejects such an overlap:
another candidate needs either a proven non-overlapping input address or
separate evidence that makes the relocation path safe.

The current upstream decompressor's `head.S` contains its own input-overlap
relocation handling.  Its documented appended-DTB allowance is conservatively
modelled here as a full 1 MiB clear workspace after the decompressed kernel.
No target ramoops region is reserved, and no legacy carveout was copied.

## Historical first-attempt ranges (not a new deployment gate)

| Object | Physical range | Size | Basis |
| --- | --- | ---: | --- |
| compressed zImage | `0x40208000-0x40c3e16f` | 10,707,312 | exact built input |
| appended DTB | `0x40c3e170-0x40c4007d` | 7,950 | exact built DTB |
| decompressed kernel assumed by the old check | `0x40208000-0x41b23c83` | 26,328,196 | obsolete assumption; the built zreladdr was `0x40208000` because SMEM reservation was absent |
| conservative decompressor/DTB workspace assumed by the old check | `0x41b23c84-0x41c23c83` | 1,048,576 | obsolete gate model |
| native initramfs | `0x42400000-0x4250c2de` | 1,098,463 | exact built input |
| RPM payload | `0x00020000-0x0003d3e7` | 119,784 | private legacy p3 segment; outside System RAM |

The old arithmetic showed a gap to the initramfs, but it was not sufficient:
it did not enforce the upstream MSM8x60 SMEM reservation.  The corrected
host check now refuses a build without it.  After a rebuild it must re-measure
the compressed input, appended DTB, `zreladdr`, decompressed image, relocation
workspace, initramfs and RPM ranges; only then may it report `PASS`. It now
also rejects an input/decompressed-image overlap unless an explicitly proven
Sony-path relocation rule replaces that conservative prohibition.

This does not attribute the remaining nominal RAM, prove firmware ownership,
prove decompressor relocation for the Sony path, or prove S1Boot acceptance.
Those are separate physical-boot observations.
