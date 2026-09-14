# Retired Hikari DSI experiments

These patches are retained as negative bring-up evidence and are **not** part
of `kernel/patches/series`.

The 2026-09-15 Debian microSD boot using ELF SHA-256
`fab8742c1ee5d25e2da6f360060dd5065f7db57afc26b407e6ebbdd88f64e3c7`
proved that the combined changes regress the physical MDV22 panel. DRM, the
720x1280 connector, fb0 and the AS3676 backlight all registered, but the first
12-byte panel transfer timed out twice, including after an explicit
blank/unblank retry:

```text
command DMA timeout: base=0x488d3000 len=12 ... status=0x3 ...
dsi_cmds2buf_tx: cmd dma tx failed, type=0x29, data0=0xbe, len=12, ret=-110
```

The owner observed a completely black panel. In contrast, the physically
accepted 0066, 0068 and 0073 kernels use a coherent V2 command buffer allocated
from the DSI device and log `MDV22 command sequence complete before video
scanout` before presenting readable fbcon output. Production therefore remains
on that accepted command-DMA path. Any individual idea from these patches must
be separated and physically tested before reconsideration.
