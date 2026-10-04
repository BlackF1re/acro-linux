# Hikari hardware

Sony Xperia acro S **LT26w**, codename **Hikari**, Sony **Fuji** platform.
This page brings together the identified parts, board wiring, memory layout
and physical test results. Detailed logs stay in the linked research records.

> [!IMPORTANT]
> Identifying a chip or binding its driver does not prove that its function works.
> **Working** below means the described physical test passed; it does not imply
> complete qualification. **Implemented** means source support, with acceptance pending.
> **Partial**, **Not working** and **Not verified** retain their individual limits.
> The capability snapshot is dated **2026-10-04/05**, not a live device query.

## Browse by subsystem

- [SoC and CPU](#soc-and-cpu)
- [RAM, storage and recovery](#ram-storage-and-recovery)
- [GPU, display and controls](#gpu-display-and-controls)
- [Wi-Fi, Bluetooth and phone radios](#wi-fi-bluetooth-and-phone-radios)
- [USB and HDMI](#usb-and-hdmi)
- [Cameras and audio](#cameras-and-audio)
- [Sensors](#sensors)
- [Power, charging and sleep](#power-charging-and-sleep)
- [Evidence and source records](#evidence-and-source-records)

## SoC and CPU

### Identity

| Field | Established value | Evidence |
| --- | --- | --- |
| Physical SoC | **Qualcomm MSM8260**, Snapdragon S3 / MSM8x60 family | `soc0/id = 70` + upstream `QCOM_ID_MSM8260 = 70` |
| CPU | Two ARMv7 Scorpion cores | Device and SYSTEM evidence |
| Revision | Version 2.1; `raw_id = 1057`, `raw_ver = 2` | Root-readable socinfo and sanitized dmesg |
| Legacy BSP platform | `msm8660` | Android `ro.board.platform`; not the physical SKU |
| Qualcomm build metadata | `M8660A-AABQNLYM-3.1.4003T` | `soc0/build_id`; not the physical SKU |

- **SKU confidence:** `VERIFIED_DEVICE` joined to the upstream ID table.
- Neither the BSP platform name nor the `M8660A` build prefix identifies a different chip.
- Clock/reset and power paths involve **GCC, MMCC, RPM, per-core SAW,
  PM8058 and PM8901**; memory-fabric support uses MSM8x60 interconnect/RPM votes.
- CPU/L2 DVFS source has speed-bin, PVS and boot-clock safety checks.
  The observed SYSTEM exposes no cpufreq policies; full dual-core DVFS is not accepted.

Evidence: [physical socinfo](../research/device/current/kernel/socinfo.txt),
[source provenance](SOURCES.md), [power-management details](POWER.md).

### Capability snapshot

- **CPU / SMP — Working.** MSM8260 · 2× ARMv7 Scorpion. Both cores online; mainline Linux 7.3 Hikari port.
- **CPU hotplug — Partial.** Scorpion CPU1. Offlining tested; re-onlining failed. No kexec from SMP SYSTEM.
- **CPU frequency scaling — Implemented.** Scorpion CPU/L2 DVFS. Native source compiled; earlier CPU0-only 384–756 MHz test passed. Full dual-core DVFS not accepted.
- **CPU voltage / shared L2 — Implemented.** Per-core SAW + L2 PLL coordination. Source and safety guards retained; full runtime acceptance pending.
- **Clocks, resets and rails — Partial.** GCC / MMCC / RPM / PM8058 / PM8901. Running display/GPU/USB paths exercised; all consumers and power transitions not qualified.
- **Memory interconnect — Partial.** MSM8x60 NoC / RPM votes. Fabric providers bound; consumer and bandwidth policy acceptance incomplete.
- **RTC — Partial.** PM8xxx RTC. Set/readback tested; powered-off retention and cold-boot restoration pending.
- **Watchdog — Implemented.** Qualcomm watchdog. Reboot-stop support retained; controlled expiry/recovery test pending.

## RAM, storage and recovery

### Memory map

- **Installed RAM:** 1 GiB.
- **Sony Linux RAM banks:** 939 MiB in total.
- The target DT describes the first bank from `0x40000000`, allowing upstream
  MSM8x60 to reserve the leading **2 MiB for SMEM**.
- The vendor gap below `0x48000000` and final MiB above `0x7fefffff` are preserved.
- Persistent diagnostics use a separate **128 KiB ramoops region** in the final MiB.

| Normal Linux bank | Address range |
| --- | --- |
| First | `0x40200000–0x42dfffff` |
| Second | `0x48000000–0x5fffffff` |
| Third | `0x60000000–0x7fefffff` |

<details>
<summary>Physical memory test — 2026-09-25</summary>

- 941 MiB described before reservations; 939 MiB normal RAM after SMEM.
- `MemTotal: 928996 kB` — approximately **907 MiB usable**, previously 643368 kB
  with the truncated bring-up DT.
- `HIGHMEM` exposes the upper 255 MiB.
- The **64 MiB CMA pool is reclaimable Linux RAM**, used for non-IOMMU display/GPU buffers.
- A 640 MiB anonymous allocation passed full write/read cycles with `0x55` and `0xaa`.
- No page/allocation failure, abort, Oops or panic followed; FD220 rendering still worked.
- Two repeatable underruns during fbcon → kmscube master handoff were classified
  separately as a display transition issue, not a RAM failure.

</details>

### Storage topology

These host names and IRQs come from the **legacy kernel**; modern node numbering may differ.

| Connection | Legacy host / node | Hardware details |
| --- | --- | --- |
| Internal eMMC | `msm_sdcc.1`, `mmc0:0001` | `0x12400000`, IRQ 136, 8-bit; **MAG2GA**, manufacturer ID `0x15`, manufactured 08/2012 |
| microSD | `msm_sdcc.3`, `mmc1` | `0x12180000`, IRQ 134/642; no card during the original topology sample |
| WLAN SDIO | `msm_sdcc.4`, `mmc2:0001` | `0x121c0000`, IRQ 133; BCM4330 |

- **eMMC capacity:** 16 GB; a manufacturer name is not inferred from the part string.
- **Current microSD role:** Debian rootfs and separate kernel bundles.
- **Recovery architecture:** immutable Linux BOOT → microSD → kexec → SYSTEM.
- Legacy persistent-log devices include `ram_console` and `ramdumplog`.
- BOOT and the known-good SYSTEM bundle remain separate from experimental kernels.

See [boot architecture](BOOT.md), [partition evidence](PARTITIONS.md) and [recovery](RECOVERY.md).

### Capability snapshot

- **Boot and recovery — Working.** Immutable Linux BOOT → microSD → kexec. Verified BOOT-to-SYSTEM transitions; experiments never replace BOOT.
- **RAM — Working.** 1 GiB physical; ~907 MiB usable snapshot. Correct Sony memory map; 640 MiB write/read stress passed.
- **Internal storage — Not verified.** 16 GB eMMC · MAG2GA. Identified on the device; native SYSTEM read/write acceptance not established.
- **microSD storage — Working.** External card / Debian rootfs. Read/write rootfs and kernel bundles; sustained I/O/removal endurance pending.
- **Persistent crash logs — Partial.** ramoops / legacy RAM console. Capture path established; historical ECC and handoff compatibility require care.

## GPU, display and controls

### Graphics and panel

- **GPU:** Adreno 220, exposed as **FD220** by current Mesa/Freedreno.
- **Native stack:** DRM/MSM → GBM/EGL/GLES → phoc → Phosh.
- Working A220 kernel lifecycle semantics were derived from the historical KGSL
  reference; the production path retains modern Linux and Mesa, not the KGSL ABI.
- **Display:** MDP4 → MIPI-DSI → **Renesas R63306** panel path, **720 × 1280** portrait.
- Legacy panel binding: `mipi_renesas_r63306.0`, driver `mipi_renesas_r63306`.
- Legacy graphics/media blocks include `kgsl-2d`, `kgsl-3d`, `msm_vidc`,
  `msm_vfe`, `msm_gemini`, `semc_vpe` and `msm_rotator`.
  Their presence is not native video-codec acceptance.

### Touch, keys and light outputs

| Part / function | Legacy connection | Identification |
| --- | --- | --- |
| Touchscreen | I2C `0-002c`, `clearpad-i2c` | Sony/Synaptics ClearPad **TM1964-001**, native RMI4 path |
| Back / Home / Menu | Touch navigation strip | Native touch-overlay key mappings |
| Power key | PM8xxx | Separate input/wake path |
| Volume keys | PM8058 GPIO / TLMM | Separate up/down mappings |
| Camera button | PM8058 matrix | Two stages: focus and shutter |
| Backlight / RGB / button illumination | I2C `3-0040`, `as3676` | **ams/OSRAM AS3676** |
| Vibration | PM8xxx vibrator | Physical acceptance pending |

See [display details](DISPLAY.md) and [functional patch evidence](FUNCTIONAL-PATCH-AUDIT.md).

### Capability snapshot

- **3D GPU / GLES2 — Working.** Adreno 220 · DRM/MSM + current Freedreno. KGSL-derived native KMD lifecycle; repeated varying tests and hardware Phosh. Full conformance pending.
- **Desktop composition — Working.** GBM/EGL/GLES → phoc → Phosh. Hardware GLES2 FD220; no Pixman in the observed running session.
- **Internal display — Working.** MDP4 + MIPI-DSI + Renesas R63306. Native 720×1280 scanout; some handoff/resume paths have underrun history.
- **LCD backlight — Working.** AS3676. Brightness callback and output tested; brightness restored after audits.
- **Touchscreen / multitouch — Working.** Synaptics ClearPad TM1964-001 / RMI4. Real taps, drags and simultaneous contacts tested; full-edge calibration pending.
- **Back button — Implemented.** RMI navigation strip. Native touch-overlay mapping; separate key/session acceptance pending.
- **Home button — Implemented.** RMI navigation strip. Native touch-overlay mapping; separate key/session acceptance pending.
- **Menu button — Implemented.** RMI navigation strip. Native touch-overlay mapping; separate key/session acceptance pending.
- **Power button — Partial.** PM8xxx power key. Input/wake wiring present; reliable suspend wake not established.
- **Volume up / down — Implemented.** PM8058 GPIO / TLMM keys. Both keys modelled independently; complete physical key acceptance pending.
- **Camera focus / shutter key — Implemented.** Two-stage PM8058 matrix key. Separate KEY_CAMERA_FOCUS and KEY_CAMERA mappings; camera integration pending.
- **Notification LED — Working.** AS3676 RGB sinks. Owner visually confirmed red, green and blue; endurance pending.
- **Navigation illumination — Working.** AS3676 button backlight. Owner visually confirmed the capacitive-button illumination.
- **Haptics / vibration — Not verified.** PM8xxx vibrator. Driver/configuration present; physical vibration acceptance pending.
- **Video decoding / encoding — Not verified.** MSM8x60 video engine. No native codec/media acceptance; GLES rendering is a separate capability.

## Wi-Fi, Bluetooth and phone radios

### BCM4330 combo

- **Identification:** Broadcom **BCM4330**, established from legacy names/topology
  and physical SDIO ID **`02d0:4330`**.
- **Wi-Fi:** MSM SDCC4, four-bit SDIO, up to **48 MHz**; native `brcmfmac`.
- **Bluetooth:** UART/power path; legacy `bcm_bt_lpm` and `bt_power` devices.

| Board signal / supply | Historical Sony-generation mapping |
| --- | --- |
| `WL_RST_N` | TLMM130, active low |
| `WL_HOST_WAKEUP` | TLMM128, out-of-band interrupt |
| Sleep clock | Physical PM8058 GPIO38, alternate function 2, **32.768 kHz** |
| SDCC4 rail | PM8058 S3, **1.8 V** physical rail |
| Advertised MMC OCR | **2.7–2.9 V** bits |

- **Wiring confidence:** `HISTORICAL_SOURCE`.
- The DT uses a logical fixed OCR adapter; shared S3 is not programmed until
  all consumers and RPM constraints are established.
- BCM4330 B2 firmware advertises P2P but cannot create that interface.
  The native feature mask suppresses only P2P.
- Signed `wireless-regdb` is installed; firmware exposes regulatory domain `99`.
  A verified Sony country map / CLM dataset remains unavailable.

<details>
<summary>Wi-Fi test history and current limitation</summary>

- **2026-09-16:** active scans, authorized association, DHCP/default route, DNS
  and bidirectional traffic passed. Stopping the supplicant and removing the
  address still allowed reassociation, DHCP and traffic.
- **2026-09-24:** sustained receive exposed Qualcomm MMCI PIO FIFO-window
  errors (`MCI_STARTBITERR` / `-ECOMM`). An initial eight-address change still
  failed after 6493 seconds because it restarted the offset for each burst.
- The corrected implementation advances through the complete cyclic FIFO
  window for one PIO service, matching Sony's downstream SDCC driver.
- **2026-09-25:** ten reconnects, approximately 355 MiB HTTPS receive, then
  three more reconnects with traffic passed without MMCI, SDIO-header or backplane errors.
- NetworkManager supplies a stable per-installation MAC rather than accepting
  brcmfmac's random fallback.
- **2026-10-04:** a later SDIO backplane failure was observed. Current status
  remains **Partial**, despite the earlier successful traffic tests.
- Regulatory completeness, power measurements, suspend/resume and repeated
  long-idle reconnect acceptance remain open.

Record: [sanitized Wi-Fi bring-up](../research/device/current/boot/internal-wifi-bringup-2026-09-16.md).

</details>

### Modem, GNSS, NFC and FM

- **NFC controller:** NXP **PN544**, I2C `3-0028`, legacy `pn544` and `/dev/pn544`.
  `pm8xxx-nfc` is PM8058 power/interrupt integration, **not a second NFC controller**.
- **FM:** legacy Qualcomm FM Radio Transceiver driver and `/sys/class/misc/msm_fm`
  registered; native reception/tuning/audio acceptance is pending.
- **GNSS:** exact receiver/transport remains **UNKNOWN**. Sensor/DSP SMD nodes
  do not establish a GNSS receiver or a successful position fix.
- **Modem:** legacy PIL modem and SMD endpoints, `rmnet0`–`rmnet7`, `rmnet_mux_ctrl`.
- **Remote processors:** separate QDSP6/DSPS PIL nodes; legacy platform devices
  include `pil_modem`, `pil_qdsp6v3`, `pil_dsps`, `pil_tzapps`, `msm_smd`,
  APR audio/voice and DATA/DIAG/IPCROUTER SMD endpoints.
- Legacy dmesg records reset release and “Modem Is Up”; this is not native
  attach/data/SMS/call acceptance.
- Remote storage opens logical `modem_fs1`, `modem_fs2`, `modem_fsg` names;
  those names are not mapped here to raw partitions.
- Observed legacy nodes: `/dev/smd*`, `/dev/smd_sns_dsps`, `/dev/smd_sns_adsp`,
  `/dev/smd_cxm_qmi`, `/dev/ttyHS0`, `/dev/ttyHSL0`.
  The original topology survey issued no radio, GNSS, FM or NFC commands.

### Capability snapshot

- **Wi-Fi station — Partial.** Broadcom BCM4330 / SDIO. Association, reconnect and traffic passed; later SDIO backplane failure observed on 2026-10-04.
- **Wi-Fi Direct / P2P — Not working.** BCM4330 firmware path. Unsupported legacy-firmware P2P creation is suppressed; not advertised as working.
- **Bluetooth discovery — Partial.** BCM4330 / UART serdev / BlueZ. Firmware download, HCI power and active discovery passed.
- **Bluetooth connections / audio — Not verified.** BCM4330 profiles. Pairing, payload transfer and audio profiles need separate physical tests.
- **NFC — Implemented.** NXP PN544. Native DT/driver path configured; tag transactions not verified.
- **FM radio — Not verified.** Qualcomm companion audio/FM path. Reception, tuning, antenna and audio routing not accepted.
- **Cellular modem / network attach — Not verified.** MSM8260 modem. Android observations are not native Linux acceptance.
- **Mobile data — Not verified.** Cellular packet data. No native network/data-session acceptance.
- **SMS — Not verified.** Modem messaging. No native send/receive acceptance.
- **Voice calls — Not verified.** Modem + audio routing. No native bidirectional call/audio acceptance.
- **SIM detection / access — Implemented.** GPIO switch + modem SIM path. Insertion switch modelled; SIM access/PIN/network integration not verified.
- **GNSS / GPS — Not verified.** Location subsystem; exact path unresolved. No native satellite/fix acceptance; exact integration remains unknown.

## USB and HDMI

### Connector and OTG wiring

- **USB:** integrated MSM8x60 USB 2.0 High-Speed OTG/host path.
- Legacy devices: `msm_otg`, `msm_hsusb`, `msm_hsusb_host`; exact PHY die unknown.
- **HDMI:** MSM8x60 HDMI block, legacy `hdmi_msm.*`; external PHY/controller unknown.

Sony board-source indices are **zero-based**. Mainline PM8xxx consumer
specifiers use **physical one-based** GPIO/MPP numbers; controller
`gpio-ranges` stay zero-based.

| Signal | Sony source index | Physical/mainline connection |
| --- | --- | --- |
| USB ID | PM8058 GPIO index 30 | **GPIO31**, 1.5 kΩ S3 pull-up |
| VBUS detect | PM8058 MPP index 10 | **MPP11** |
| External 5 V enable | PM8901 MPP index 0 | **MPP1** |
| Protected VBUS switch enable | TLMM28 | **NCP373** enable |
| Overcurrent fault | TLMM104 | Active low |

- **PM8901:** second SSBI controller at `0x00c00000`, active-low IRQ TLMM91, four MPPs.
- **MPP register base:** PM8901 **`0x27`**, PM8058 **`0x50`**.
- Wiring is `HISTORICAL_SOURCE`; register-base interpretation is
  `VERIFIED_VENDOR_SOURCE`, with physical readback and powered-device tests.

<details>
<summary>OTG mapping and physical acceptance history</summary>

- Build **0073:** USB-ID encoded as 29 incorrectly selected host mode with an
  ordinary notebook cable. Rechecking Sony's numbering established GPIO31/MPP11.
- Build **0077:** PM8901 MPP1 read back `0x30`; the old generic driver had written
  through the wrong register base. Historical patch **0071** introduced the
  compatible-specific base (now covered by the consolidated PMIC patch).
- Build **0079:** target Linux enabled source power, enumerated a real
  Mercusys/Realtek **`2c4e:0102`** adapter at EHCI High-Speed, removed the host
  cleanly and returned to device role. Current DT statically checks GPIO31,
  MPP11 and PM8901 MPP1.
- Under the Sony-derived Android kernel, PM8901 MPP1 (`ext_5v_en`, legacy GPIO225)
  and TLMM28 (`ncp373_en`) rose together; active-low TLMM104 returned high.
  Three real devices enumerated, including a Kingston DataTraveler and a
  keyboard/mouse receiver. This corroborates wiring, not target-Linux acceptance.

</details>

See [USB details](USB.md).

### Capability snapshot

- **micro-HDMI video — Not verified.** MSM8x60 HDMI path. Identified; monitor output/EDID/hotplug not accepted.
- **HDMI audio — Not verified.** HDMI audio routing. No external audio playback acceptance.
- **USB device / networking — Working.** USB 2.0 HS · ACM + NCM. Serial console and USB SSH/network transport tested; suspend/endurance pending.
- **USB OTG host — Working.** EHCI / external VBUS switch. Powered enumeration and real HID input; return to device mode tested.
- **USB overcurrent protection — Partial.** NCP373 / TLMM fault input. Wiring and control implemented; fault-injection acceptance pending.

## Cameras and audio

### Identified media parts

| Function | Legacy bus / driver | Identified part and limits |
| --- | --- | --- |
| Rear camera | I2C `1-001a`, `sony_sensor_main` | Sony module **KMO13BS0**; exact sensor die **UNKNOWN** |
| Front camera | I2C `1-0048`, `sony_sensor_sub` | Sony module **STW01BM0**; exact sensor die **UNKNOWN** |
| Flash | I2C `3-0053`, `lm3560` | TI **LM3560** |
| Audio/FM companion | I2C `4-000d`, `marimba-core`, `timpani_codec` | Qualcomm **Timpani** legacy path; physical die part number not directly established |
| Legacy dummy aliases | I2C `4-0066`, `4-0077`, `8-0055`, driver `dummy` | Physical purpose **UNKNOWN** |
| Headset insertion | TLMM61, `gpio-keys` | High when inserted; `SW_HEADPHONE_INSERT` |

- **Camera evidence:** module identification `VERIFIED_DEVICE`; sensor-die IDs unknown.
- Legacy `video0/video1` map to the rear module, `video2/video3` to the front,
  and `video100` to `msm_cam_server`.
- Both modules have legacy probe/CSI configuration evidence; the original
  survey started no capture. Module IDs must not be treated as sensor-die IDs.
- Camera platform path includes `msm_cam_server` and two `msm_csic` instances.
- Audio topology includes `soc-audio`, MSM codec/CPU DAIs, DSP/MVS/MI2S,
  `snddev_icodec` routes, `snddev_hdmi`, `msm_mvs_audio` and `apr_voice_svc`.
  This does not identify every analogue amplifier or prove playback/capture.
- Repeated headset insert/remove tests generated edge IRQs and the standard
  input switch after Sony's **1500 ms debounce**.
- Headset buttons/accessory classification use a separate XOADC route;
  working insertion does not establish headset audio or microphone bias.

### Capability snapshot

- **Rear camera — Not verified.** Sony KMO13BS0 module. Identified under Android; exact sensor die and native capture unresolved.
- **Front camera — Not verified.** Sony STW01BM0 module. Identified under Android; exact sensor die and native capture unresolved.
- **Autofocus — Not verified.** Rear camera actuator/path. No native focus-control acceptance.
- **Camera flash / torch — Not verified.** TI LM3560. Identified; safe native flash/torch operation not accepted.
- **Speaker — Not verified.** Qualcomm Timpani audio path. No native playback acceptance.
- **Earpiece / call receiver — Not verified.** Phone audio routing. No native receiver playback/call acceptance.
- **Microphones / capture — Not verified.** Phone microphone paths. All physical microphone routes need capture and routing tests.
- **3.5 mm headset audio / mic — Not verified.** Headset audio routing. Jack detection works separately; playback/capture and mic bias pending.
- **Headset insertion — Working.** TLMM61 input switch. Repeated physical insert/remove events and debounce tested.
- **Headset remote buttons — Partial.** PM8058 XOADC accessory input. ADC reads; mic-bias and button classification pending.

## Sensors

### Motion, proximity and ambient light

| Sensor | Legacy bus / driver | Hardware identification |
| --- | --- | --- |
| Accelerometer | I2C `5-0018`, `bma250` | Bosch **BMA250** |
| Gyroscope | I2C `5-0068`, `mpu3050` | InvenSense **MPU-3050** |
| Magnetometer | I2C `5-000c`, `akm8972` | AKM **AKM8972**; native AK8975-compatible path |
| Proximity/light-labelled legacy node | I2C `3-0054`, `apds9702` | Avago **APDS-9702**; physical near/far acceptance |
| Native ambient-light readout | AS3676 photodiode ADC | On-demand sampling; continuous mode disabled after display-loss correlation |
| SoC die temperature | MSM8660 TSENS | Thermal measurement/protection path |

These I2C identifications are `VERIFIED_DEVICE`. Legacy node labels do not
prove that every advertised sensing function has been accepted.

### PM8058 analogue inputs

Sony Fuji board code maps five inputs to XOADC channels **5–9**, powered by
**PM8058 L18 at 2.2 V**. Wiring is `VERIFIED_VENDOR_SOURCE`, joined to physical ADC reads.

| XOADC channel | PM8058 MPP | Input |
| --- | --- | --- |
| 5 | MPP3 | Headset accessory / button ADC |
| 6 | MPP7 | Battery thermistor |
| 7 | MPP10 | MSM / board thermistor |
| 8 | MPP8 | Battery identification |
| 9 | MPP5 | Charger-current monitor |

- **2026-09-24:** all five channels were readable with their MPPs owned by XOADC.
- The MSM NTC moved monotonically in the expected direction during CPU heating.
- Native `msm-board-thermal` uses Sony's conversion table through standard thermal/IIO.
- Headset classification, battery-ID transitions and calibrated current/state
  transitions still require separate acceptance tests.

### Capability snapshot

- **Accelerometer — Working.** Bosch BMA250. Per-axis motion/orientation responses tested; full calibration pending.
- **Gyroscope — Working.** InvenSense MPU3050. Per-axis motion responses tested; full calibration/power policy pending.
- **Magnetometer / compass — Working.** AKM8972 via AK8975-compatible driver. Per-axis orientation responses and raw reads tested; calibration pending.
- **Proximity — Working.** Avago APDS9702. Physical near/far transitions and IRQ delivery tested.
- **Ambient light — Partial.** AS3676 photodiode ADC. On-demand readings work; continuous mode remains disabled after display-loss correlation.
- **SoC die temperature — Partial.** MSM8660 TSENS. Plausible live temperatures; protective trips/IRQ/throttling not accepted.
- **Board temperature — Partial.** PM8058 XOADC / MSM NTC. Raw readings and thermal response observed; complete protection policy pending.
- **Battery temperature — Partial.** PM8058 XOADC / pack NTC. Native readings/mapping present; controlled temperature-policy acceptance pending.
- **Battery identification — Partial.** PM8058 XOADC battery-ID channel. Raw channel reads; battery-family/state-transition acceptance pending.
- **Charge-current monitor — Partial.** PM8058 XOADC current channel. Raw channel reads; calibrated current/state-transition acceptance pending.

## Power, charging and sleep

### Power hardware

| Part | Legacy connection | Established identity |
| --- | --- | --- |
| Main PMIC | SSBI `msm_ssbi.0`, `pm8058-core` | Qualcomm **PM8058 rev E3** |
| Companion PMIC | SSBI `msm_ssbi.1`, `pm8901-core` | Qualcomm **PM8901 rev 2.1** |
| Fuel gauge | I2C `3-0055`, `bq27520` | TI **BQ27520**, reported firmware **5.7** |
| Charger | I2C `3-006b`, `bq24160` | TI **BQ24160**, reported revision **`0x05`** |

- PM8058 exposes keypad, LED, OTHC headset instances, PWM, XOADC, battery alarm,
  GPIO/MPP, NFC support, power key, thermal monitor, USB power, vibrator,
  microphone bias and RTC subdevices.
- PM8901 exposes regulators, MPP and thermal/misc subdevices.
- Legacy power devices also include `msm_rpm`, `rpm-regulator`, `saw-regulator`
  and `chargalg`.
- USB and cradle use separate BQ24160 input paths. Adaptive-current observations
  are source-dependent; they do not guarantee a fixed charging rate.
- Cradle wiring/control is implemented, but the available cradle also failed
  under Android, preventing a powered physical acceptance test.
- Reliable suspend/resume is **not established**; prior tests lost USB/display.
  Only s2idle is advertised in the recorded snapshot.

See [charging and fuel-gauge policy](CHARGING.md) and [power management](POWER.md).

### Capability snapshot

- **Battery voltage / current / SOC — Partial.** TI BQ27520 G1 gauge. Native readings and G1 handling; full low-to-full/SOC calibration pending.
- **USB charging — Working.** TI BQ24160. Sustained real charging and upper-charge taper observed; full-cycle endurance pending.
- **Adaptive USB current — Partial.** BQ24160 input/DPM policy. 500/800/900/1500 mA probing observed; source-dependent, not a guaranteed draw rate.
- **Cradle / dock charging — Implemented.** BQ24160 IN / GPIO126. Separate input and adaptive policy; available cradle failed even in Android, so physical acceptance blocked.
- **Thermal protection — Partial.** TSENS / battery policy / CPU cooling. Safety checks present; protective trip/throttle acceptance incomplete.
- **CPU idle states — Not verified.** Scorpion / platform idle. No accepted low-power residency/wakeup measurement.
- **Suspend / resume — Not working.** System sleep and power domains. Previous tests lost display/USB; reliable suspend/resume not established.
- **Wake sources — Partial.** Power, RTC, USB, keys, radio/input IRQs. Several wake-capable nodes modelled; each wake source requires a successful sleep/wake test.

## Evidence and source records

- **Physical inventory:** [full legacy bus matrix](../research/device/current/topology/bus-matrix.md),
  [raw topology snapshot](../research/device/current/kernel/bus-topology-raw.txt),
  [SoC identity](../research/device/current/kernel/socinfo.txt).
- **Authority and source revisions:** [SOURCES.md](SOURCES.md).
- **Implementation and acceptance:** [STATUS.md](STATUS.md),
  [machine-readable hardware state](../status/hardware.yaml),
  [73-capability summary](../status/hardware-summary.tsv),
  [functional patch audit](FUNCTIONAL-PATCH-AUDIT.md).
- **Complete project scope:** [HARDWARE_SCOPE.md](HARDWARE_SCOPE.md).

Evidence vocabulary: `VERIFIED_DEVICE`, `VERIFIED_VENDOR_SOURCE`,
`VERIFIED_UPSTREAM`, `HISTORICAL_SOURCE`, `HYPOTHESIS`, `UNKNOWN`.
The linked records retain dates, source commits and raw observations; no
new hardware acceptance is claimed by this documentation reorganisation.
