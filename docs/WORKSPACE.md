# Project source and workspace map

## What is the source of the system?

The production kernel is **upstream Linux plus the patch series in this
repository**. Its base and patch order are recorded in
[`../kernel/source.lock`](../kernel/source.lock) and
[`../kernel/patches/series`](../kernel/patches/series); build instructions are
in [BUILD.md](BUILD.md). OpenSEMC is a historical Sony/Fuji hardware
reference, not the base tree for the modern system. Its board files helped
identify wiring and old KGSL behaviour; the current system uses DRM/MSM and
current Mesa/Freedreno.

Mesa is a separate userspace project. The device's tested Mesa runtime is
staged under `/opt/hikari-mesa-a220`; Mesa source/build trees are not required
to rebuild the kernel. Any maintained Mesa packaging or patch inputs live in
`distro/mesa/`.

## Keep these working references

| Path | Purpose |
| --- | --- |
| `repo/` | Canonical project source, kernel patches, scripts, hardware status and concise bring-up docs. |
| `src/linux-hikari-resume-clean-20261008/` | Source of the physically tested sleep-final kernel; tree matches `kernel/source.lock`. |
| `src/linux/` | BOOT-era integrated Hikari kernel reference; preserve its local edits. |
| `src/opensemc-msm8x60/` | Single clean OpenSEMC/Fuji reference checkout, commit `c4784b04c08d30f799b8b14b597aeb2124d2e6e1`. Not used to build production Linux. |
| `src/reference/android_kernel_sony_msm8660/` | Sony/LineageOS kernel reference for RAM, thermal and CPU-clock facts cited in `docs/SOURCES.md`. |
| `src/reference/android_device_sony_hikari/` | Sony device-tree/firmware-manifest reference cited in `docs/SOURCES.md`. |
| `src/sony-hikari-6.2.B.1.96/` | Official Sony release import used to verify Hikari board and power semantics. |
| `src/busybox/`, `src/kexec-tools-2.0.29/` | Small host-side source dependencies used by the boot/initramfs build tools. |
| `build/hikari-debian-current/` | Verified immutable BOOT loader ELF and its checksum. |
| `build/hikari-sleep-final-20261009/` | Current tested SYSTEM kernel, DTB, initramfs, modules, checksums and acceptance logs. |
| `backups/hikari/` | Verified device backup material. Keep private and do not publish. |
| `private/hikari-stock-system/` | Private device-specific calibration/firmware inputs. Never publish. |

Obsolete kernel experiment trees and reproducible build outputs have been
removed. The remaining build directory contains only the loader and current
tested SYSTEM bundle. Build scripts recreate their output directories as
needed. Source snapshots from cleanup are in
`backups/git/workspace-cleanup-20261009/`; the host SSH key and pre-update
device SYSTEM archive are private backups under
`backups/hikari/build-cleanup-20261009/`.

The device's working `/opt/hikari-mesa-a220` runtime and repository Mesa
packaging inputs remain because the running GPU stack uses them. Keep Sony
and OpenSEMC checkouts as hardware references.

## How to reproduce the successful device paths

- Safe boot and rollback: [BOOT.md](BOOT.md), [RECOVERY.md](RECOVERY.md).
- Kernel source materialization and build: [BUILD.md](BUILD.md).
- Working A220 DRM/MSM lifecycle and Mesa runtime: [DISPLAY.md](DISPLAY.md).
- Physical acceptance procedures: [TESTING.md](TESTING.md).
- Device identity, board wiring and current capability evidence:
  [HARDWARE.md](HARDWARE.md), [SOURCES.md](SOURCES.md),
  [`../status/hardware.yaml`](../status/hardware.yaml).
- Power and charge bring-up: [POWER.md](POWER.md), [CHARGING.md](CHARGING.md).
- USB device/host paths: [USB.md](USB.md).

Research files should remain only when they contain unique evidence needed to
reproduce a working hardware path or explain a current limitation. Raw frames,
temporary binaries, abandoned candidates, duplicate logs and chronological
trial notes belong outside the maintained documentation and may be removed.
