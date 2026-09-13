# Hardware inventory

Read-only physical evidence is kept under research/device/current/, including
the sanitized full legacy dmesg and raw bus snapshot. The attached phone is
Sony Xperia acro S LT26w / Fuji (hikari).

## Silicon identity

| Fact | Value | Evidence |
| --- | --- | --- |
| Family | Qualcomm MSM8x60 / Snapdragon S3 | physical socinfo plus upstream Qualcomm ID table |
| Legacy BSP platform string | msm8660 | ro.board.platform only |
| Exact physical SKU | MSM8260 | root-readable soc0 ID 70, mapped by upstream `QCOM_ID_MSM8260 = 70` |
| SoC revision fields | version 2.1; raw_id 1057; raw_ver 2 | root-readable soc0 and sanitized dmesg |
| Qualcomm build metadata | M8660A-AABQNLYM-3.1.4003T | root-readable soc0 build_id; not a silicon-SKU field |

The SKU conclusion is an evidence chain: physical socinfo ID 70 plus the
upstream ID mapping. It is **not** inferred from either `ro.board.platform`
or the `M8660A` prefix in build metadata. The latter two fields describe the
legacy BSP and Qualcomm build respectively; neither changes the physical SKU.
The complete sanitized device evidence is
[socinfo.txt](../research/device/current/kernel/socinfo.txt); source
provenance is in [SOURCES.md](SOURCES.md).

## Identified components and legacy topology

| Function | Observed device / address | Legacy driver | Component identification | Confidence |
| --- | --- | --- | --- | --- |
| Internal panel path | platform mipi_renesas_r63306.0 | mipi_renesas_r63306 | legacy driver identifies Renesas R63306 path; 720x1280 MIPI-DSI | VERIFIED_DEVICE |
| Touch | I2C 0-002c | clearpad-i2c | Sony ClearPad, legacy ID TM1964-001 | VERIFIED_DEVICE |
| Main camera module | I2C 1-001a, video0/video1 | sony_sensor_main | Sony module ID KMO13BS0; exact sensor die UNKNOWN | VERIFIED_DEVICE / UNKNOWN |
| Front camera module | I2C 1-0048, video2/video3 | sony_sensor_sub | Sony module ID STW01BM0; exact sensor die UNKNOWN | VERIFIED_DEVICE / UNKNOWN |
| NFC controller | I2C 3-0028, /dev/pn544 | pn544 | NXP PN544 | VERIFIED_DEVICE |
| LED controller | I2C 3-0040 | as3676 | ams/OSRAM AS3676 | VERIFIED_DEVICE |
| Camera flash | I2C 3-0053 | lm3560 | TI LM3560 | VERIFIED_DEVICE |
| Proximity/light | I2C 3-0054 | apds9702 | Avago APDS-9702 | VERIFIED_DEVICE |
| Fuel gauge | I2C 3-0055 | bq27520 | TI BQ27520, firmware 5.7 reported | VERIFIED_DEVICE |
| Charger | I2C 3-006b | bq24160 | TI BQ24160, revision 0x05 reported | VERIFIED_DEVICE |
| Magnetometer | I2C 5-000c | akm8972 | AKM AKM8972 | VERIFIED_DEVICE |
| Accelerometer | I2C 5-0018 | bma250 | Bosch BMA250 | VERIFIED_DEVICE |
| Gyroscope | I2C 5-0068 | mpu3050 | InvenSense MPU-3050 | VERIFIED_DEVICE |
| WLAN / Bluetooth | SDIO mmc2:0001; UART/power devices | bcm4330, bcm_bt_lpm, bt_power | Broadcom BCM4330 combo, identified by legacy names/topology | VERIFIED_DEVICE |
| Audio / FM companion path | I2C 4-000d, platform timpani_codec | marimba-core, timpani_codec | Qualcomm legacy Timpani codec stack; physical die part number not direct | VERIFIED_DEVICE / HYPOTHESIS |
| PMIC | SSBI msm_ssbi.0/.1 | pm8058-core, pm8901-core | Qualcomm PM8058 rev E3 and PM8901 rev 2.1 | VERIFIED_DEVICE |
| eMMC | mmc0:0001 | mmcblk | MAG2GA, manfid 0x15, manufacture 08/2012; vendor name not asserted | VERIFIED_DEVICE |
| HDMI | platform hdmi_msm.* | hdmi_msm | MSM8x60 HDMI block; external PHY/controller unknown | VERIFIED_DEVICE / UNKNOWN |
| USB | platform msm_otg, msm_hsusb* | legacy MSM OTG/host | MSM8x60 integrated USB path; exact PHY die unknown | VERIFIED_DEVICE / UNKNOWN |

The exact Fuji/Hikari USB connector wiring is `HISTORICAL_SOURCE` from the
OpenSEMC Sony-generation board code uses explicitly zero-based PMIC indices:
index 30 is physical PM8058 GPIO31 ID with a 1.5 kOhm S3 pull-up; index 10 is
physical PM8058 MPP11 VBUS detect; PM8901 index 0 is physical MPP1 and
enables external 5 V; TLMM28 enables the NCP373 protected VBUS switch; and
TLMM104 is its active-low fault input. PM8901 is on the second SSBI controller
at `0x00c00000`, with an active-low interrupt on TLMM91 and four MPPs. These
facts are implemented in the current local DT. Build 0079 is
`VERIFIED_DEVICE` under target Linux for source power, EHCI High-Speed
enumeration of a Mercusys/Realtek `2c4e:0102` adapter, clean host removal and
return to device role. PM8xxx consumer specifiers use physical
one-based GPIO/MPP numbers even though controller `gpio-ranges` remain
zero-based. The 0073 boot proved that encoding USB-ID as 29 selects host mode
with a normal notebook cable. Rechecking Sony's namespace showed that its
indices 30/10 map to physical mainline GPIO31/MPP11; the current DT statically
checks those values together with MPP1. Build 0079 then physically verified
the corrected source path.

PM8901 MPP control registers start at `0x27`, unlike the PM8058 MPP base
`0x50`. This is `VERIFIED_VENDOR_SOURCE` from Sony's PM8901 MFD source and
`VERIFIED_DEVICE` by build 0077 regmap readback: physical MPP1 remained
`0x30` while the old generic-driver path wrote through the wrong base. Patch
0071 encodes the compatible-specific base; build 0079 physically verified its
effect through powered peripheral enumeration.

The wiring is also `VERIFIED_DEVICE` under the Sony-derived Android kernel.
During a physical OTG test PM8901 MPP1 (`ext_5v_en`, legacy GPIO225) and
TLMM28 (`ncp373_en`) changed low-to-high together, while the active-low
TLMM104 fault input returned high. The host enumerated three real devices,
including a Kingston DataTraveler and a USB keyboard/mouse receiver. This
validates the hardware facts, but is not target-Linux acceptance.

pm8xxx-nfc is a PM8058-side platform support node (power/interrupt
integration); it is not evidence for a second NFC controller. The I2C pn544
node and /dev/pn544 identify the controller.

The full bus-to-driver table is in research/device/current/topology/bus-matrix.md.
The table describes physical evidence or the legacy driver's own component
identification. It does not itself demonstrate a function, nor any target
Linux implementation; see [STATUS.md](STATUS.md) and
`status/hardware.yaml`.
