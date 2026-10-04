# Xperia acro S · native Linux

[![Kernel source checks](https://github.com/BlackF1re/acro-linux/actions/workflows/hikari-kernel-audit.yml/badge.svg)](https://github.com/BlackF1re/acro-linux/actions/workflows/hikari-kernel-audit.yml)
[Build](docs/BUILD.md) · [Hardware](docs/HARDWARE.md) · [Recovery](docs/RECOVERY.md) · [Project status](docs/STATUS.md)

A native Linux port for **Sony Xperia acro S LT26w / Hikari**: modern Debian
armhf, the Linux 7.3 Hikari port, DRM/MSM, current Mesa/Freedreno and
**hardware-accelerated Phosh on Adreno 220**. No Android framework or libhybris
in the production graphics path.

The goal is a useful **Linux phone and pocket computer** with ordinary package
management, native applications, hardware graphics and a dependable recovery
path. The existing screen, touch, radios and sensors should become normal Linux
devices that applications can use through standard interfaces.

Hikari is a compact ARMv7 machine with tight memory and power budgets. Making
it comfortable to use means paying attention to idle power, background services,
rendering cost and input—not just reaching a desktop. Calls, cameras, audio and
reliable sleep are still bring-up work.

> [!IMPORTANT]
> GPU rendering is working on the modern kernel. KGSL supplied the hardware
> reference; its A220 lifecycle semantics are implemented in native DRM/MSM.
> Linux 3.4/KGSL is a research oracle, **not** the production OS.

> [!WARNING]
> Experimental port, not a fully qualified daily-driver phone. Do not flash or
> replace the immutable BOOT. Test kernels live separately on microSD and are
> loaded from BOOT through kexec. Do not kexec from the SMP SYSTEM or live-unbind MDP4.

### At a glance

| Device | Production stack | Source organisation |
|---|---|---|
| MSM8260 · dual Scorpion · Adreno 220 | Linux 7.3 + Debian armhf + Phosh GLES2 | **17 patches, one per subsystem** |
| 1 GiB RAM · 16 GB eMMC · microSD | 720×1280 DSI display · native RMI4 touch | Pinned upstream base; exact source-tree checks |

```text
Sony boot → immutable Linux BOOT → microSD/kexec → modern Linux SYSTEM
                                                └─ DRM/MSM → Freedreno → Phosh
```

## Ideas behind the port

### A recovery environment that stays put

The small BOOT kernel is the safety anchor. It reads the microSD card and
loads a selected SYSTEM kernel through kexec. Experimental kernels can live
in separate directories beside the working system. After a failed experiment,
a hardware reboot returns to BOOT without replacing the boot partition.

This makes the phone a practical development machine: its operating system
can evolve while the recovery route stays familiar and independently usable.

### Old driver knowledge, modern Linux interfaces

Adreno 220 was able to submit commands under modern Freedreno while silently
corrupting interpolated values. Tests with the historical KGSL stack established
a working hardware reference. Comparing the two paths led to transferring
A220 context, MMU and submission lifecycle behaviour into modern DRM/MSM.

The result keeps current Mesa, GBM/EGL and Phosh. Sony/Qualcomm sources remain
valuable descriptions of the hardware; their register sequences and wiring
facts can be expressed through current Linux drivers and frameworks.

### A port you can reconstruct

The kernel changes are organised as **one patch per subsystem**, applied to a
pinned upstream revision. Source-tree checks establish exactly what a build
contains, and separate hardware records describe what actually ran on the phone.
This should make upgrades, regression checks and experiments easier to follow.

### One device, several ways to use it

The longer-term aim is a touch-friendly handheld that can also run familiar
Linux tools with a keyboard, mouse and external display. Debian provides the
application ecosystem; USB OTG already supports real input devices. HDMI,
audio and the remaining phone functions still need acceptance before that
complete experience is available.

## Where the project is heading

The next milestones are reliable sleep and wake, full CPU/power-management
acceptance, robust connectivity, then native audio, telephony and cameras.
Performance work should reduce idle consumption and keep the interface
responsive within 1 GiB of RAM. Each milestone needs repeated tests on the
physical Hikari, including recovery and everyday use.

## Hardware readiness

Snapshot: **2026-10-05**, combining retained physical evidence and the latest
source audit. Status means *native modern SYSTEM support*, not Android support.
**Working** means the stated function ran on the physical phone, not that every
mode passed. **Partial** means only part is tested. **Source support** is not
hardware acceptance. **Not verified** means no accepted functional test.

> [!CAUTION]
> Sleep/resume is not reliable. Do not enable automatic suspend. Wi-Fi passed
> traffic/reconnect tests but later failed SDIO access; it is deliberately marked
> partial. Full CPU DVFS source exists, but the audited running image has no
> cpufreq policy. A probe, successful build or passing CI does not prove hardware works.

<details>
<summary><strong>Core, boot & storage</strong></summary>

| Capability | Hardware / path | Readiness | Evidence / remaining work |
|---|---|---|---|
| Boot and recovery | Immutable Linux BOOT → microSD → kexec | ✅ Working | Verified BOOT-to-SYSTEM transitions; experiments never replace BOOT. |
| CPU / SMP | MSM8260 · 2× ARMv7 Scorpion | ✅ Working | Both cores online; mainline Linux 7.3 Hikari port. |
| CPU hotplug | Scorpion CPU1 | 🟡 Partial | Offlining tested; re-onlining failed. No kexec from SMP SYSTEM. |
| CPU frequency scaling | Scorpion CPU/L2 DVFS | 🛠️ Source support | Native source compiled; earlier CPU0-only 384–756 MHz test passed. Full dual-core DVFS not accepted. |
| CPU voltage / shared L2 | Per-core SAW + L2 PLL coordination | 🛠️ Source support | Source and safety guards retained; full runtime acceptance pending. |
| Clocks, resets and rails | GCC / MMCC / RPM / PM8058 / PM8901 | 🟡 Partial | Running display/GPU/USB paths exercised; all consumers and power transitions not qualified. |
| Memory interconnect | MSM8x60 NoC / RPM votes | 🟡 Partial | Fabric providers bound; consumer and bandwidth policy acceptance incomplete. |
| RAM | 1 GiB physical; ~907 MiB usable snapshot | ✅ Working | Correct Sony memory map; 640 MiB write/read stress passed. |
| Internal storage | 16 GB eMMC · MAG2GA | ⬜ Not verified | Identified on the device; native SYSTEM read/write acceptance not established. |
| microSD storage | External card / Debian rootfs | ✅ Working | Read/write rootfs and kernel bundles; sustained I/O/removal endurance pending. |
| RTC | PM8xxx RTC | 🟡 Partial | Set/readback tested; powered-off retention and cold-boot restoration pending. |
| Watchdog | Qualcomm watchdog | 🛠️ Source support | Reboot-stop support retained; controlled expiry/recovery test pending. |
| Persistent crash logs | ramoops / legacy RAM console | 🟡 Partial | Capture path established; historical ECC and handoff compatibility require care. |

</details>

<details>
<summary><strong>Graphics, display & controls</strong></summary>

| Capability | Hardware / path | Readiness | Evidence / remaining work |
|---|---|---|---|
| 3D GPU / GLES2 | Adreno 220 · DRM/MSM + current Freedreno | ✅ Working | KGSL-derived native KMD lifecycle; repeated varying tests and hardware Phosh. Full conformance pending. |
| Desktop composition | GBM/EGL/GLES → phoc → Phosh | ✅ Working | Hardware GLES2 FD220; no Pixman in the observed running session. |
| Internal display | MDP4 + MIPI-DSI + Renesas R63306 | ✅ Working | Native 720×1280 scanout; some handoff/resume paths have underrun history. |
| LCD backlight | AS3676 | ✅ Working | Brightness callback and output tested; brightness restored after audits. |
| Touchscreen / multitouch | Synaptics ClearPad TM1964-001 / RMI4 | ✅ Working | Real taps, drags and simultaneous contacts tested; full-edge calibration pending. |
| Back button | RMI navigation strip | 🛠️ Source support | Native touch-overlay mapping; separate key/session acceptance pending. |
| Home button | RMI navigation strip | 🛠️ Source support | Native touch-overlay mapping; separate key/session acceptance pending. |
| Menu button | RMI navigation strip | 🛠️ Source support | Native touch-overlay mapping; separate key/session acceptance pending. |
| Power button | PM8xxx power key | 🟡 Partial | Input/wake wiring present; reliable suspend wake not established. |
| Volume up / down | PM8058 GPIO / TLMM keys | 🛠️ Source support | Both keys modelled independently; complete physical key acceptance pending. |
| Camera focus / shutter key | Two-stage PM8058 matrix key | 🛠️ Source support | Separate KEY_CAMERA_FOCUS and KEY_CAMERA mappings; camera integration pending. |
| Notification LED | AS3676 RGB sinks | ✅ Working | Owner visually confirmed red, green and blue; endurance pending. |
| Navigation illumination | AS3676 button backlight | ✅ Working | Owner visually confirmed the capacitive-button illumination. |
| Haptics / vibration | PM8xxx vibrator | ⬜ Not verified | Driver/configuration present; physical vibration acceptance pending. |
| Video decoding / encoding | MSM8x60 video engine | ⬜ Not verified | No native codec/media acceptance; GLES rendering is a separate capability. |
| micro-HDMI video | MSM8x60 HDMI path | ⬜ Not verified | Identified; monitor output/EDID/hotplug not accepted. |
| HDMI audio | HDMI audio routing | ⬜ Not verified | No external audio playback acceptance. |

</details>

<details>
<summary><strong>Connectivity & telephony</strong></summary>

| Capability | Hardware / path | Readiness | Evidence / remaining work |
|---|---|---|---|
| Wi-Fi station | Broadcom BCM4330 / SDIO | 🟡 Partial | Association, reconnect and traffic passed; later SDIO backplane failure observed on 2026-10-04. |
| Wi-Fi Direct / P2P | BCM4330 firmware path | 🔴 Not working | Unsupported legacy-firmware P2P creation is suppressed; not advertised as working. |
| Bluetooth discovery | BCM4330 / UART serdev / BlueZ | 🟡 Partial | Firmware download, HCI power and active discovery passed. |
| Bluetooth connections / audio | BCM4330 profiles | ⬜ Not verified | Pairing, payload transfer and audio profiles need separate physical tests. |
| USB device / networking | USB 2.0 HS · ACM + NCM | ✅ Working | Serial console and USB SSH/network transport tested; suspend/endurance pending. |
| USB OTG host | EHCI / external VBUS switch | ✅ Working | Powered enumeration and real HID input; return to device mode tested. |
| USB overcurrent protection | NCP373 / TLMM fault input | 🟡 Partial | Wiring and control implemented; fault-injection acceptance pending. |
| NFC | NXP PN544 | 🛠️ Source support | Native DT/driver path configured; tag transactions not verified. |
| FM radio | Qualcomm companion audio/FM path | ⬜ Not verified | Reception, tuning, antenna and audio routing not accepted. |
| Cellular modem / network attach | MSM8260 modem | ⬜ Not verified | Android observations are not native Linux acceptance. |
| Mobile data | Cellular packet data | ⬜ Not verified | No native network/data-session acceptance. |
| SMS | Modem messaging | ⬜ Not verified | No native send/receive acceptance. |
| Voice calls | Modem + audio routing | ⬜ Not verified | No native bidirectional call/audio acceptance. |
| SIM detection / access | GPIO switch + modem SIM path | 🛠️ Source support | Insertion switch modelled; SIM access/PIN/network integration not verified. |
| GNSS / GPS | Location subsystem; exact path unresolved | ⬜ Not verified | No native satellite/fix acceptance; exact integration remains unknown. |

</details>

<details>
<summary><strong>Cameras & audio</strong></summary>

| Capability | Hardware / path | Readiness | Evidence / remaining work |
|---|---|---|---|
| Rear camera | Sony KMO13BS0 module | ⬜ Not verified | Identified under Android; exact sensor die and native capture unresolved. |
| Front camera | Sony STW01BM0 module | ⬜ Not verified | Identified under Android; exact sensor die and native capture unresolved. |
| Autofocus | Rear camera actuator/path | ⬜ Not verified | No native focus-control acceptance. |
| Camera flash / torch | TI LM3560 | ⬜ Not verified | Identified; safe native flash/torch operation not accepted. |
| Speaker | Qualcomm Timpani audio path | ⬜ Not verified | No native playback acceptance. |
| Earpiece / call receiver | Phone audio routing | ⬜ Not verified | No native receiver playback/call acceptance. |
| Microphones / capture | Phone microphone paths | ⬜ Not verified | All physical microphone routes need capture and routing tests. |
| 3.5 mm headset audio / mic | Headset audio routing | ⬜ Not verified | Jack detection works separately; playback/capture and mic bias pending. |
| Headset insertion | TLMM61 input switch | ✅ Working | Repeated physical insert/remove events and debounce tested. |
| Headset remote buttons | PM8058 XOADC accessory input | 🟡 Partial | ADC reads; mic-bias and button classification pending. |

</details>

<details>
<summary><strong>Sensors — individually</strong></summary>

| Capability | Hardware / path | Readiness | Evidence / remaining work |
|---|---|---|---|
| Accelerometer | Bosch BMA250 | ✅ Working | Per-axis motion/orientation responses tested; full calibration pending. |
| Gyroscope | InvenSense MPU3050 | ✅ Working | Per-axis motion responses tested; full calibration/power policy pending. |
| Magnetometer / compass | AKM8972 via AK8975-compatible driver | ✅ Working | Per-axis orientation responses and raw reads tested; calibration pending. |
| Proximity | Avago APDS9702 | ✅ Working | Physical near/far transitions and IRQ delivery tested. |
| Ambient light | AS3676 photodiode ADC | 🟡 Partial | On-demand readings work; continuous mode remains disabled after display-loss correlation. |
| SoC die temperature | MSM8660 TSENS | 🟡 Partial | Plausible live temperatures; protective trips/IRQ/throttling not accepted. |
| Board temperature | PM8058 XOADC / MSM NTC | 🟡 Partial | Raw readings and thermal response observed; complete protection policy pending. |
| Battery temperature | PM8058 XOADC / pack NTC | 🟡 Partial | Native readings/mapping present; controlled temperature-policy acceptance pending. |
| Battery identification | PM8058 XOADC battery-ID channel | 🟡 Partial | Raw channel reads; battery-family/state-transition acceptance pending. |
| Charge-current monitor | PM8058 XOADC current channel | 🟡 Partial | Raw channel reads; calibrated current/state-transition acceptance pending. |

</details>

<details>
<summary><strong>Power & sleep</strong></summary>

| Capability | Hardware / path | Readiness | Evidence / remaining work |
|---|---|---|---|
| Battery voltage / current / SOC | TI BQ27520 G1 gauge | 🟡 Partial | Native readings and G1 handling; full low-to-full/SOC calibration pending. |
| USB charging | TI BQ24160 | ✅ Working | Sustained real charging and upper-charge taper observed; full-cycle endurance pending. |
| Adaptive USB current | BQ24160 input/DPM policy | 🟡 Partial | 500/800/900/1500 mA probing observed; source-dependent, not a guaranteed draw rate. |
| Cradle / dock charging | BQ24160 IN / GPIO126 | 🛠️ Source support | Separate input and adaptive policy; available cradle failed even in Android, so physical acceptance blocked. |
| Thermal protection | TSENS / battery policy / CPU cooling | 🟡 Partial | Safety checks present; protective trip/throttle acceptance incomplete. |
| CPU idle states | Scorpion / platform idle | ⬜ Not verified | No accepted low-power residency/wakeup measurement. |
| Suspend / resume | System sleep and power domains | 🔴 Not working | Previous tests lost display/USB; reliable suspend/resume not established. |
| Wake sources | Power, RTC, USB, keys, radio/input IRQs | 🟡 Partial | Several wake-capable nodes modelled; each wake source requires a successful sleep/wake test. |

</details>

This inventory includes all currently identified board functions; unidentified
parts remain in scope. Exact sensor dies, additional routes and untested modes
must be established from evidence, not guessed. The row-level inventory is
[hardware-summary.tsv](status/hardware-summary.tsv); detailed provenance and
older acceptance records are in [HARDWARE.md](docs/HARDWARE.md),
[hardware.yaml](status/hardware.yaml) and the [latest audit](docs/FUNCTIONAL-PATCH-AUDIT.md).
Newer audit limitations take precedence over older aggregate status labels.

## Build and explore

Start with [BUILD.md](docs/BUILD.md) for host dependencies, configuration,
firmware requirements and packaging. Source reconstruction is separate from deployment:

```sh
scripts/materialize-hikari-kernel.sh /path/to/new/linux-hikari
KERNEL_SRC=/path/to/new/linux-hikari scripts/build-hikari-debian-kernel.sh
python3 -m unittest discover -s tests
```

The materializer refuses to reset an existing tree. Build preparation never
edits kernel source; changes must belong to the subsystem patches. Original
patches/authorship and exact tree-equivalence records remain archived.

| Directory | Contents |
|---|---|
| `kernel/` | Upstream lock, 17 subsystem patches, DT and config |
| `distro/`, `debian/`, `ui/` | Mesa integration, Debian packaging and session setup |
| `scripts/`, `tools/`, `tests/` | Reproducible builds, diagnostics and checks |
| `docs/`, `status/` | Hardware facts, readiness, power, recovery and acceptance |
| `research/` | Evidence and archived experiments; not automatic production input |

## Project information

[License](LICENSE) · [Third-party licensing](LICENSING.md) ·
[Security](SECURITY.md) · [Contributing](CONTRIBUTING.md) ·
[Code of conduct](CODE_OF_CONDUCT.md)

Project-owned material is **GPL-2.0-or-later**, unless a file states otherwise.
Imported code and firmware retain their own licenses.

<details>
<summary>Repository history note</summary>

The complete history was re-signed on 2026-10-05 at the owner's request.
Commit IDs changed; preserve local work before reconciling an existing clone
with `main`. See the [history audit](docs/HISTORY-SIGNING.md).

</details>
