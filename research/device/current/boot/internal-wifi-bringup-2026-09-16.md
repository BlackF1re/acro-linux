# Hikari internal BCM4330 bring-up (2026-09-16)

## Result

`PARTIAL`, `VERIFIED_DEVICE`: the current 7.3-rc1 second-stage kernel physically
enumerated the soldered BCM4330 over SDIO, loaded `brcmfmac`, created `wlan0`,
and completed repeated active scans. Accepted scans found between six and nine
BSSes. Network association, DHCP and real packet traffic are
still required before promotion to `VERIFIED`.

No SSID, BSSID, MAC address, calibration content or other device identifier is
stored in this record.

## Root cause and smallest accepted change

Sony's Fuji board data routes the BCM4330 32.768 kHz sleep clock through
physical PM8058 GPIO38 in alternate function 2, powered from the S3 GPIO input
domain. With that pin unclaimed, SDCC4 did not enumerate the radio. Modelling
the exact mux as the pinctrl state of `mmc-pwrseq-simple` made the clock active
before WL_RST_N was released; the physical device then appeared as SDIO vendor
`0x02d0`, device `0x4330`.

An intermediate experiment also made PM8058 S3 an explicit 1.8 V regulator.
It was rejected: S3 is a shared rail whose complete consumers/RPM constraints
are not yet represented, and partial DT control can disturb other hardware.
The accepted DT uses a fixed 2.8 V logical OCR adapter because Sony advertises
the 2.7--2.9 V MMC OCR bits, while deliberately leaving physical S3 under its
established bootloader/RPM state.

The remaining board wiring is SDCC4 four-bit at up to 48 MHz, WL_RST_N on
TLMM130 and out-of-band HOST_WAKE on TLMM128. SDIO DAT1 IRQ is not advertised
because the upstream PL18x host currently lacks `enable_sdio_irq()` support.

## Firmware and remaining blockers

The private device rootfs uses Sony's installed BCM4330 B2 firmware and Hikari
calibration under the board-specific `brcmfmac` filename. Neither file is
committed or redistributable. Firmware boot succeeds, but no CLM/txcap blobs
are available, so the driver reports limited channels. It also rejects the
firmware-default address and assigns a random address despite the private
calibration file; production MAC provenance remains unresolved.

Before `VERIFIED`: pass association, DHCP, bidirectional network traffic,
repeated connect/disconnect, suspend/resume, wake behavior, regulatory-domain
handling, and stable device-specific MAC provisioning.
