# Hikari first-boot memory analysis

## Post-secondboot reassessment

The former `SECOND_BOOT_MEMORY_SAFETY=PASS` classification applied only to
internal overlap arithmetic after treating `0x40200000` as physical RAM base.
It is **invalidated as a deployment gate**. `SECOND_BOOT_MEMORY_SAFETY` is now
`BLOCKED` pending a corrected RAM-base model and a new independently validated
artifact; it does not claim that this was the only secondboot failure.

Current upstream requires `CONFIG_ARCH_QCOM_RESERVE_SMEM` on MSM8x60 and
reserves the first 2 MiB *of System RAM*. With that option selected, current
ARM `TEXT_OFFSET` is `0x00208000`. Historical MSM8x60 board code instead sets
the shared-RAM physical base to `0x40000000`; the physical legacy p3 also loads
its zImage at `0x40208000`. The legacy `/proc/iomem` System-RAM resource view
begins at `0x40200000`, but it explicitly is not a complete physical-RAM
census.

The second DTS made `0x40200000` the beginning of System RAM, so upstream
reserved `0x40200000-0x403fffff` and generated a text/load candidate of
`0x40408000`. This is a **probable double application of the 2 MiB SMEM
offset**. It is not directly proven by a secondboot kernel log: the only
captured TWRP `last_kmsg` belongs to a later legacy boot; see
[secondboot post-mortem](../research/device/current/boot/secondboot-postmortem.md).

The next proposed technical change is deliberately one change: model the
physical RAM base at `0x40000000` (without claiming all later holes), let the
upstream SMEM reservation consume `0x40000000-0x401fffff`, and revalidate a
new kernel text/load candidate of `0x40208000`. No third artifact or device
write is authorized by this analysis.

## Historical second-artifact ranges (superseded)

These are retained so the actual second artifact can be audited. They are no
longer a safe target-memory layout. The local checker derived the kernel end
from the then-current `vmlinux` and decompressor symbols from the compressed
`vmlinux`; it deliberately refused any load address other than `0x40408000`.

| Object | Range | Size |
| --- | --- | ---: |
| Qualcomm SMEM reserve | `0x40200000-0x403fffff` | 2,097,152 |
| zImage input | `0x40408000-0x40e3e4e7` | 10,708,200 |
| appended Hikari DTB | `0x40e3e4e8-0x40e403f5` | 7,950 |
| final decompressed kernel | `0x40408000-0x41f23c83` | 28,425,348 |
| relocated decompressor, appended DTB and 128 KiB margin | `0x41f24600-0x4297c935` | 10,847,030 |
| native initramfs | `0x42a00000-0x42b0c33b` | 1,098,556 |
| private RPM payload (outside System RAM) | `0x00020000-0x0003d3e7` | 119,784 |

The compressed input deliberately overlaps the final decompressed-kernel
range.  This is handled by the pinned upstream ARM
`arch/arm/boot/compressed/head.S`: if output would overwrite executing input,
it backwards-relocates the `restart..r6` interval; `r6` includes appended DTB
bytes.  The gate measures its relocation-code reserve (2,304 bytes) and adds
128 KiB margin, then rejects any overlap with SMEM or initramfs.  The old
`0x42800000` initramfs candidate intersected this relocated range; `0x42a00000`
does not.  No arbitrary ramoops region is reserved.

The decompressor relocation analysis remains valid only within this superseded
address model. S1Boot accepted and flashed this ELF, but no target-Linux proof
of life was observed. The required next build gate must validate the corrected
`0x40000000` physical-base model before it considers compressed input,
decompressor relocation, final kernel, DTB, initramfs, SMEM and RPM ranges.
