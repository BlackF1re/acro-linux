# Hikari BOOT #6 display artifact

Status: `IMPLEMENTING`, built locally only.  No display component described
here has been tested on the physical device.  BOOT #5.1 USB CDC ACM, PID 1,
and ramoops remain the diagnostic and recovery foundation.

## Source and patch provenance

The kernel base is Linus commit `786262be6048deab760f68c8acc2c85607165894`
(7.3-rc1).  The external kernel branch retains the following author-preserved
mailing-list commits by Herman van Hazendonk:

- MSM8x60 legacy GDSC v2: `e771804a5` and `d0b41b36b`, from
  `20260606-submit-clk-gdsc-msm8x60-legacy-v2`;
- MSM8x60 MMCC v1: `99781428e`, `a659291f3`, and `c8f45edda`;
- MSM8x60 NoC v4: `e61fd6a49` and `96cfe69be`.

No newer public MMCC revision was available when this artifact was prepared.
A separate project-owned adjustment makes MMCC fabric unhalt return
`-EPROBE_DEFER` until RPM is ready, rather than reporting false success.  It
does not claim to be an upstream v2.  The NoC work is v4; its present upstream
implementation retains its own fabric-clock policy and that policy has not
been changed locally.

The board facts come from the exact Fuji/Hikari downstream files
`board-semc_fuji.c`, `devices-msm8x60.c`,
`mipi_tmd_video_wxga_mdv22.c`, `msm_dss_io_8x60.c`, and
`leds-fuji_hikari.c` in `android_kernel_sony_msm8660`.  They are provenance,
not a reused Android framebuffer architecture.

## Implemented BOOT #6 graph

The final Hikari DTB describes:

```text
MMCC + legacy GDSC + MSM8x60 NoC/MMFAB
  -> MDP4 @ 0x05100000 (SPI 75)
  -> existing DRM/MSM DSI v2 host @ 0x04700000 (SPI 82)
  -> new MSM8x60 45 nm PHY @ 0x04700000
  -> R63306/TMD MDV22 panel
  -> DRM fbdev emulation -> fbcon

GSBI8/QUP I2C @ 0x19880000 -> AS3676 @ 0x40 -> LCD backlight
```

Current DRM/MSM's v2 host is reused through a minimal MSM8660 configuration;
no downstream `msm_fb` stack is included.  The 45 nm PHY is an honest,
fixed-rate Hikari bootstrap implementation: it uses the exact downstream
analog/PLL tables for approximately 418.038 Mb/s per lane, not 28 nm values
or a falsely general rate calculator.

The panel driver is a modern `drm_panel`/`mipi_dsi_device` implementation.
Its profile is the exact MDV22 ID00 source sequence: 720x1280 portrait,
RGB888, four lanes, non-burst sync-event video, VC0, H `45/128/3`, V `3/9/4`,
and a 69.672960 MHz pixel clock.  It uses PM8901 L2 at 2.85 V as VCI, PM8901
LVS1 as VDDIO, GPIO18 as panel power-enable, and GPIO70 as reset.  The
AS3676 driver is a small backlight-class implementation on GSBI8 address
`0x40`; it targets sinks 01, 02, and 06 and selects a conservative default
brightness rather than the downstream maximum.

## Static acceptance

The BOOT #6 fragment builds DRM/MSM, MDP4, DSI, the 45 nm PHY, the panel,
AS3676 backlight, fbdev emulation, fbcon, MMCC, NoC, and all previously
verified USB gadget and ramoops support into the kernel.  The final DTB has
reciprocal MDP4--DSI--panel endpoints, resolved supply/clock/reset references,
and the observed ramoops region.  Host-side gates validate display, USB,
ramoops, appended DTB, Sony ELF and ARM decompressor self-relocation layout.
`make dtbs` passes.  The installed `dtschema` 2026.6 makes the kernel's
bulk `make dtbs_check` invocation pass multiple DTB positional arguments after
an option and prints an argument-parsing error for every DTB (while `make`
still returns zero); it is therefore not counted as a schema pass.  Direct
`dt-doc-validate` of each new binding and targeted `dt-validate` of the final
Hikari DTB both pass with that same toolchain.

## Physical test and risks

The next physical test must keep the existing USB ACM shell alive even when
display probing defers or fails.  Expected useful dmesg order is MMCC/NoC,
MDP4, DSI v2, 45 nm PHY, panel attach/prepare/enable, AS3676, DRM connector,
fbdev and fbcon.  USB remains the primary diagnostic transport and ramoops
the pre-USB fallback.

Important unverified risks are intentionally not hidden: MDP4's exact MSM8x60
IOMMU requirements have not received a physical test; legacy BGR swap and
precise generic-vs-DCS packet semantics need runtime confirmation; the
fixed-rate PHY, panel power sequence and AS3676 writes are source-derived but
not yet electrically verified.  A driver compiling or probing is not a
display acceptance result.

The physical success criterion is a lit internal panel with native fbcon.
The minimum useful result is a live USB shell showing MDP4/DSI/DRM connector
and modeset diagnostics without destabilizing USB.

## Offline correction after the first display attempt

The first display-enabled artifacts did not produce a visible panel and the
later attempt did not retain a usable USB shell long enough to locate the
failure at runtime.  This is not evidence that the panel, DRM, or USB path
cannot work; it is a failure to be diagnosed with a newly built artifact.

An offline comparison of the actual DRM/MSM DSI v2 clock requests with the
exact Fuji MDV22 clock chain found three concrete implementation errors in the
then-current bootstrap code:

- DSI source and pixel clocks were parented to the PHY byte output, while byte
  and escape clocks were parented to the DSI output.  MSM8x60 requires the
  inverse relationship: DSI source/pixel use the 209.018880 MHz DSI PLL and
  byte/escape use the 52.254720 MHz byte PLL.
- The PHY advertised 69.672960 MHz as its DSI PLL output.  That is the panel
  pixel rate, not the source rate requested by the v2 host.  The historical
  chain is 836 MHz VCO / 4 = 209.018880 MHz, then / 3 for pixels and / 16 for
  the byte clock.
- The fixed-rate 45 nm PHY initialized the analog/PLL tables but did not
  program the source, byte, and DSI divider registers used by the Fuji PHY
  configuration before enabling the PLL.

The source now programs those dividers, uses the correct output parents, and
keeps the source-derived 418.037760 Mb/s per-lane target.  The clean corrected
artifact is `hikari-artifacts-g14-dsi-clockfix/hikari-boot6-dsi-clockfix-v2.elf`
(`0ab1e7b974e221679b677925394c180470a6c82252a81d07b0459b66c4bd8c9e`,
12,502,307 bytes).  Previously built display ELF files are not silently
relabelled as containing this corrected DTB.  Physical display status remains
`NOT_VERIFIED` until a charged device is tested.
