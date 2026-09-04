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
a more precise pre-`/init` failure boundary. Its persistent log recorded
checked-disable warnings for `dsi_m_ahb_clk` and `amp_ahb_clk`; initramfs and
USB-userspace markers were not observed. The clock driver's individual halt
poll is bounded to roughly 200 microseconds. Stack-trace output accounts for
most of the wall-clock gap, so this evidence does not prove an infinite loop
inside clock disable. It does prove that the DSI boot state was not fully
quiesced before gating. This is not evidence of a panel electrical failure.

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

## MSM8x60 DSI link-clock correction

The next physical log proved that the AHB halt-bit correction worked far
enough to reach link-clock setup, but exposed an APQ8064-derived topology that
does not exist on the Fuji clock controller:

```text
failed to reparent dsi1_byte_clk to dsi1pllbyte: -22
failed to reparent dsi1_pixel_clk to dsi1pll: -22
failed to reparent dsi1_esc_clk to dsi1pllbyte: -22
```

The exact Sony `clock-8x60.c` model instead has a direct DSI byte branch at
`MISC_CC[2]`, a fixed PXO/2 escape clock at `MISC_CC[0]`, and the shared MDP
pixel RCG at `PIXEL_CC/MD/NS`. The DRM/MSM MSM8x60 host variant now requests
only those direct `byte`, `pixel`, and `core` inputs: it does not request an
APQ8064-style `src` clock and does not attempt to program the fixed escape
rate. The MMCC implementation supplies the exact direct branches and the
69.672960 MHz `567/3125` PLL8 pixel rate.

The project-owned canonical DTS and its copied kernel-tree DTS are now kept
identical. The display gate rejects `assigned-clocks` or
`assigned-clock-parents` on the MSM8x60 DSI node, preventing the build system
from silently restoring the invalid topology. Kernel commits `a9c320a7dbec`
and `73e268175648` contain the link-clock and optional-MDP-rail corrections.
These changes are locally validated only; visible display remains
`NOT_VERIFIED` pending an owner-approved physical test.

## MSM8x60 DSI controller quiesce

The g27 physical post-mortem advanced through MSM8x60 DSI V2 selection and
MDP4 component binding. `msm_dsi_runtime_suspend()` then reported all three
DSI AHB branches still on. The bounded polls returned after warning, but no
initramfs marker or stable ACM terminal followed before the persistent ring
became corrupt/truncated. The exact later failure instruction therefore
remains unknown. Their MMCC halt-bit mapping already agrees with exact Sony
source; clearing `CLK_CTRL` alone did not release the branches.

Exact Sony MSM8x60 `mipi_dsi.c` clears DSI `CLK_CTRL` (`+0x118`) and `CTRL`,
stops the 45 nm PLL, and disables DSI master, DSI slave, then AMP AHB. The
first local reproduction placed that reset in `msm_dsi_runtime_suspend()`.
That callback is normal lifecycle machinery rather than a one-time firmware
handoff, so it could reset the controller repeatedly during component probe,
panel transactions, or later power-management transitions. The following
physical attempt again ended around checked disables of the slave, master and
AMP AHB branches before `/init`; moving more shutdown operations into the
same callback did not make that lifecycle safe.

Signed kernel commit `3c1ddf679af0` therefore makes the operation explicitly
one-shot. After host and PHY discovery, and before DSI manager registration,
it takes a tracked bulk clock reference, clears `CLK_CTRL` and `CTRL`, stops
the 45 nm PLL, flushes the posted MMIO writes, and records the retained-clock
state. Runtime suspend and resume then leave those AHB references untouched.
The destroy/error-unwind path releases them exactly once. A project build gate
requires the one-shot call, retained suspend/resume behavior and matching
teardown, and forbids controller/PHY reset operations in runtime suspend.

This containment is intentionally conservative: the display AHB clocks stay
on for the life of the driver, increasing bring-up power consumption. It
removes the evidenced pre-init failure path without pretending that final
runtime PM is solved. The locally validated g29 artifact is recorded in
[BUILD.md](BUILD.md); physical panel, fbcon and charging acceptance remain
open.

## g29 post-mortem: missing MDP power domain

The g29 physical attempt proved that the one-shot DSI quiesce completed and
retained its AHB clocks. It advanced through MSM8x60 DSI V2 selection and
MDP4/DSI component binding, then the synchronous kernel-init thread stopped
progressing. Charger workqueue messages continued for 72 seconds, so this was
not a whole-kernel panic. There was no `MDP4 version`, initramfs release,
`/init`, or Hikari userspace marker.

The deployed MDP4 node lacked a power domain. Exact Sony MSM8x60 source puts
`mdp.0` behind `FS_MDP` and maps its clocks to `footswitch-8x60.4`; the current
MMCC driver exposes the same island as `MDP_GDSC` ID 4. The corrected Hikari
node uses `power-domains = <&mmcc MDP_GDSC>`, so the platform core powers the
island before `mdp4_kms_init()` performs its first revision-register read.
The binding and final-DTB gate enforce this relationship.

The bring-up cmdline also uses asynchronous `mdp4,msm_dsi` probing. This is a
diagnostic fail-open measure: another display-side MMIO stall will no longer
prevent later USB initcalls from registering the ttyGS0 kernel console. The
full sanitized diagnosis is in
[g29-display-mdp-power-stall.md](../research/device/current/boot/g29-display-mdp-power-stall.md).
