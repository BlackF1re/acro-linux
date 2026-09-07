# Hikari display: DSI core clock was parented to PXO

Status: sanitized `VERIFIED_DEVICE` diagnosis. The parent correction was
physically deployed, but it exposed an earlier CCF enable failure. Visible
scanout still needs a successor physical acceptance test.

## Failure boundary on the live system

The running mainline system remained usable through USB while DRM reported a
connected DSI-1 connector, active 720x1280 CRTC, XR24 framebuffer and fbcon.
The framebuffer was neither absent nor permanently blank: read-only hashes of
`/dev/fb0` changed.  MDP4 can scan out this dumb GEM framebuffer without the
Adreno GPU, so missing GPU support is not the cause of the absent pixels.

The decisive live observations were:

```text
dsi1_src clock rate:       27000000 Hz
DSI1 PLL output:          209018880 Hz
MMCC DSI_NS @ 0x0054:     0x00000000
MDP/DSI vblank progress:  none
```

The MDP pixel clock and framebuffer programming were present, but the DSI
video engine never began producing the first frame.  Source value zero in
`DSI_NS` selects PXO.  This places the failure after DRM framebuffer setup but
before a running DSI video timing stream.

## Exact cause

The MSM8x60 MMCC bootstrap described `dsi1_src` with an empty frequency table
and `clk_rcg_bypass_ops`.  `clk_rcg_bypass_determine_rate()` takes the source
enum from that table entry; the empty entry is zero, so every core-clock rate
request retained parent zero (27 MHz PXO).  Enabling the DSI PLL and its byte
output could not correct the independently mis-parented DSI core mux.

Sony's exact MSM8x60 display clock code instead sets `dsicore_clk.src = 3`
and writes that source into MMCC `DSI_NS`.  In the current parent map, source
3 is the DSI1 PHY pixel/core PLL output.  APQ8064's newer clock model likewise
uses parent-aware bypass operations and an explicit assigned PHY parent.

The correction is deliberately narrow:

- `dsi1_src` uses `clk_rcg_bypass2_ops` and no empty frequency table;
- the Hikari DSI node assigns only `DSI_SRC` to
  `DSI_PIXEL_PLL_CLK` from its own PHY;
- a final-DTB gate verifies both resolved phandles and IDs;
- a source gate rejects the old empty-table implementation.

This does not change the physically verified USB path, RAM/SMEM layout,
ramoops, RPM, panel command table, backlight or framebuffer allocation.

## Physical successor result and next boundary

The parent-corrected artifact retained the USB root shell, completed MMCC,
IOMMU, MDP4 and 45 nm PHY initialization, and selected the required
209.018880 MHz DSI core source. It then stopped in the next exact operation:

```text
dsi1_clk status stuck at 'off'
msm_dsi_host_power_on: failed to enable link clocks. ret=-16
```

`dsi_link_clk_enable_msm8x60()` enables byte, escape, core (`src_clk`) and
pixel clocks in that order. The failure is the core `dsi1_clk` branch at MMCC
`0x004c` bit 0. Its nominal halt readback is `0x01d0` bit 2; physical Hikari
keeps that bit in the off state after the gate is asserted, so CCF reports a
false `-EBUSY`. Sony's exact MSM8x60 driver enables this same gate without a
halt-status poll. The successor correction retains the gate write but models
the readback as `BRANCH_HALT_SKIP`, the established CCF treatment for other
MSM8x60 branches with unreliable status.

This supersedes the claim that parent selection alone is the first-vblank
blocker. Adreno and framebuffer contents remain ruled out: this failure occurs
before DSI host video power-on and before any scanout can begin.

## Command-DMA boundary after the clock fix

The halt-poll and panel-order corrections were then physically tested. The
host and PHY powered on, but the first panel command (`0xb0`) timed out:

```text
dsi_cmds2buf_tx: cmd dma tx failed, type=0x23, data0=0xb0, len=4, ret=-110
DSI DMA address: 0x7bc41000
DSI trigger:     still asserted
DSI IRQ 114:     zero completions
```

`0x7bc41000` is outside Hikari's physical RAM banks. It is an IOVA from the
MDP IOMMU because the V2 host allocated its command buffer against the DRM/MDP
device. The DSI command engine is a separate bus master and cannot consume
that MDP-domain address. Sony's downstream implementation allocates/maps the
command buffer against the DSI device and programs a physical DMA address.

The successor fix uses the DSI platform device for the V2
`dma_alloc_coherent()` and matching free operation. Clocks, panel sequence,
USB, ramoops and framebuffer allocation are unchanged. It is built and
statically validated, but not yet physically accepted.
