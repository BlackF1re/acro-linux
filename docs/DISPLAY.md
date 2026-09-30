# Display

The 720×1280 Renesas R63306/TMD MDV22 panel, MSM8x60 DSI/MDP4 path,
AS3676 boost/backlight and framebuffer console are `VERIFIED_DEVICE`.

The implementation uses the exact Sony command tables and power/reset order,
MSM8x60-specific DSI clock/PHY timing, host-before-panel preparation and
contiguous physical scanout while the legacy IOMMU path remains unsuitable.
Pure bring-up banners and successful-sequence `dev_info` messages have been
removed; errors and readback mismatches remain visible.

The SYSTEM userspace uses Mesa Freedreno for the Adreno 220.  Debian Mesa
25.0.7 needs the upstream A2xx shader fix `5a3300f4a34a` and window-scissor fix
`34b78fb26b9b`; both are carried as exact backports.  On 2026-09-25 a physical
accelerated Cage/Foot frame used renderer `FD220`, a captured 720×1280 RGB
frame had identical pixels along all four edges, and the owner confirmed that
the former coloured top/right edge was absent.  Cage and the root shell were
temporary acceptance tools, not the production session design.

The local Debian rebuild is installed as one version-coherent five-package
Mesa set (`mesa-libgallium`, EGL, GBM, DRI and GLX).  This preserves Debian's
exact intra-Mesa dependencies; the canonical rootfs passes `apt-get check` and
an on-device `eglinfo` run still selects hardware renderer `FD220`.

Display suspend/resume, brightness policy and selection of a normal
unprivileged Wayland session remain separate acceptance domains.
