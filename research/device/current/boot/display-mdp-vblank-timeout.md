# Hikari DSI-video vblank timeout

Status: sanitized `VERIFIED_DEVICE` post-mortem evidence.  The fault is
corrected in source, but visible scanout and fbcon still require a physical
acceptance test.

## Capture

TWRP recovered two fragments from the previous mainline persistent ring.  Raw
copies remain private.  The useful fragment is 75,090 bytes with SHA-256
`f5d2d9a009296f49a9cbe5f19f286099b376b49c129bb89e625adad9ed265574`.
It identifies kernel commit `96651e282822a6b587b43dc3c4767a1f27581933`, shows
both MDP IOMMU context providers attach successfully, and contains no kernel
panic, Oops or BUG through at least 895 seconds.

After fbdev setup, the DRM damage worker repeatedly reports:

```text
mdp4 5100000.display-controller: [drm] vblank wait timed out on crtc 0
```

The timeout recurs at roughly 1.2-second intervals.  This proves that the
commit path progressed far enough to service fbdev damage, but DRM never
observed the scanout vblank it was waiting for.  It does not by itself prove
panel illumination or pixel transfer.

## Source comparison and cause

The current MDP4 CRTC used the DMA completion bit returned by `dma2irq(dma)`
for both atomic commit completion and DRM vblank accounting.  Exact Sony
MSM8x60 source distinguishes those events for DSI video mode:

- `INTR_DMA_P_DONE` (bit 4) completes the primary DMA commit;
- `INTR_PRIMARY_VSYNC` (bit 7) is the DSI-video frame/vsync event.

Consequently a completed register update could wake the commit wait while
the subsequent DRM vblank wait remained tied to the wrong interrupt source.

## Correction

Kernel commit `efae8bd73882339f2f6a8a394479d6c0eeeeedfa` gives MDP4
separate interrupt state for commit completion and scanout vblank.  DSI video
selects `MDP4_IRQ_PRIMARY_VSYNC`; other interfaces retain the existing DMA
interrupt fallback.  The display source and kernel-source build gates reject
a return to the coupled model.

This correction is narrowly scoped.  It does not explain the absent USB
console bytes in this capture and does not claim that DSI PHY, panel commands,
backlight, or fbcon are physically verified.
