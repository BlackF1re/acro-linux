# Hikari built-in display bring-up

The target architecture is upstream DRM/MSM MDP4 -> DSI -> DRM panel -> DRM
fbdev emulation -> fbcon. The Android framebuffer stack is research evidence,
not the intended architecture.

## Evidence

`VERIFIED_VENDOR_SOURCE` from the Fuji downstream BSP identifies the board
panel family as Renesas R63306 and the `mipi_video_tmd_wxga_mdv22` profile:
1280x720, RGB888, four DSI lanes, video non-burst sync-event mode, and the
legacy timing tuple hback/hfront/hpulse `45/128/3`, vback/vfront/vpulse
`3/9/4`. The source also records LCD power GPIO18, reset GPIO70, MDP vsync
GPIO28, PM8901 L2 (2.85 V VCI), PM8901 LVS1 (VDDIO), and PM8058 L0 DSI power.
These are inputs for a future board-level upstream conversion, not a claim
that the present DTS correctly drives any of them.

At Linux
[`786262be6048`](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=786262be6048deab760f68c8acc2c85607165894),
DRM/MSM contains `DRM_MSM`, MDP4, DSI and fbdev-emulation infrastructure.
It does not contain an MSM8x60/45 nm DSI PHY implementation suitable for this
panel, nor an exact R63306 panel driver; the superficially similar R63353 is
not treated as compatible.

## BOOT #5 decision

No display node, panel driver, MMCC/interconnect patch, or fbcon configuration
is included in BOOT #5. Adding one would require inventing unproven 45 nm PHY,
MMCC/MMFAB and panel-init behaviour. USB ACM is intentionally the sole
external BOOT #5 diagnostic target.

Display remains `IMPLEMENTING`, not `PROBES`. The bounded implementation
sequence and the BOOT #5.1 read-only live baseline are documented in
[DISPLAY_BRINGUP_PLAN.md](DISPLAY_BRINGUP_PLAN.md). Only a physical visible
native-resolution fbcon result can verify the subsystem.
