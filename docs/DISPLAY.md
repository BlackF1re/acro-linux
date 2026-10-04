# Display and GPU

The native 720×1280 Renesas R63306/TMD MDV22 panel uses MSM8x60 DSI/MDP4
and AS3676 backlight. The port retains Sony command tables, power/reset order,
DSI clock/PHY timing and contiguous physical scanout. These are functional
hardware adaptations, not disposable diagnostics.

The A220 driver carries KGSL-derived context shadow banks, CP-ordered MMU
synchronization and context rearm. This lifecycle implementation fixed the
old stale-varying corruption and remains intact. Patches 0080–0085 reproduce
the signed source integration exactly; patch 0086 only reduces startup logs.
No GPU register write, packet, shadow allocation, wait or barrier is removed.

Phosh currently uses hardware GLES2 with the separate matching Mesa runtime
in `/opt/hikari-mesa-a220`. Mesa commit:
`7bcaafa20c99ea1dd6c7ba8105da0be4b8044871`.
All EGL/DRI/GBM library paths must refer to that runtime together.
See [STATUS.md](STATUS.md) for the live identity and [BUILD.md](BUILD.md)
for the latest source/release checkpoint.

Preserve the BOOT recovery route. Never live-unbind MDP4. Display resume and
complete workload acceptance, including terrain, are separate test domains.
