# BOOT #5.1 live baseline (sanitized)

Evidence level: `VERIFIED_DEVICE` where explicitly stated. Raw command line,
raw dmesg, and complete command captures remain private because they may carry
unique bootloader data.

## Runtime platform

- Runtime DT model: `Sony Xperia acro S (Hikari)`.
- Two ARM CPUs are online; `MemTotal` is 931376 KiB.
- Platform inventory includes RPM at `0x00104000`, ChipIdea HSUSB at
  `0x12500000`, GSBI at `0x19c00000`, timer at `0x02000000`, GCC at
  `0x02082000`, and ramoops at `0x7ffe0000`.
- No target DRM, backlight, LED, thermal, I2C, MMC, or SPI class device was
  instantiated in this intentionally minimal BOOT #5.1 DT. That is not a
  negative physical-hardware claim.

## USB acceptance state

The live UDC is `ci_hdrc.0`; its state is `configured`, with both current and
maximum speed reported as `high-speed`. `/dev/ttyGS0` is present as a character
device. This is consistent with the independently observed host CDC ACM
connection at 480 Mbps.

The live clock summary shows the USB interface and transceiver clocks enabled:
`usb_hs1_h_clk`, `usb_hs1_xcvr_clk` (60 MHz), `sleep_clk` (32.768 kHz), and
`cxo_board` (19.2 MHz). It also shows the RPM message-RAM clock enabled.

The regulator summary shows PM8058 L6 at 3050 mV with an enabled ULPI v3p3
consumer. It also lists an enabled ULPI v1p8 consumer. This accompanies, but
does not explain away, the separate L6 voltage-constraint warning: that warning
is `NON_BLOCKING_FOR_CURRENT_USB` and unresolved for power-cycle, runtime-PM,
suspend/resume, and OTG work.

## Minimal diagnostic-userspace baseline

The owner observed approximately 18 MiB used memory, approximately 913 MiB
free memory, roughly 95% idle CPU, and load average near zero. This is a
BOOT #5.1 diagnostic-initramfs baseline only; it is not a forecast for a full
distribution or graphical shell.

`crng init done` was observed only after roughly 367 seconds:
`RNG_ENTROPY=FUNCTIONAL_BUT_SLOW_INIT`. Runtime time began in 1970;
`RTC=NOT_VERIFIED/NOT_CONFIGURED`. Neither topic was changed during this live
read-only inventory.
