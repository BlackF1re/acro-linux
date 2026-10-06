# Display and GPU

The native 720×1280 Renesas R63306/TMD MDV22 panel uses MSM8x60 DSI/MDP4
and AS3676 backlight. The port retains Sony command tables, power/reset order,
DSI clock/PHY timing and contiguous physical scanout. These are functional
hardware adaptations, not disposable diagnostics.

The physical first-light/scanout procedure and acceptance evidence are in
[`display-physical-scanout-success.md`](../research/device/current/boot/display-physical-scanout-success.md).
It records the wrong IOMMU address/underrun, the CMA-backed scanout fix, the
missing-VM cleanup fault, and the final 720×1280/60 Hz device checks.

The A220 driver carries KGSL-derived context shadow banks, CP-ordered MMU
synchronization and context rearm. This lifecycle implementation fixed the
old stale-varying corruption and remains intact in
[`0015-hikari-gpu.patch`](../kernel/patches/0015-hikari-gpu.patch). Canonical
Hikari board data is maintained in
[`0017-hikari-board.patch`](../kernel/patches/0017-hikari-board.patch). No GPU
register write, packet, shadow allocation, wait or barrier was removed during
the source cleanup.

The historical OpenSEMC KGSL stack is retained as a source reference and
hardware oracle only. On that legacy path, the June-2013 fd2 userspace reached
Adreno 220 through `/dev/kgsl-3d0`, while buffer allocation used the KGSL DRM
GEM node. Its GEM bridge needed an explicit MMU map when an allocated buffer
had no GPU virtual address. The physical control used OpenSEMC commit
`c4784b04c08d30f799b8b14b597aeb2124d2e6e1`, June-2013 Mesa
`e9edbf0a688c68ef0896e5d4278f411f6b6f8398` and matching libdrm
`3586337f3703ce4833a375f66b08df064a1cec28`. It passed S0 4/4 EXACT and three
independent S1c×24→S1×32 runs at 56/56 NEAR, with zero SEVERE frames. The
modern DRM/MSM port then reproduced the required A220 context/MMU/submit
lifecycle in its own kernel API. Production does not use KGSL, Android
userspace or historical Mesa.

Phosh currently uses hardware GLES2 with the separate matching Mesa runtime
in `/opt/hikari-mesa-a220`. Mesa commit:
`7bcaafa20c99ea1dd6c7ba8105da0be4b8044871`.
All EGL/DRI/GBM library paths must refer to that runtime together.
See [STATUS.md](STATUS.md) for the live identity and [BUILD.md](BUILD.md)
for the latest source/release checkpoint.

Preserve the BOOT recovery route. Never live-unbind MDP4. Display resume and
complete workload acceptance, including terrain, are separate test domains.
