# Hikari internal BCM4330 bring-up (2026-09-16)

## Result

`WORKING`, `VERIFIED_DEVICE`: the current 7.3-rc1 second-stage kernel physically
enumerated the soldered BCM4330 over SDIO, loaded `brcmfmac`, created `wlan0`,
and completed repeated active scans. Accepted scans found between six and nine
BSSes. It then associated with an authorized protected network, acquired DHCP
and a default route, resolved DNS and passed real packet traffic. After a
forced supplicant stop and address removal, it reassociated, reacquired DHCP
and passed traffic again.

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

## Network acceptance

The 2026-09-16 physical acceptance run used the packaged Debian 13 armhf
`wpa_supplicant`, a credential held only in a mode-`0600` file under `/run`,
and `systemd-networkd` DHCP. Privacy-preserving checks passed:

- association, IPv4 DHCP and a default route;
- DNS resolution and five-packet traffic to a controlled public endpoint;
- forced supplicant termination, removal of the assigned address,
  reassociation, fresh DHCP and a repeated traffic pass;
- a third reassociation with `p2p_disabled=1`, with no new P2P-interface error.

The optional P2P interface is not supported by this legacy firmware path and
is not part of the accepted station-mode result. The global supplicant service
remained disabled; the test connection was explicit and transient. Temporary
transfer packages were removed after `dpkg --audit` passed.

## Firmware and remaining blockers

The private device rootfs uses Sony's installed BCM4330 B2 firmware and Hikari
calibration under the board-specific `brcmfmac` filename. Neither file is
committed or redistributable. Firmware boot succeeds, but no CLM/txcap blobs
are available, so the driver reports limited channels. It also rejects the
firmware-default address and assigns a random address despite the private
calibration file; production MAC provenance remains unresolved.

Before subsystem-level `VERIFIED`: pass suspend/resume and wake behavior,
complete regulatory-domain/CLM handling, power measurements, longer reconnect
endurance and stable device-specific MAC provisioning.
