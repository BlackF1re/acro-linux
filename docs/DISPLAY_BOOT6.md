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
  -> new MSM8x60 45 nm PHY @ 0x047000f0 / PLL @ 0x04700200
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
charging, ramoops, appended DTB, Sony ELF and ARM decompressor self-relocation
layout. `make dtbs` passes. Targeted `make CHECK_DTBS=y
qcom/qcom-msm8260-sony-hikari.dtb` now also passes without warnings, as do
direct `dt-doc-validate` of each new binding and targeted `dt-validate` of the
final Hikari DTB.

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

## BOOT #7 component-graph correction

BOOT #7's TWRP-exported persistent log narrowed a pre-`/init` crash to
`component_master_add_with_match()` from `msm_drv_probe()` during deferred
DRM/MSM probing.  This was a concrete DT graph error, not a panel electrical
result: the Hikari DSI endpoint used MDP4 port 0, which current DRM/MSM skips
as the LCDC/LVDS output while building component matches.  DSI1 belongs on
MDP4 port 1.  The next local artifact uses that port and its static gate both
requires port 1 and rejects a DSI endpoint on port 0.  The USB and persistent
logging foundations are unchanged.

The same correction pass removed several API mismatches which could otherwise
defer or mis-map the display chain: the DSI controller now has the generic
fallback compatible and `dsi_ctrl` register name expected by current DRM/MSM,
uses `phy-names = "dsi"` and `syscon-sfpb`, and gives the 45 nm PHY and PLL
their exact non-overlapping subranges. A real MSM8660 MMSS SFPB binding was
added instead of leaving that syscon unconstrained. The panel now participates
in the normal DRM backlight lifecycle, and its display-on/off commands occur in
panel enable/disable rather than prepare/unprepare.

The optional MDP4 `vdd` dummy-supply diagnostic seen immediately beforehand is
not the crash cause: current MDP4 code explicitly continues when its optional
exclusive `vdd` lookup is unavailable.  Physical display status remains
`IMPLEMENTING` until a later owner-approved boot demonstrates a connector or
visible fbcon.

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
keeps the source-derived 418.037760 Mb/s per-lane target. The latest canonical
artifact and hashes are recorded in [BUILD.md](BUILD.md); historical display
ELFs remain immutable experiment records. Physical display status remains
`NOT_VERIFIED` until an owner-approved device test.

## Live DSI host diagnosis

The subsequent physically observed kernel kept the verified USB shell but did
not register a DRM card. AS3676 did probe and export its backlight class. The
terminal DSI error was `dsi_get_config: Invalid version`; a read-only hardware
check returned zero from the generic DSI version register at `0x047001f0`.
MSM8x60 therefore cannot use the later generic V2 identification path.

The locally built successor selects the existing V2 configuration from the
explicit `qcom,msm8660-dsi-ctrl` compatible. It does not change the verified
USB path or the source-derived panel electrical data. Targeted DT schema,
display static, memory, persistent-RAM and Sony ELF gates pass. The correction
is `IMPLEMENTING`, not `VERIFIED`, until it registers DRM on the handset.

## Runtime-suspend clock hang and panel payload correction

The following physical run advanced beyond DSI variant selection and supplied
a more precise pre-`/init` failure boundary. Its persistent log stopped in
`msm_dsi_runtime_suspend()` while the clock framework waited forever for
`dsi_m_ahb_clk` to report off; a later trace similarly named `amp_ahb_clk`.
Consequently CPU0 never reached the initramfs, which also explains the missing
or unreliable USB userspace diagnostics in that run. This is not evidence of
a panel electrical failure.

Exact Sony/OpenSEMC MSM8x60 clock data assigns MMSS halt bits 18, 19 and 20 to
AMP AHB, DSI master AHB and DSI slave AHB respectively. The project bootstrap
had assigned bit 21 to the slave clock and made it critical. Kernel commit
`200115087c00` corrects the slave halt bit to 20 and returns all three branches
to normal DSI runtime-PM ownership.

An independent table audit against the exact Hikari ID00/ID01 MDV22 source
found several project command entries whose declared payload count omitted the
last byte. Kernel commit `6b09d9bff5cf` corrects C0 and C8--CE counts so the
modern DRM panel driver transmits every source-derived byte. A build gate now
checks the halt-bit rule and every command-table count before packaging.

The resulting artifact is locally valid and retains the physically verified
USB ACM and ramoops paths. Visible native-resolution scanout, panel enable and
backlight remain `NOT_VERIFIED` until the artifact is tested on the phone.
