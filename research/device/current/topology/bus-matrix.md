# Legacy bus topology matrix

Source: rooted, read-only sysfs enumeration. Addresses and driver bindings are
direct evidence; the physical-chip column is intentionally UNKNOWN where the
legacy name is not a direct component identity.

## I2C

| Bus/address | Kernel device | Driver | Probable physical chip | Confidence |
| --- | --- | --- | --- | --- |
| 0-002c | clearpad-i2c | clearpad-i2c | Sony ClearPad, TM1964-001 legacy ID | VERIFIED_DEVICE |
| 1-001a | sony_sensor_main | sony_sensor_main | rear camera module KMO13BS0; sensor die UNKNOWN | VERIFIED_DEVICE / UNKNOWN |
| 1-0048 | sony_sensor_sub | sony_sensor_sub | front camera module STW01BM0; sensor die UNKNOWN | VERIFIED_DEVICE / UNKNOWN |
| 3-0028 | pn544 | pn544 | NXP PN544 NFC controller | VERIFIED_DEVICE |
| 3-0040 | as3676 | as3676 | AS3676 LED controller | VERIFIED_DEVICE |
| 3-0053 | lm3560 | lm3560 | TI LM3560 camera flash | VERIFIED_DEVICE |
| 3-0054 | apds9702 | apds9702 | APDS-9702 proximity/ambient-light sensor | VERIFIED_DEVICE |
| 3-0055 | bq27520 | bq27520 | TI BQ27520 fuel gauge | VERIFIED_DEVICE |
| 3-006b | bq24160 | bq24160 | TI BQ24160 charger | VERIFIED_DEVICE |
| 4-000d | timpani | marimba-core | Qualcomm legacy Timpani companion path | HYPOTHESIS |
| 4-0066, 4-0077, 8-0055 | timpani | dummy | legacy dummy aliases, physical purpose UNKNOWN | VERIFIED_DEVICE / UNKNOWN |
| 5-000c | akm8972 | akm8972 | AKM8972 magnetometer | VERIFIED_DEVICE |
| 5-0018 | bma250 | bma250 | Bosch BMA250 accelerometer | VERIFIED_DEVICE |
| 5-0068 | mpu3050 | mpu3050 | InvenSense MPU-3050 gyroscope | VERIFIED_DEVICE |

## MMC/SDIO

| Host / address | Kernel device | Driver | Physical component | Confidence |
| --- | --- | --- | --- | --- |
| msm_sdcc.1, 0x12400000, IRQ 136 | mmc0:0001 | mmcblk | MAG2GA eMMC, 8-bit | VERIFIED_DEVICE |
| msm_sdcc.3, 0x12180000, IRQ 134/642 | mmc1 | msm_sdcc | microSD host; no card at sampling | VERIFIED_DEVICE |
| msm_sdcc.4, 0x121c0000, IRQ 133 | mmc2:0001 | BCM4330 host driver | BCM4330 SDIO WLAN | VERIFIED_DEVICE |

## SSBI / PMIC

SSBI controller msm_ssbi.0 exposes PM8058 subdevices: keypad, LED, OTHC
headset-detection instances, PWM, XOADC, battery alarm, GPIO/MPP, NFC support,
power key, thermal monitor, USB power and vibrator, microphone bias and RTC.
msm_ssbi.1 exposes PM8901 regulator, MPP and thermal/misc subdevices.

## Platform topology

The raw platform-device list is recorded in ../kernel/bus-topology-raw.txt.
Important direct bindings include:

- display: mipi_dsi, mipi_renesas_r63306, mdp, msm_fb, hdmi_msm;
- graphics/video: kgsl-2d, kgsl-3d, msm_vidc, msm_vfe, msm_gemini,
  semc_vpe, msm_rotator;
- camera: msm_cam_server, two msm_csic instances, the two I2C camera modules;
- power: msm_rpm, rpm-regulator, saw-regulator, PM8058/PM8901, chargalg;
- USB: msm_otg, msm_hsusb and msm_hsusb_host;
- audio: soc-audio, msm codec/cpu DAI, msm DSP/MVS/MI2S and timpani_codec;
- modem/DSP: pil_modem, pil_qdsp6v3, pil_dsps, pil_tzapps, msm_smd,
  APR audio/voice, and DATA*/DIAG/IPCROUTER SMD endpoints;
- persistent diagnostics: ram_console and ramdumplog.

## Media, audio and radio topology

The legacy V4L2 nodes map video0/video1 to the main I2C camera module and
video2/video3 to the front module. msm_cam_server is video100. Dmesg records
probe and CSI configuration for both modules. No capture was started; the
module IDs must not be confused with exact sensor-die IDs, which remain
UNKNOWN.

Audio uses legacy MSM DSP audio, ASoC-style CPU/codec DAI nodes, numerous
snddev_icodec endpoints, snddev_hdmi endpoints, msm_mvs_audio and
apr_voice_svc. This establishes legacy playback, routing, HDMI-audio and
voice-path infrastructure; it does not identify every analogue amplifier or
prove a functional path.

Modem topology is PIL modem plus SMD endpoints, rmnet0 through rmnet7 and
rmnet_mux_ctrl. QDSP6 and DSPS have separate PIL nodes. Dmesg records modem
reset release and later “Modem Is Up”; this is a legacy runtime observation,
not a modem acceptance test. Legacy remote storage opens logical modem_fs1,
modem_fs2 and modem_fsg names during boot; those are not mapped here to raw
partitions.

The device nodes include /dev/pn544, /dev/smd*, /dev/smd_sns_dsps,
/dev/smd_sns_adsp, /dev/smd_cxm_qmi, /dev/ttyHS0 and /dev/ttyHSL0. No radio,
GNSS, FM or NFC command was issued. A Qualcomm FM Radio Transceiver driver
and /sys/class/misc/msm_fm were registered. GNSS hardware and its exact
transport remain UNKNOWN: the observed SMD sensor/DSP nodes are insufficient
to identify a GNSS receiver.
