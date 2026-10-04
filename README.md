# Xperia acro S · native Linux

[![Kernel source checks](https://github.com/BlackF1re/acro-linux/actions/workflows/hikari-kernel-audit.yml/badge.svg)](https://github.com/BlackF1re/acro-linux/actions/workflows/hikari-kernel-audit.yml)
[Build](docs/BUILD.md) · [Testing](docs/TESTING.md) · [Hardware](docs/HARDWARE.md) · [Recovery](docs/RECOVERY.md) · [Project status](docs/STATUS.md)

A native Linux port for **Sony Xperia acro S LT26w / Hikari**: modern Debian
armhf, the Linux 7.3 Hikari port, DRM/MSM, current Mesa/Freedreno and
**hardware-accelerated Phosh on Adreno 220**. No Android framework or libhybris
is used in the production graphics path.

The goal is a useful **Linux phone and pocket computer** with ordinary package
management, native applications, hardware graphics and a dependable recovery
path. The screen, touch, radios, sensors and other board functions are being
brought up as normal Linux devices through current kernel interfaces.

The port already reaches an accelerated graphical handheld environment, but it
is not yet a daily-driver phone. Reliable suspend/resume, audio, telephony,
cameras and several remaining peripheral paths still need bring-up or physical
acceptance.

> [!WARNING]
> Do not flash or replace the immutable BOOT during normal development. Test
> kernels live separately on microSD and are loaded from BOOT through kexec.
> Do not kexec from the SMP SYSTEM or live-unbind MDP4.

## At a glance

| Question | Current answer |
|---|---|
| What runs? | Linux 7.3 Hikari + Debian armhf + Phosh GLES2 |
| What is already usable? | BOOT→SYSTEM recovery path, dual-core SMP, RAM, microSD rootfs, native display, multitouch, accelerated Adreno 220, USB device/networking, powered USB OTG, charging and several sensors |
| What is only partial? | Wi-Fi, Bluetooth, RTC, thermal/power policy, several buttons and wake paths |
| What is still missing? | Reliable suspend/resume, native audio, cellular data/SMS/calls, cameras, video codecs and HDMI |
| How is it developed safely? | Immutable BOOT loads independent SYSTEM bundles from microSD; failed experiments return to the known recovery environment after a hardware reboot |
| How is the kernel source kept reproducible? | A pinned upstream base plus **17 subsystem patches**, canonical DT/config records and exact prepared-tree checks |

```text
Sony boot → immutable Linux BOOT → microSD/kexec → modern Linux SYSTEM
                                                └─ DRM/MSM → Freedreno → Phosh
```

The table above describes the **usable system**, not merely drivers that build
or probe. Detailed per-device evidence and acceptance limits are recorded below
and in the project documentation.

## Engineering highlights

### Adreno 220 on current DRM/MSM

The existing A2xx path could submit work to Adreno 220 without an obvious GPU
fault while still producing corrupted interpolated values. Historical KGSL was
used as a hardware-behaviour reference rather than as a runtime dependency.
Comparing the working historical path with DRM/MSM identified missing A220
context-shadow, MMU invalidation and submission-lifecycle semantics.

Those semantics are now implemented in native DRM/MSM while modern DRM virtual
memory, fences and userspace state remain owned by the current stack. The
result is real FD220 GLES2 rendering through current Mesa/Freedreno and a Phosh
session using hardware composition instead of a software-rendering fallback.

### Display bring-up from a previously unsupported path

Hikari's 720×1280 panel did not have a complete modern-kernel display path. The
port brings together MDP4, MSM8x60 DSI host support, a 45 nm DSI PHY path, the
Renesas R63306/TMD MDV22 panel and the required clock, fabric and memory
plumbing. It also fixes Hikari-specific command-DMA/vblank behaviour needed for
stable physical scanout.

The result is native KMS scanout with working backlight and a touch-driven
Wayland session. Resume and some handoff paths are still separate acceptance
problems and are not hidden by the fact that normal scanout works.

### CPU, clocks and shared platform infrastructure

The port brings both Scorpion cores online and reconstructs MSM8x60 clock,
reset, interconnect, PMIC and shared-L2 dependencies needed by the rest of the
machine. Native CPU/L2 DVFS and per-core SAW voltage coordination are present in
the maintained source, but the latest audited running image does not expose a
cpufreq policy, so full dual-core DVFS remains a pending physical acceptance
item rather than a claimed working feature.

This distinction is intentional: source support, a successful build and a
physical test are tracked separately throughout the project.

### Recovery-first development

The original small BOOT environment stays fixed and acts as the safety anchor.
It reads microSD-hosted SYSTEM bundles and starts a selected modern kernel using
kexec. Experimental kernels can therefore live beside a known-good system
without repeatedly rewriting the boot partition.

That arrangement turns recovery into part of the architecture rather than an
afterthought: a failed SYSTEM experiment can be abandoned with a hardware
reboot, while deployment and rollback remain independently testable.

### Reconstructible source instead of a private working tree

Kernel changes are maintained as **one repository patch per subsystem** on top
of a pinned upstream revision. The materializer checks the exact resulting
source tree, and canonical board DT/configuration records are kept in the
repository. Historical experiments and original patch exports remain under
`research/`, but they are not silently applied to production builds.

This repository layout is optimized for local reconstruction and audit. It is
not the intended shape of future upstream submissions: upstream series will be
split into smaller logical changes according to the receiving subsystem's
review rules.

## What the finished system is meant to be

The target is not merely a phone that reaches a shell or displays a desktop. It
is a small ARMv7 Linux computer that is comfortable as a handheld and can also
use ordinary Linux applications, USB keyboard/mouse and eventually an external
display. Debian supplies normal package management and application software;
Wayland/Phosh provides the current adaptive interface.

Reaching that target also means respecting the device's 1 GiB RAM and limited
power budget. Idle consumption, background services, renderer cost, wakeups and
input latency are release concerns, not post-release polish.

The next major milestones are reliable sleep/wake and CPU power management,
robust connectivity, then native audio, telephony and cameras. HDMI and media
acceleration remain part of the full-computer target as well.

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

The recovery architecture, SMP, RAM and microSD-rooted SYSTEM are physically
working. CPU power management is not yet fully accepted, and native SYSTEM use
of the internal eMMC remains deliberately unclaimed.

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

The central handheld UI path is working end to end: native display scanout,
backlight, multitouch and hardware-accelerated Phosh. Several physical buttons,
haptics, video acceleration and HDMI still need independent acceptance.

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

USB is the strongest connectivity path and works in both device/network and
powered host roles. Wi-Fi and Bluetooth have demonstrated real operation but
still have unresolved limits; the cellular stack and other radios have not yet
reached native Linux acceptance.

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

This is still an early bring-up area. Headset insertion is physically working
and accessory ADC reads exist, but native playback, capture, call routing and
camera capture are not yet claimed.

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

Motion/orientation sensors and proximity have passed direct physical tests.
Ambient-light and thermal/battery channels can produce useful readings, but
continuous modes, calibration and protection policy still need qualification.

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

Real USB charging works and native battery/power measurements are available,
but reliable system sleep is the largest remaining blocker to normal handheld
use. No automatic suspend should be enabled until repeated suspend/resume and
wake-source tests pass.

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

## Build, test and deploy

A clean source tree can be reconstructed from the pinned upstream revision and
the maintained subsystem series:

```sh
scripts/materialize-hikari-kernel.sh /path/to/new/linux-hikari
KERNEL_SRC=/path/to/new/linux-hikari scripts/build-hikari-debian-kernel.sh
python3 -m unittest discover -s tests
```

The materializer refuses to reset an existing tree. Build preparation does not
silently edit kernel source: maintained changes must be represented by the
patch series, and the resulting tree is checked against the recorded identity.

A complete SYSTEM also includes the Debian rootfs and initramfs. Packaging,
transfer to the phone and BOOT/SYSTEM switching are documented in
[BUILD.md](docs/BUILD.md). Physical acceptance procedures are in
[TESTING.md](docs/TESTING.md), and recovery constraints are in
[RECOVERY.md](docs/RECOVERY.md). Source reconstruction and deployment are kept
separate deliberately so that building a kernel never implies permission to
rewrite recovery-critical storage.

## Repository map

| Directory | Contents |
|---|---|
| `kernel/` | Pinned upstream base, 17 subsystem patches, canonical DT and kernel configs |
| `distro/`, `debian/`, `ui/` | Mesa/runtime integration, Debian system configuration and graphical session setup |
| `initramfs/` | BOOT/SYSTEM early-userspace components |
| `firmware/` | Firmware metadata/integration material subject to its original licensing |
| `scripts/`, `tools/`, `tests/` | Reproducible builds, packaging, diagnostics, transfer helpers and automated checks |
| `docs/`, `status/` | Maintained hardware facts, readiness, power, recovery, source provenance and acceptance records |
| `research/` | Raw evidence, historical experiments and superseded work; never implicit production input |

## Documentation map

Start with the document that matches what you are trying to do:

| Topic | Document |
|---|---|
| Current runnable state and known gaps | [STATUS.md](docs/STATUS.md) |
| Reconstructing, building and packaging SYSTEM/BOOT | [BUILD.md](docs/BUILD.md) |
| Physical acceptance procedures | [TESTING.md](docs/TESTING.md) |
| Hardware inventory and evidence | [HARDWARE.md](docs/HARDWARE.md) |
| Safe recovery and destructive-operation gates | [RECOVERY.md](docs/RECOVERY.md) |
| BOOT architecture | [BOOT.md](docs/BOOT.md) |
| Partition evidence | [PARTITIONS.md](docs/PARTITIONS.md) |
| Display-specific bring-up | [DISPLAY.md](docs/DISPLAY.md) |
| Power and charging | [POWER.md](docs/POWER.md) · [CHARGING.md](docs/CHARGING.md) |
| Debian/userspace integration | [DEBIAN.md](docs/DEBIAN.md) |
| Firmware handling | [FIRMWARE.md](docs/FIRMWARE.md) |
| Source provenance | [SOURCES.md](docs/SOURCES.md) |
| Upstream status and submission preparation | [UPSTREAM.md](docs/UPSTREAM.md) |
| Patch/source audit | [FUNCTIONAL-PATCH-AUDIT.md](docs/FUNCTIONAL-PATCH-AUDIT.md) · [PATCH-AUDIT.md](docs/PATCH-AUDIT.md) |

## Contributing

Hardware claims must be tied to the exact source/runtime identity and to a real
physical test. A build, probe or passing CI job is useful evidence, but it is
not a substitute for exercising the function on the phone. Failed and partial
tests are useful results and should be retained rather than rounded up to
"working".

Kernel work in this repository stays organized by owning subsystem, with
original authorship and licensing preserved. Read [CONTRIBUTING.md](CONTRIBUTING.md)
and the relevant documentation before changing hardware support.

## Project information

[License](LICENSE) · [Third-party licensing](LICENSING.md) ·
[Security](SECURITY.md) · [Contributing](CONTRIBUTING.md) ·
[Code of conduct](CODE_OF_CONDUCT.md)

Project-owned material is **GPL-2.0-or-later**, unless a file states otherwise.
Imported code and firmware retain their own licenses.

<details>
<summary>Repository history note</summary>

The history was signed and grouped into logical development checkpoints on
2026-10-05 at the owner's request. Commit IDs changed; preserve local work
before reconciling an existing clone with `main`. See the
[history audit](docs/HISTORY-SIGNING.md).

</details>
