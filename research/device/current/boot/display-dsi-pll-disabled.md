# Hikari display: DSI PLL was programmed but never started

## Physical boundary

The retained mainline log from the latest display attempt proves that the
kernel remained alive and reached the complete software display stack:

- both MDP IOMMUs attached and MDP4 reported hardware version 4.1;
- DRM selected the native `720x1280` mode;
- the Hikari 45 nm DSI PHY profile was programmed for 418037760 bit/s;
- `msmdrmfb`, `fb0`, and fbcon registered;
- AS3676 produced physically visible LCD illumination;
- PID 1 reached `/init`, started the USB service and shell, and continued its
  alive loop.

The first display failure was instead a `PRIMARY_VSYNC` timeout immediately
after the PHY setup. No MDP/DSI interrupt followed. This excludes a kernel
crash and places the failure before valid DSI video timing reached the panel.
The stock Android display working normally independently excludes a broken
panel, flex cable, or backlight as the explanation.

## Exact source mismatch

Sony's MSM8x60 implementation in
`drivers/video/msm/msm_dss_io_8x60.c:mipi_dsi_clk_enable()` reads
`DSIPHY_PLL_CTRL_0` at DSI offset `0x0200` and writes it back with bit 0 set.
Its disable path writes `0x40` to the same register.

The project 45 nm PHY driver programmed the source-derived PLL table, whose
first value is `0x40`, but never performed Sony's separate enable write. Its
fixed-rate CCF clock providers describe the output rates; they do not have
hardware enable operations and therefore could not start the underlying PLL.
This exactly explains the otherwise contradictory result: DRM, framebuffer,
panel sequencing, and backlight could all complete while DSI generated no
video clock or VSYNC.

Signed kernel commit `825085ffdeb71af31431455927df68561406d86e` now writes
`0x41` only after all other PLL/PHY programming, reads the register back for
the next physical log, and restores `0x40` before PHY power-down. The project
guard rejects future Hikari builds which omit either transition.

## Why the USB terminal was absent without a kernel crash

The same log proves that `/init` ran, `/dev/ttyGS0` existed, the UDC and gadget
were reported ready, a direct device-side write returned success, and the
interactive shell process started. The repeated display commit timeouts did
delay initramfs startup until about 79 seconds, but did not terminate PID 1.

Those device-side events are not proof that the host completed USB
enumeration or that usbipd attached the new gadget identity. A ttyGS write may
be queued successfully with no configured host endpoint, and a shell may wait
indefinitely on that tty. Therefore the missing terminal was a host-visible
USB transport/attachment failure in that attempt, not evidence that Linux or
the init supervisor had died. The retained target log cannot distinguish a
failed re-enumeration from a failed usbipd re-attach; that boundary requires
the corresponding host log during the next run.

## Next physical acceptance test

The successor must show `PLL_CTRL_0 0x41`, DSI/MDP interrupts and advancing
vblank counters, followed by visible native-resolution pixels. If VSYNC is
still absent despite a confirmed `0x41` readback, the next boundary is PLL
lock/lane-clock generation rather than panel hardware.
