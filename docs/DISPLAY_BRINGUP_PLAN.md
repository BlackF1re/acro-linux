# Hikari display bring-up plan

Status: `RESEARCHING`. This is a bounded plan for the first visible native
console; it authorizes no device write or reboot. A compiled driver or a DT
node is not display verification. The acceptance test is stable visible
1280x720 fbcon output on the physical Hikari panel.

## Working foundation and live baseline

BOOT #5.1 is a stable, interactive mainline diagnostic platform. Live
read-only inventory found no target DRM, backlight, LED, thermal, I2C, MMC, or
SPI class device instantiated yet. This means the current minimal DTS has not
described those devices; it does not negate their physical presence.

The live clock summary has no MDP4/DSI consumer. HSUSB's independently
verified clocks (`usb_hs1_h_clk`, `usb_hs1_xcvr_clk`, `sleep_clk`, and
`cxo_board`) demonstrate that the RPM/clock foundation is active, but do not
provide MMSS clock/reset control. This is the pre-display baseline to compare
against after each future physical test.

## Exact target pipeline

```text
MSM8260 -> MSM8x60 MMCC -> MDP4 -> 45 nm DSI PHY -> DSI host
        -> Renesas R63306 / TMD WXGA panel -> DRM fbdev emulation -> fbcon
                                                   -> panel backlight
```

`VERIFIED_VENDOR_SOURCE` Fuji data identifies the panel path as
`mipi_renesas_r63306` with profile `mipi_video_tmd_wxga_mdv22`: 1280x720,
four DSI lanes, RGB888, video non-burst sync-event mode, hback/hfront/hpulse
`45/128/3`, and vback/vfront/vpulse `3/9/4`. Its board data records LCD
power GPIO18, reset GPIO70, MDP vsync GPIO28, PM8901 L2 at 2.85 V (VCI),
PM8901 LVS1 (VDDIO), and PM8058 L0 DSI power. Those values require conversion
and DT-schema review; they are not yet a target DTS claim. The legacy runtime
also identifies the R63306/TMD path, but no panel command sequence has been
executed by the target kernel.

## Current upstream state

At the pinned Linux
[`786262be6048`](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=786262be6048deab760f68c8acc2c85607165894),
DRM/MSM already supplies the MDP4, DSI, fbdev-emulation, and framebuffer
console framework. The [MDP4 binding](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/Documentation/devicetree/bindings/display/msm/mdp4.yaml?id=786262be6048deab760f68c8acc2c85607165894)
requires the core/iface/bus/lut clock set (and conditionally HDMI/TV/LCDC/PXO
clocks). Those resources cannot be supplied correctly for MSM8x60 without an
MSM8x60 MMCC provider and its corresponding clock/reset IDs.

The tree has no MSM8x60/45 nm DSI PHY implementation. Its closest structural
reference is the MSM8960 28 nm PHY driver, but its analog values must not be
copied to Hikari. The bootstrap source is instead the Fuji downstream PHY and
panel path, cross-checked with historical Hikari mainline work, and converted
to an upstream-style 45 nm PHY driver with each register value sourced.

The tree also has no exact R63306/TMD WXGA panel driver. The R63353 family is
not a substitute. A new small `drm_panel` implementation is therefore needed:
regulators, reset sequencing, the evidenced DCS/vendor initialization sequence,
mode, lane/pixel format configuration, prepare/enable/disable/unprepare, and a
separate backlight consumer. Android framebuffer code is evidence only, never
the target architecture.

## Patch provenance and ordering

Before adding display DT nodes, retrieve and apply the latest authoritative
MSM8x60 MMCC series with preserved author metadata; no such provider is in the
pinned tree. Its clock/reset IDs are the first hard blocker for MDP4 and DSI.

For scanout, retrieve the latest `v4` [MSM8x60 NoC
series](https://patchew.org/linux/cover.1780197411.git.github.com%40herrie.org/diff/20260606-submit-interconnect-msm8660-v4-0-6e1e5c5efa26%40herrie.org/)
by Herman van Hazendonk, or a newer authoritative revision if one exists when
the work begins. It models AFAB, SFAB, MMFAB, and DFAB and has a multimedia
fabric path needed to make MDP bandwidth voting an evidence-backed design.
Unlike BOOT #5 USB, display scanout should not omit this provider merely to
reduce the patch count.

Do not apply a historical panel or PHY patch as project-authored code. Keep
third-party commits author-preserved and document message IDs and revisions.

## Smallest safe implementation sequence

1. Apply and validate MMCC, then NoC v4/newer, with their bindings and a
   minimal MSM8260 common DTS integration. Build `dtbs`, relevant
   `dtbs_check`, and bindings before board work.
2. Add the 45 nm DSI PHY only after its regulators, clocks, reset, and all
   analog values have Hikari/Fuji provenance. Verify probe dependency graph
   statically.
3. Add an upstream-style R63306/TMD panel driver and an isolated Hikari panel
   node. Preserve the exact downstream sequence as sanitized source evidence.
4. Add only the needed MDP4/DSI/panel/backlight DT graph and the relevant
   built-in DRM, MDP4, DSI, fbdev-emulation, and fbcon configuration. GPU
   acceleration is not required.
5. Build a separate artifact and use the existing ramoops/USB console to
   capture probe logs. On physical hardware, accept each stage separately:
   MMCC/MDP4 probe, DSI PHY/host, panel enable, backlight, then visible fbcon.

Until a new owner-approved deployment, all display components remain
`RESEARCHING`; display, backlight, and fbcon are `NOT_VERIFIED`.
