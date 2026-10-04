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

Suspend/resume and cpuidle remain unverified. CPU DVFS, thermal protection,
cradle charging and the remaining audio/radio/camera/HDMI functions retain
their individual evidence limits. Prior suspend tests had display/USB resume
regressions; do not enable automatic sleep as a cleanup action.

Historical operational snapshots are under
`research/archive/operational-docs-20261004/`; hardware research is retained.
