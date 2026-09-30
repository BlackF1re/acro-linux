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

## System memory

Sony's Fuji board code defines 939 MiB of normal Linux RAM in three banks:
`0x40200000-0x42dfffff`, `0x48000000-0x5fffffff` and
`0x60000000-0x7fefffff`.  The target DT starts the first region at
`0x40000000` so the upstream MSM8x60 code can reserve its leading 2 MiB for
SMEM; it preserves the vendor gap below `0x48000000` and the final MiB above
`0x7fefffff`.  The latter also contains the separate 128 KiB ramoops region.

On 2026-09-25 the physical SYSTEM kernel reported 941 MiB described before
SMEM and other reservations, 939 MiB normal RAM after the SMEM carveout, and
`MemTotal: 928996 kB` (about 907 MiB usable by Linux), up from 643368 kB with
the truncated bring-up DT.  `HIGHMEM` exposes the upper 255 MiB and the 64 MiB
CMA pool remains reclaimable Linux memory needed for non-IOMMU display/GPU
buffers.  A 640 MiB anonymous mapping passed full write/read cycles with both
`0x55` and `0xaa`; no page, allocation, abort, Oops or panic followed.  FD220
rendering remained functional.  Direct fbcon-to-kmscube master handoff emits
two repeatable primary-interface underruns, which is a separate display
transition issue rather than evidence of a RAM fault.

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
| Headset insertion | TLMM GPIO61 | gpio-keys | high when inserted; `SW_HEADPHONE_INSERT` | VERIFIED_DEVICE |
| Board analog sensors | PM8058 XOADC MPP3/7/10/8/5 | pm8xxx-xoadc | headset accessory/button ADC, battery thermistor, MSM thermistor, battery ID, charger-current monitor | VERIFIED_VENDOR_SOURCE / VERIFIED_DEVICE |
| WLAN / Bluetooth | SDIO mmc2:0001; UART/power devices | bcm4330, bcm_bt_lpm, bt_power | Broadcom BCM4330 combo, identified by legacy names/topology | VERIFIED_DEVICE |
| Audio / FM companion path | I2C 4-000d, platform timpani_codec | marimba-core, timpani_codec | Qualcomm legacy Timpani codec stack; physical die part number not direct | VERIFIED_DEVICE / HYPOTHESIS |
| PMIC | SSBI msm_ssbi.0/.1 | pm8058-core, pm8901-core | Qualcomm PM8058 rev E3 and PM8901 rev 2.1 | VERIFIED_DEVICE |
| eMMC | mmc0:0001 | mmcblk | MAG2GA, manfid 0x15, manufacture 08/2012; vendor name not asserted | VERIFIED_DEVICE |
| HDMI | platform hdmi_msm.* | hdmi_msm | MSM8x60 HDMI block; external PHY/controller unknown | VERIFIED_DEVICE / UNKNOWN |
| USB | platform msm_otg, msm_hsusb* | legacy MSM OTG/host | MSM8x60 integrated USB path; exact PHY die unknown | VERIFIED_DEVICE / UNKNOWN |

The BCM4330 WLAN half is soldered to MSM SDCC4 with a four-bit bus running up
to 48 MHz. `HISTORICAL_SOURCE` Sony-generation board data identifies TLMM130 as
active-low `WL_RST_N`, TLMM128 as the out-of-band `WL_HOST_WAKEUP`, and physical
PM8058 GPIO38 alternate function 2 as the 32.768 kHz sleep clock. It also names
PM8058 S3 at 1.8 V as the physical SDCC4 rail while advertising the 2.7--2.9 V
MMC OCR bits. The current DT therefore uses a logical fixed OCR adapter but
does not program shared S3 until all consumers and RPM constraints are known.
On 2026-09-16 `VERIFIED_DEVICE` evidence showed SDIO `02d0:4330`, a loaded
native `brcmfmac` interface, repeated active scans, association to an
authorized network, DHCP/default-route acquisition, DNS and bidirectional
packet traffic. A forced supplicant stop followed by address removal also
reassociated, reacquired DHCP and passed traffic again. This establishes
`WORKING`. On 2026-09-24 sustained receive traffic exposed a Qualcomm MMCI PIO
FIFO-window bug (`MCI_STARTBITERR`/`-ECOMM`). The initial eight-address change
still failed on a reconnect after 6493 seconds because it restarted the FIFO
offset for every burst. The corrected implementation now advances across the
complete cyclic FIFO window for one PIO service, exactly as Sony's downstream
MSM SDCC driver does. On 2026-09-25 the physical device passed ten reconnects,
about 355 MiB of HTTPS receive traffic, and another three reconnects with real
traffic, without an MMCI, SDIO-header or backplane error. NetworkManager now
supplies a stable per-installation MAC
instead of accepting brcmfmac's random fallback. The BCM4330 B2 firmware also
advertises P2P but cannot create that interface; the standard brcmfmac feature
mask suppresses only P2P, removing its timeout while station reconnect and
traffic continue to pass. Signed `wireless-regdb` is installed, but this old
firmware exposes its own `99` regulatory domain and no verified Sony country
map or CLM data has been found; regulatory completeness, power measurement and
suspend/resume and a repeated long-idle reconnect therefore remain open. See the
[sanitized bring-up record](../research/device/current/boot/internal-wifi-bringup-2026-09-16.md).

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

Sony's Fuji board data maps the five board analog inputs above to XOADC
channels 5 through 9 in that order and powers the ADC reference from PM8058 L18
at 2.2 V.  The target kernel now models those routes in DT.  Physical SYSTEM
boot evidence on 2026-09-24 showed all five channels readable with their MPPs
owned by XOADC.  The MSM NTC changed monotonically in the expected direction
during CPU heating and is exported as the standard `msm-board-thermal` thermal
zone using Sony's conversion table.  Headset, battery-ID and charge-monitor
functional state transitions still require their individual acceptance tests.
Headset insertion itself is a separate TLMM61 signal: repeated physical
insert/remove cycles changed it cleanly, generated edge IRQs and updated the
standard `SW_HEADPHONE_INSERT` input switch after Sony's 1500 ms debounce.
