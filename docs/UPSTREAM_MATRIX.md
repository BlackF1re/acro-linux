# Hikari upstream feature matrix

Status is assessed at 2026-09-01.  “Generic upstream” means a relevant
framework or driver exists; it is deliberately not a claim of Hikari support.
“Gap” is the work needed before any target-Linux implementation can be called
even `PROBES`.  Physical evidence is in
[`research/device/current/`](../research/device/current/); legacy code paths
are recorded in [SOURCES.md](SOURCES.md).

| Area | Physical / legacy evidence | Current upstream status | Hikari-specific missing data or gap | Next research action |
| --- | --- | --- | --- | --- |
| SMP, CPU, timer | MSM8260, dual Scorpion | Generic MSM8660 DT CPU/GIC/timer support | Hikari memory/boot integration | Establish minimal boot contract only after archaeology review. |
| RAM and reserved memory | 1 GiB nominal; legacy visible RAM and carveouts recorded | Generic ARM memory/reserved-memory model | Correct Hikari memory map; secure holes unknown | Derive from vendor source and future boot logs; do not copy legacy map. |
| GCC, clocks, RPM | Legacy MSM8x60/PMIC runtime | MSM8660 GCC and RPM-regulator patterns exist | Board consumers and sequencing | Map each Hikari supply/clock from legacy board files. |
| PM8058 / PM8901 | PM8058 E3 and PM8901 2.1 observed | PM8058 DT description and RPM regulator infrastructure exist | Exact rail assignments and PMIC GPIO/MPP wiring | Reconcile vendor tables with measured topology. |
| GPIO / pinctrl | Legacy board mux and GPIO names | MSM8660 TLMM pinctrl exists | Every Hikari pin state | Build reviewed board-to-DT mapping first. |
| eMMC / microSD | MAG2GA on mmc0; removable mmc1 | SDCC/MMC infrastructure exists | Controller instances, supplies, CD/WP wiring | Extract only source-backed mapping. |
| USB PHY / device / host | Legacy USB topology observed | Generic MSM8x60 USB blocks/frameworks present | PHY tuning, ID/VBUS and charger interaction | Compare SURF patterns with Fuji source; no tests yet. |
| MIPI DSI panel | Renesas R63306 legacy path | DRM/KMS exists; no Hikari-ready R63306 path established | Panel supplier/timing, reset, regulators, backlight | Recover exact legacy panel configuration and find/assess upstream driver. |
| HDMI / HDMI audio | Legacy HDMI path reported | Generic DRM/MSM HDMI support exists for applicable hardware | Hikari pins, power, audio routing | Source-map board glue and validate generation compatibility. |
| DRM/MSM, Adreno 220 | Adreno 220 physical platform | A2xx DRM/MSM code exists; Mesa has Freedreno | Correct GPU node, firmware and board boot integration; no Hikari validation | Identify MSM8x60 GPU DT precedent and later run native renderer test. |
| Touchscreen | ClearPad TM1964-001 legacy runtime | No Hikari-ready ClearPad upstream path established | Controller protocol, IRQ/reset/supplies, coordinate map | Translate Sony tables only after binding/driver assessment. |
| Keys / camera key | Legacy input devices | Linux input/gpio-keys generic | GPIO/PMIC key map and debounce | Extract Fuji keypad definitions. |
| LEDs / illumination | AS3676 at I2C3-0040 | Generic LED framework; exact AS3676 support not established in current tree | Sink mapping, ALS/blink policy, supplies | Assess driver/binding or upstream gap. |
| Vibrator | Legacy platform feature | Generic regulator/GPIO/haptics frameworks | Exact actuator driver and rail | Source-map only; no inference. |
| Charger | BQ24160 at I2C3-006b | BQ2415x family driver exists; exact BQ24160 match unconfirmed | Exact compatible, IRQ, OTG and thermal policy | Verify chip support/binding before design. |
| Fuel gauge | BQ27520 at I2C3-0055 | Power-supply framework exists; exact BQ27520 support unconfirmed | Gauge variant, battery data/calibration handling | Locate supported driver or upstream gap; never copy private calibration. |
| Thermal, cpufreq, cpuidle | Legacy runtime | Generic ARM/Qcom frameworks exist | MSM8x60 policy, sensors and OPP evidence | Research current MSM8x60-specific support; 1890 MHz is not a stock OPP. |
| Wi-Fi BCM4330 | SDIO BCM4330, legacy firmware up | brcmfmac family support is a candidate | Power/reset, board NVRAM/calibration and legal firmware provenance | Map generic firmware separately; do not read calibration contents. |
| Bluetooth BCM4330 | Legacy HCD patch path | Bluetooth HCI BCM family support is a candidate | UART transport, enable GPIO, HCD provenance | Derive transport wiring from vendor source. |
| Audio, headset, mics, speaker | Legacy msm-audio/Timpani and speaker amp GPIOs | ALSA/ASoC generic; no complete MSM8x60 Fuji call-audio path established | Codec/AMP routing, ADSP voice path, jack detection | Study `board-semc_fuji-audio.c` and Timpani profiles as reference only. |
| Camera / VFE / CSIC | KMO13BS0 and STW01BM0 modules; legacy CSI probe | Generic V4L2 exists; no MSM8x60 CAMSS enablement established | Exact sensor dies, CSI/VFE support, power sequences | Treat sensor dies UNKNOWN; map module wires and find current SoC support. |
| JPEG/Gemini/VIDC | Legacy multimedia allocations | No MSM8x60-specific upstream enablement established here | Hardware generation, firmware/control ABI | Keep as research blocker. |
| Modem, SMD, rmnet, voice | Legacy PIL and modem-up logs | Generic Qualcomm IPC exists | Firmware ABI, shared memory, telephony and call audio | Inventory legacy channels/source without radio actions. |
| GNSS | Legacy integration, exact topology unknown | Generic tty/GNSS framework | Chip/path, power and protocol | Identify source evidence; currently UNKNOWN. |
| NFC | PN544 at I2C3-0028; PMIC-side helper | PN544 I2C driver exists | IRQ/enable/firmware and DT wiring | Use PN544 node; do not invent a second controller. |
| FM/RDS | Legacy radio topology observed | No Hikari-ready FM path established | BCM transport and userspace/control ABI | Determine source-backed relationship to combo chip. |
| Accelerometer | BMA250 at I2C5-0018 | Exact BMA250 current upstream driver not established in this pass | Binding/driver availability, IRQ/orientation | Check upstream driver support before porting tables. |
| Magnetometer | AKM8972 at I2C5-000c | Exact AKM8972 support not established | Variant/binding/orientation | Research driver and calibration policy. |
| Gyroscope | MPU-3050 at I2C5-0068 | IIO MPU-3050 driver and OF match exist | IRQ/orientation/aux devices | Map Hikari properties to current binding. |
| Proximity / ALS | APDS9702 at I2C3-0054 | Exact APDS9702 support not established | Driver/binding and threshold policy | Research, avoid substituting nearby APDS variants. |
| RTC / watchdog | PMIC/SoC legacy facilities | Generic Qcom/PMIC frameworks | Exact selected hardware and wake policy | Recover source mapping. |
| Suspend / resume / wake | Legacy ClearPad transitions observed | Generic frameworks only | Full wake-source and rail sequencing | Build a wake-source inventory before any target claim. |

Rows marked “not established” are intentionally `UNKNOWN`, not negative proof.
The target implementation remains `UNKNOWN`/`NOT_STARTED` in
[`status/hardware.yaml`](../status/hardware.yaml).
