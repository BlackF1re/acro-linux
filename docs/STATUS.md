# Current status

## Current port

The production target is Linux 7.3 Hikari + DRM/MSM + current Freedreno +
Debian armhf + Phosh GLES2. Hardware and source evidence remains in
[HARDWARE.md](HARDWARE.md), [SOURCES.md](SOURCES.md) and
[status/hardware.yaml](../status/hardware.yaml).

The immutable BOOT loads SD-hosted SYSTEM bundles through kexec. Do not
flash BOOT or replace the known-good bundle during experiments.

## Verified snapshot — 2026-10-04

The connected SYSTEM reports `7.3.0-rc1-hikari-system-ga701a6f7854a-dirty`,
#1, built 2026-10-04 12:43:59 +07. Phosh is active with `WLR_RENDERER=gles2`
and matching EGL/DRI/GBM paths in `/opt/hikari-mesa-a220`.
Mesa libgallium SHA256:
`e907085656c8445aab198f14f7df5b81e4beec4be97e29447acbc6f611e5e428`.
No MMU_PAGE_FAULT/GPU-fault/GPU-lockup matches appeared in this boot's log.
The owner confirms correct GPU graphics. This is not a new full terrain test.

The latest source integration and saved release build are documented in
[BUILD.md](BUILD.md). They are not identical to the currently booted image:
no cpufreq policy is exposed by the running kernel. Source support must not
be described as physical acceptance of the latest DVFS build.

## Remaining acceptance

On 2026-10-08 five conservative CPU/RPM power-collapse cycles woke through
RTC, with working GPU Phosh, display and touchscreen. Peripheral resume
errors, other wake sources, deep-level policy and suspend current still
prevent full suspend/resume acceptance; see [POWER.md](POWER.md). CPU DVFS, thermal protection,
cradle charging and the remaining audio/radio/camera/HDMI functions retain
their individual evidence limits. Prior suspend tests had display/USB resume
regressions; do not enable automatic sleep as a cleanup action.

The maintained bring-up procedures are linked from [WORKSPACE.md](WORKSPACE.md).
Raw experiments are retained only where they provide evidence for a current
open acceptance item.
