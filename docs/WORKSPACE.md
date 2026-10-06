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
| `src/linux-hikari-current/` | Clean materialized kernel source used by the current build workflow. |
| `src/linux/` | Existing integrated Hikari kernel worktree; preserve local edits and do not reset it during cleanup. |
| `src/opensemc-msm8x60/` | Single clean OpenSEMC/Fuji reference checkout, commit `c4784b04c08d30f799b8b14b597aeb2124d2e6e1`. Not used to build production Linux. |
| `src/reference/android_kernel_sony_msm8660/` | Sony/LineageOS kernel reference for RAM, thermal and CPU-clock facts cited in `docs/SOURCES.md`. |
| `src/reference/android_device_sony_hikari/` | Sony device-tree/firmware-manifest reference cited in `docs/SOURCES.md`. |
| `src/busybox/`, `src/kexec-tools-2.0.29/` | Small host-side source dependencies used by the boot/initramfs build tools. |
| `build/linux-hikari-current/` | Current kernel build objects. |
| `build/hikari-rootfs-current/`, `build/hikari-root-initramfs-current/` | Current Debian rootfs and initramfs build inputs. |
| `build/hikari-debian-current/` | Known system loader/update artifacts and recovery copies. Keep hashes and manifests. |
| `build/hikari-system-release-20261004/hikari-release/` | Older self-contained release backup; its reproducible Kbuild object tree has been removed. |
| `backups/hikari/` | Verified device backup material. Keep private and do not publish. |
| `private/hikari-stock-system/` | Private device-specific calibration/firmware inputs. Never publish. |

The historical Mesa checkout and dated Mesa/A220 candidate builds have been
removed from their source/build locations. The unreferenced KangXperia kernel
clone, dated power-test bundle and its 2.3 GiB object tree, old release object
tree, and loose audit logs were also removed from the active workspace. The
old self-contained release bundle and the current system/rootfs artifacts are
retained. The device's working `/opt/hikari-mesa-a220` runtime and repository
Mesa packaging inputs remain because the running GPU stack uses them. Keep one
OpenSEMC checkout as the legacy reference.

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
