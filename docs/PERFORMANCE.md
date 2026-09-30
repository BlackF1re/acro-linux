# Performance

No release-grade performance baseline exists yet. Do not tune around software
rendering or an incomplete power stack.

## Provisional Wayland baseline

On 2026-09-24 a temporary Debian Cage 0.2.0 session with Foot 1.21.0 ran on
the physical SYSTEM kernel at 720x1280. EGL identified Mesa 25.0.7 Freedreno
`FD220`; Cage held the MSM DRM master and active GEM buffers. Cage, Foot and
the shell used about 42 MiB combined RSS, while `free` reported about 535 MiB
available from the kernel-visible 628 MiB. This establishes a lightweight
comparison point, not a choice of production shell. Visual touch/libinput
acceptance and comparable measurements of adaptive environments remain open.

On 2026-09-25 the same accelerated path was repeated with exact upstream Mesa
A2xx fixes `5a3300f4a34a` and `34b78fb26b9b`.  EGL and GLES2 selected `FD220`;
an RGB capture had uniform pixels on every edge and the physical panel no
longer showed the former coloured last row/column.  This verifies the render
path and scissor correction, not Cage as the final compositor.

After accelerated graphics and suspend are functional, record reproducible
on-device measurements for boot time, idle/loaded PSS and RSS, CPU utilization,
storage throughput, network throughput, frame timing and wakeups. Compare
candidate Wayland environments on the same kernel/rootfs and thermal state.
Keep only summarized results here; raw captures belong under `research/`.
