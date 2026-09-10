# Hikari physical scanout acceptance (2026-09-10)

Evidence state: `VERIFIED_DEVICE`.

The known-working Sony/TWRP kernel was built without `CONFIG_MSM_IOMMU`.
Mainline attempts that attached MDP4 to the legacy MSM IOMMUs programmed a
small display IOVA (`0x00005000`), while readback from both physical context
banks remained zero. The MDP therefore fetched from the wrong physical
address and reported `PRIMARY_INTF_UNDERRUN` for every frame, producing a
solid blue panel.

Patch 0065 detaches the Hikari MDP node from those IOMMUs and gives scanout GEM
objects physically contiguous CMA backing. Its first physical run proved the
new address (`0x7bd00000` inside the reserved `0x7bc00000` CMA area), then
faulted in `msm_gem_vma_put()` because the generic cleanup path still
unconditionally dereferenced the deliberately absent KMS VM. The retained
ramoops record identifies `msm_gem_vma_put+0x94` and a null address plus
`0x94`. The final patch makes this VMA cleanup a no-op when no VM exists.

The corrected 0066 Sony ELF has SHA-256
`561917ad4a123b0aa9a65c2d8b00111a5171c480e9b06d5b0395940c1e67f321`.
It was flashed only to S1 `boot` partID `0x00000003`. The owner explicitly
confirmed a readable terminal and repeating `HIKARI DISPLAY ALIVE` output.
Live target evidence then showed:

- Linux `7.3.0-rc1-gbf494ebad392-dirty` remained alive with an interactive
  USB serial shell;
- DRM/MSM selected contiguous physical scanout without an IOMMU and logged
  `fbdev scanout address 7bd00000`;
- DSI-1 was connected, CRTC 0 was active, and the native mode was
  `720x1280` at 60 Hz;
- plane 2 scanned the `XR24` fbcon framebuffer, 720x1280 with pitch 2944;
- `/proc/interrupts` showed the active MDP interrupt (`msm`, GIC 107) advancing
  to 51,927 by 867 seconds and DSI IRQ 114 at 38;
- no `PRIMARY_INTF_UNDERRUN`, MDP error IRQ, Oops, BUG, or unhandled fault was
  present in the complete live `dmesg`;
- writing `HIKARI_DISPLAY_ACCEPTANCE_0066` to `/dev/tty0` exercised fbcon.

A later stability read at 867.38 seconds again found no underrun, MDP error
IRQ, Oops, BUG, unhandled fault, or hung-task report.

The private captures are retained outside version control under
`research/private/hikari-live-debug/20260910-direct-scanout-0066/`. The main
serial capture has SHA-256
`76a4c6f18ca89af89441d4cb16ffb7af421baddd1429eccc7e3ee36f7cb7c113`;
the later stability capture has SHA-256
`8bd5702a233855d7ea5244bbfb172077c11c8db09d8652709842c88b6a59856b`.

This completes the physical native-display and fbcon acceptance test, so those
paths are `VERIFIED` with `VERIFIED_DEVICE` evidence. Display suspend/resume,
brightness policy, and accelerated GPU are separate acceptance domains.

One non-fatal fbdev warning remains: MSM's fbdev setup maps the GEM object into
virtual memory but does not set `FBINFO_VIRTFB`, so generic sysmem draw helpers
warn once. Pixel output works; this bookkeeping issue should be corrected and
retested separately rather than conflated with the solved scanout-address
failure.
