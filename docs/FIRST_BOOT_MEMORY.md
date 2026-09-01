# Hikari second-boot memory gate

`SECOND_BOOT_MEMORY_SAFETY=PASS` is a host-side gate for the locally built
second artifact.  It is not proof that S1Boot will execute that artifact.

The first attempt is obsolete: it omitted the upstream-required
`CONFIG_ARCH_QCOM_RESERVE_SMEM`, so its decompressed-kernel base was
`0x40208000` inside the required MSM8x60 2 MiB SMEM reservation.  The new
configuration sets `CONFIG_ARCH_QCOM_RESERVE_SMEM=y`, disables
`ARCH_MULTIPLATFORM` and `AUTO_ZRELADDR`, and uses `PHYS_OFFSET=0x40200000`.
Pinned upstream `arch/arm/Makefile` consequently uses `TEXT_OFFSET=0x00208000`.

## Validated second-artifact ranges

The physical legacy evidence gives first System RAM as
`0x40200000-0x42dfffff`.  The local checker derives the kernel end from the
current `vmlinux` and decompressor symbols from the current compressed
`vmlinux`; it refuses a load address other than `0x40408000`.

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

These addresses are host-validated, evidence-backed candidates.  S1Boot
acceptance of the changed kernel load address remains a physical second-boot
question.
