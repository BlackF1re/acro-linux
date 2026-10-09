# Hikari FM receiver

## Hardware and transport

The tuner is **Broadcom BCM4330**, shared with Bluetooth and Wi-Fi. It is
controlled by vendor HCI opcode `0xfc15` over the existing Bluetooth UART.
Wired headphones provide the antenna.

Evidence checked on 2026-10-09:

- `VERIFIED_DEVICE`: the Sony stock system contains `libfmradio.brcm-prop_rx.so`;
  native HCI FM power, frequency writes and frequency readback succeeded.
- `VERIFIED_DEVICE`: the native driver created `/dev/radio0`. V4L2 querycap,
  tuning, frequency readback and signal reads succeeded. Headphone-assisted
  scans made 103 initial and 206 final successful tuning/readback operations.
  The final scan covered 87.5–108.0 MHz at 100 kHz spacing.
- `VERIFIED_DEVICE`: `v4l2-compliance` 1.30.1 completed **49/49** checks,
  zero failures and warnings; an ordinary `phosh` user could open and tune
  the radio through the normal video-group/uaccess permissions.
- `VERIFIED_VENDOR_SOURCE`: Sony's `msm_fm` misc device is a DSP audio endpoint.
  Hikari registers Timpani as an audio codec, without a Marimba FM child.
- Sony defines `fmradio_stereo_rx`, `MI2S_RX`, `MI2S_SD3`, stereo, 48 kHz;
  the FM MI2S pins are GPIO 101 (WS), 102 (SCLK), 107 (SD).

The original identification as “Qualcomm companion FM” was incorrect.
Signal changes across the band do not by themselves identify a broadcast
station or prove audible reception.

## Native implementation

`kernel/patches/0020-hikari-fm-radio.patch` adds `CONFIG_RADIO_BCM4330=m`:

- `/dev/radioX` with standard V4L2 radio/tuner ioctls;
- 87.5–108 MHz tuning, bounded seek, signal and stereo status;
- mute and 50/75 microsecond de-emphasis controls;
- RDS blocks through `read()`/`poll()`, sampled only while requested;
- automatic FM child registration for a BCM4330 serdev controller;
- shared HCI command serialization; no Android daemon or proprietary library.

Bluetooth must be powered and the factory address must already be applied.
The existing SYSTEM build personalizes the DTB from private calibration.
Do not publish that address or substitute the firmware's default address.
Closing the last radio file powers the tuner down.

## Acceptance and limitations

Implementation state: **PARTIAL**.

Initial tuning and band scan passed on Linux
`7.3.0-rc1-hikari-system-wake2-20261009-gf83137430dc0-dirty`, with staged
`hci_uart` and FM modules. A subsequent `v4l2-compliance` test exposed a
nested control mutex; the source now uses separate ioctl and control locks.
The corrected driver subsequently passed all 49 V4L2 compliance checks.
The Broadcom-required 300 ms FM power-up delay, RDS FIFO reset and channel
step initialization are included. RDS reads on 87.5 MHz returned 33 blocks,
24 flagged uncorrectable and 9 corrected; this proves the block transport,
not valid station identity. No RDS blocks arrived on 91.5, 98.0 or 102.1 MHz in 20-second probes.
Signal peaks align with the station frequencies supplied by the owner,
including 87.7, 91.5, 98.0 and 106.6 MHz; this remains weaker evidence
than decoding a stable station identity.
Hardware seek returned `ENODATA` and restored the original frequency; a
successfully found broadcast station remains unverified.

**Audio is blocked:** the running SYSTEM exposes no ALSA sound card
(`/proc/asound/cards`: `--- no soundcards ---`). The separate native
MSM8660 MI2S/DSP/Timpani audio path must be implemented before listening
through the headphones. Enabling the tuner's mute control cannot create
that missing audio route. No audible station or RDS station identity has
been accepted yet.

## Standard application usage

After loading matching SYSTEM modules and powering Bluetooth:

```sh
bluetoothctl power on
v4l2-ctl --device=/dev/radio0 --all
v4l2-compliance --device=/dev/radio0
```

An application must keep its radio file open while receiving. Use standard
`VIDIOC_S_FREQUENCY`, `VIDIOC_G_TUNER`, `VIDIOC_S_HW_FREQ_SEEK` and RDS block
reads; frequency units are 62.5 Hz (`V4L2_TUNER_CAP_LOW`). Audio playback
will additionally require the ALSA path above.

## References

- [Sony 6.2.B.1.96 source mirror](https://github.com/DooMLoRD/android_kernel_sony_msm8660/tree/ae953d9a9f149db0c3a51e2b587074d0d911b7ea),
  `arch/arm/mach-msm/board-semc_fuji.c`,
  `arch/arm/mach-msm/qdsp6v2/board-semc_fuji-audio.c`,
  `drivers/mfd/marimba-core.c`, `arch/arm/configs/fuji_hikari_row_defconfig`.
- [Sony Broadcom FM integration](https://github.com/sonyxperiadev/vendor-broadcom-bt-fm/tree/2da2991694277c0e29782fbadffe69027adeb09a),
  GPL-2.0 driver helpers and userspace V4L2 integration.
- [Broadcom GPL register protocol](https://github.com/LineageOS/android_kernel_lge_msm8996/tree/056872e0e024dcf1cc9e98fc9db9e639eebdea98/drivers/bluetooth/brcm_v4l2),
  `fmdrv_main.h`, `fmdrv.h`, `fmdrv_rx.c`, `fmdrv_main.c`;
  used for register/packet facts, not an Android transport port.
- [Linux V4L2 radio interface](https://www.kernel.org/doc/html/latest/userspace-api/media/v4l/dev-radio.html).

## Tested artifact

The FM module was built by ARM GCC 15.2.0 with the existing SYSTEM config
and `CONFIG_RADIO_BCM4330=m`. Both the UART and FM modules were staged in
`/run/hikari-fm-test`; system modules and boot bundles were not replaced.
The FM module SHA256 and final acceptance logs are stored alongside
[device evidence](../research/device/current/fm/). On reboot, normal installed
modules return until a SYSTEM build including the FM patch is installed.

Reproduce the on-device RDS probe (exit 2 means no blocks, inconclusive):

```sh
arm-linux-gnueabihf-gcc -O2 -Wall -Wextra -Werror \
  tools/hikari_fm_probe.c -o hikari-fm-probe
# Transfer the executable to the phone, then run as its ordinary desktop user:
./hikari-fm-probe 102100
./hikari-fm-probe 87700 seek
```
