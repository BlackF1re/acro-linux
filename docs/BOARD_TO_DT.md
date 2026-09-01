# Legacy Fuji board files to modern Device Tree map

This is a translation ledger, not a DTS.  Legacy Android board files encode
useful wiring facts but often mix policy, old Qualcomm APIs and device-specific
power magic.  Each item must be justified against current bindings before a DT
node is written.

| Legacy construct / evidence | Physical component | Known bus, GPIO or resource | Modern subsystem / eventual DT concept | Confidence and constraint |
| --- | --- | --- | --- | --- |
| `mipi_renesas_r63306` and legacy dmesg | Renesas R63306 display path | DSI; panel timing/supplies not yet recovered | DRM panel + DRM/MSM DSI node, supplies/reset/backlight properties | Historical + device evidence; exact panel glass/supplier remains unresolved. |
| `touch-fuji_hikari.c`; `clearpad-i2c` | ClearPad TM1964-001 | I2C0-002c; IRQ/reset unknown | Input touchscreen node with regulator/reset/interrupt properties appropriate to an accepted driver | Device evidence for module/path; no current Hikari-ready driver established. |
| `board-fuji-camera.c` | Rear module KMO13BS0 | I2C1-001a; common MCLK GPIO32, I2C GPIO47/48; rear reset GPIO106 in legacy source | V4L2 async sensor, regulator/reset/clock endpoints to CSI | Module, not sensor die: exact rear die UNKNOWN. |
| `board-fuji-camera.c` | Front module | I2C1-0048; front reset GPIO25 in legacy source | V4L2 sensor endpoint to CSI | Device calls it STW01BM0; OpenSEMC names `STW00YP1`. Treat as a variant/source conflict, not silicon identification. |
| `nfc-fuji.c` and I2C inventory | NXP PN544 | I2C3-0028; enable/IRQ GPIOs still to extract | `pn544` I2C NFC node with interrupt, enable and supply | Exact controller is direct device evidence. PM8058-side `pm8xxx-nfc` is helper topology, not proof of second NFC IC. |
| `leds-fuji_hikari.c` | AS3676 LED controller | I2C3-0040; sink groups in legacy table | LED controller node, child LEDs and regulator | Exact chip/address observed; current exact binding/driver needs confirmation. |
| legacy LM3560 registration | LM3560 flash | I2C3-0053 | V4L2 flash subdevice with `vin-supply`, enable/flash controls | Exact chip/address observed; upstream `lm3560` driver exists. |
| legacy charging / I2C inventory | BQ24160 charger | I2C3-006b | power-supply charger node, IRQ/supplies/USB role inputs | Exact chip/address observed; confirm that BQ2415x binding covers it. |
| legacy fuel-gauge / I2C inventory | BQ27520 | I2C3-0055 | power-supply gauge node | Exact chip/address observed; private battery calibration must not enter repository. |
| legacy sensor registration | APDS9702 | I2C3-0054 | IIO/input sensor node | Direct address/chip name, but current upstream support unknown. |
| legacy sensor registration | AKM8972 | I2C5-000c | IIO magnetometer node | Direct address/chip name; driver/binding remains to be found. |
| legacy sensor registration | BMA250 | I2C5-0018 | IIO accelerometer node | Direct address/chip name; orientation and support unconfirmed. |
| legacy sensor registration | MPU-3050 | I2C5-0068 | `invensense,mpu3050` IIO node | Current upstream driver has this compatible; Hikari IRQ/orientation unknown. |
| bcm4330 module parameters | BCM4330 Wi-Fi/BT combo | SDIO mmc2; BT transport/power GPIOs unknown | MMC SDIO Wi-Fi plus UART HCI BCM node | Module/path evidence; calibration contents prohibited. |
| `board-semc_fuji-audio.c` | Timpani audio / amps | legacy speaker amp GPIO20 and GPIO16; MI2S resources | ASoC codec/DAI routes, GPIO amps, jack detect | Legacy reference only; codec and voice architecture not yet recoverable as modern topology. |
| `board-semc_fuji.c`, PMIC tables | PM8058 / PM8901 | PMIC IRQ/GPIO/MPP and rails | SPMI/SSBI PMIC nodes, RPM regulators, GPIO/MPP pinctrl | PMIC revisions observed; each rail and interrupt needs explicit source mapping. |
| legacy HDMI / USB board glue | integrated MSM8x60 paths | PHY, VBUS, ID, connector pins unknown | DRM HDMI / USB controller+PHY+connector nodes | Framework is not board wiring; do not infer values from SURF. |
| PIL/SMD legacy logs | modem and ADSP | shared-memory carveouts recorded; channel names incomplete | remoteproc/IPC/telephony architecture, if applicable | Architecture and firmware ABI remain a blocker. |

The source paths behind this ledger are enumerated in [SOURCES.md](SOURCES.md).
Exact values from legacy source require review against current bindings; none
have been copied into a target DTS.
