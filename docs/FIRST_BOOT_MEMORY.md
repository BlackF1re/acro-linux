# First Hikari native-boot memory gate

`FIRST_BOOT_MEMORY_SAFETY=PASS` applies only to the exact local artifact
recorded below.  It is a host-side range proof, not evidence of a successful
device boot.

## Inputs and decompressor rule

Legacy-device evidence names the first System RAM bank as
`0x40200000-0x42dfffff`.  The prototype uses the physically observed Sony ELF
kernel address `0x40208000`, which is `0x8000` from that bank's beginning.

The selected current ARM configuration deliberately has:

```text
CONFIG_ARCH_MULTIPLATFORM=n
CONFIG_AUTO_ZRELADDR=n
CONFIG_PHYS_OFFSET=0x40200000
CONFIG_PAGE_OFFSET=0xc0000000
```

This is necessary: with the normal multiplatform `AUTO_ZRELADDR` algorithm,
`head.S` masks a zImage PC with `0xf8000000`; `0x40208000` would incorrectly
produce `0x40008000`, outside the observed first RAM bank.  The explicit
configuration instead gives `zreladdr = PHYS_OFFSET + TEXT_OFFSET`, or
`0x40208000`.

The current upstream decompressor's `head.S` contains its own input-overlap
relocation handling.  Its documented appended-DTB allowance is conservatively
modelled here as a full 1 MiB clear workspace after the decompressed kernel.
No target ramoops region is reserved, and no legacy carveout was copied.

## Exact G artifact ranges

| Object | Physical range | Size | Basis |
| --- | --- | ---: | --- |
| compressed zImage | `0x40208000-0x40c3e16f` | 10,707,312 | exact built input |
| appended DTB | `0x40c3e170-0x40c4007d` | 7,950 | exact built DTB |
| decompressed kernel | `0x40208000-0x41b23c83` | 26,328,196 | `vmlinux` `_end` minus `PAGE_OFFSET` |
| conservative decompressor/DTB workspace | `0x41b23c84-0x41c23c83` | 1,048,576 | upstream decompressor rule |
| native initramfs | `0x42400000-0x4250c2de` | 1,098,463 | exact built input |
| RPM payload | `0x00020000-0x0003d3e7` | 119,784 | private legacy p3 segment; outside System RAM |

The kernel workspace ends before the initramfs begins, with a 9,290,620-byte
gap from the decompressed-kernel end to the initramfs start.  The initramfs
ends before the observed first-bank end (`0x42e00000`).  The RPM interval is
below System RAM and has no ELF load-address overlap.  The host gate derives
these values from the exact `vmlinux`, zImage, DTB, initramfs, and RPM files and
fails the build for an out-of-bank range or overlap.

This does not attribute the remaining nominal RAM, prove firmware ownership,
or prove S1Boot acceptance.  Those are separate physical-boot observations.
