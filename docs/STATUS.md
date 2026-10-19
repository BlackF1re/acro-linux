# Current status

> [!IMPORTANT]
> **Experimental hardware port.** A successful source build, driver probe, or isolated test is **not** a complete working phone. Status below distinguishes the **booted SYSTEM image**, **newer test bundles**, and **unverified features**.

## Runtime and source identity

| Evidence | What it establishes |
|---|---|
| **Connected SYSTEM — 2026-10-04** | `7.3.0-rc1-hikari-system-ga701a6f7854a-dirty`, hardware GLES2 Phosh on FD220 |
| **Pinned project source** | Linux **7.3-rc1 line** + maintained subsystem patch series; may differ from the booted image |
| **GPU userspace** | Tested Mesa under `/opt/hikari-mesa-a220`; not Android/libhybris |
| **Power experiments — 2026-10-08/09** | Repeated CPU/RPM collapse and RTC/power-key/screen-blank resumes on designated SYSTEM bundles |

The 2026-10-04 running kernel **exposed no cpufreq policy**, despite CPU/L2 DVFS support in maintained source. Its active Phosh used `WLR_RENDERER=gles2` with matching EGL/DRI/GBM paths and no logged GPU/MMU fault in that audited boot. Neither observation qualifies untested features.

## Acceptance overview

| Result | Evidence | Remaining work |
|---|---|---|
| ✅ BOOT → microSD SYSTEM | kexec, Debian, GPU-accelerated Phosh | Cold-boot endurance |
| ✅ Display / touch / FD220 | Real scanout, gestures and GPU rendering | Resume/handoff reliability |
| ✅ USB / charging | ACM, NCM, USB host HID, real charging | All power/role transitions |
| ◐ Wi-Fi / Bluetooth | Wi-Fi traffic and discovery tested | Later SDIO fault; BT connections untested |
| ◐ Deep sleep | Bounded 2026-10-09 RTC, power-key and screen-trigger tests | Peripheral wake, all resume paths, power consumption |
| ◐ CPU frequency / thermal | Source implementation and partial device tests | Dual-core DVFS runtime and protection acceptance |
| ○ Audio / modem / cameras / HDMI | Research or unaccepted source paths | Real playback, calls, capture or video output |

> [!WARNING]
> **Full suspend/resume is not accepted.** Later bounded wake tests passed, but Wi-Fi was disabled in some runs, wake sources remain untested and display underruns have occurred. Do not treat an experimental screen-sleep helper as production-ready power management.

## Where the evidence lives

| Question | Source |
|---|---|
| Complete component-by-component status | [Hardware](HARDWARE.md) · [machine-readable inventory](../status/hardware.yaml) |
| Most recent deep-sleep test details | [Power management](POWER.md) |
| Build and tested image separation | [Build](BUILD.md) · [Workspace](WORKSPACE.md) |
| GPU, audio and USB limits | [Display](DISPLAY.md) · [Audio](AUDIO.md) · [USB](USB.md) |

> [!CAUTION]
> Developer SSH still allows **passwordless root login**. Do not expose this configuration to untrusted networks; see [Debian](DEBIAN.md).
