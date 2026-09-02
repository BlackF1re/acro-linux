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

The corrective third local build models the physical RAM base at
`0x40000000` (without claiming all later holes), lets the upstream SMEM
reservation consume `0x40000000-0x401fffff`, and revalidates a kernel
text/load candidate of `0x40208000`. This is supported by the current
upstream Kconfig/Makefile semantics, historical MSM8x60 board code and the
legacy p3 load address. It remains a target-layout hypothesis until a physical
boot produces evidence. Local artifact creation is not authorization to write
the phone.

## Physical recovery correction (2026-09-02)

TWRP now adds direct physical-device evidence to the model. Its
`/proc/iomem` shows Linux-visible System RAM at
`0x40200000-0x42dfffff` and `0x48000000-0x6e5fffff`; its own kernel code starts
at `0x40208000`. It separately records the persistent console at
`0x7ffe0000-0x7fffffff`. This is a Linux resource view, not a complete DRAM
map: it confirms the post-reservation low address, but does not expose the
SMEM bytes as System RAM.

The convergent evidence chain is: historical MSM8x60/Fuji code places shared
RAM at physical `0x40000000`; current upstream
`CONFIG_ARCH_QCOM_RESERVE_SMEM` reserves its first 2 MiB and selects
`TEXT_OFFSET=0x00208000`; the legacy p3 and physical TWRP kernel both use
`0x40208000`; and a historical Hikari mainline trace reaches `/init` with
ramoops at `0x7ffe0000`.

| Item | Range / value | Evidence and confidence |
| --- | --- | --- |
| Physical low DRAM bank base | `0x40000000` | `HISTORICAL_SOURCE` plus upstream reservation semantics; consistent with device runtime |
| Qualcomm SMEM | `0x40000000-0x401fffff` | `VERIFIED_UPSTREAM` semantics, Hikari application remains target layout pending boot |
| First Linux-visible low address | `0x40200000` | `VERIFIED_DEVICE` TWRP `/proc/iomem` |
| Kernel text / Sony zImage candidate | `0x40208000` | `VERIFIED_DEVICE` for legacy/TWRP; strongest target starting point |
| Low visible System RAM | `0x40200000-0x42dfffff` | `VERIFIED_DEVICE` TWRP `/proc/iomem` |
| High visible System RAM | `0x48000000-0x6e5fffff` | `VERIFIED_DEVICE` TWRP `/proc/iomem` |
| Persistent console | `0x7ffe0000-0x7fffffff` | `VERIFIED_DEVICE` TWRP `/proc/iomem` |

The `0x40408000` address used in boot #2 applied the two-MiB adjustment to a
memory node that already began at the legacy post-SMEM address. It is now a
strongly supported **double-offset error**, though the lack of a target log
means it cannot be named the sole cause of that failed observation. Boot #4
returns the zImage address to `0x40208000`; it moves neither the SMEM reserve
nor the kernel arbitrarily. The initramfs remains high enough to avoid the
code-derived decompressor relocation interval.

## Boot #4 local artifact validation

The corrected local artifact was built without contacting the phone.  Its
memory gate reads the actual current `vmlinux` end and ARM compressed-kernel
symbols, rather than estimating the final kernel extent from a source setting.

The resulting local-only artifact is
`/home/paul/xperia/build/hikari-artifacts-g6/hikari-boot4-debug.elf` (11,955,195
bytes, SHA-256
`ba83fda682df3c49e5ec81ee6d354f1cc5a7e575ac94a065ef011c602319ed7c`).
It is not in Git and this record is not authority to deploy it.

| Object | Range | Size |
| --- | --- | ---: |
| Qualcomm SMEM reserve | `0x40000000-0x401fffff` | 2,097,152 |
| zImage input | `0x40208000-0x40c424d7` | 10,724,568 |
| appended Hikari DTB | `0x40c424d8-0x40c444a3` | 8,140 |
| final decompressed kernel | `0x40208000-0x41d23d03` | 28,425,476 |
| relocated decompressor, appended DTB and 128 KiB margin | `0x41d24700-0x42780ae3` | 10,863,588 |
| native initramfs | `0x42a00000-0x42b0c36e` | 1,098,607 |
| private RPM payload (outside System RAM) | `0x00020000-0x0003d3e7` | 119,784 |
| persistent console (outside System RAM) | `0x7ffe0000-0x7fffffff` | 131,072 |

The native initramfs begins after the relocation interval.  The compressed
input overlaps its ultimate decompressed-kernel range, which the current ARM
`head.S` explicitly handles by backwards self-relocating the
`restart..r6` interval; `r6` includes the appended DTB.  The checker accounts
for this path, its 2,304-byte relocation-code reserve, and an additional
128 KiB margin.

`BOOT4_MEMORY_SAFETY=PASS` means the listed local artifact satisfies this
code-derived overlap model.  It does not prove that S1Boot will execute it or
that target Linux will boot on the handset.

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
of life was observed. Boot #4's gate validates the corrected `0x40000000`
physical-base model before it considers compressed input, decompressor
relocation, final kernel, DTB, initramfs, SMEM, RPM and the distinct
`0x7ffe0000` persistent-console range. It does not mechanically copy legacy
multimedia carveouts into the target DT.
