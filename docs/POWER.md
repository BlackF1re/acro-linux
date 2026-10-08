# Power management

## Current implementation

The native charging/gauge policy is described in [CHARGING.md](CHARGING.md).
The source integration includes Scorpion CPU DVFS, shared L2 coordination,
RPM/interconnect votes and per-core SAW regulators (patches 0082/0083).
It validates speed-bin/PVS and boot clock state before taking ownership.
These safety guards must remain even when verbose register dumps are silenced.

The latest resolved build configuration enables the CPU and SAW drivers.
The connected SYSTEM at the 2026-10-04 cleanup audit exposes no cpufreq
policies. Do not claim full DVFS validation of that running image.

MSM8660 TSENS and the PM8058 board NTC use standard thermal/IIO consumers.
Their source and measurement evidence remains in [SOURCES.md](SOURCES.md)
and the hardware inventory. Protective trips/throttling need acceptance.

## Sleep and recovery

The `hikari-suspend-final` development branch now prepares the conservative
MSM8660 RPMRS sleep set before `PM_SUSPEND_MEM` collapse and uses SAW's
RPM-notified power-collapse mode. An aborted collapse restores a conservative
untimed sleep set; a completed collapse relies on RPM returning to its ACTIVE
context on wake. CPU idle remains on the standalone SAW path. This code has
not passed physical suspend/resume acceptance.

The currently running production image advertises only s2idle. Prior
platform/suspend tests caused Wi-Fi/USB and display underrun regressions.
Reliable suspend/resume is not established; do not enable automatic suspend
without a new acceptance test. A 2026-10-08 boot test found that the MSM8660
cpuidle callback nested context tracking already provided by cpuidle core;
using `CPU_PM_CPU_IDLE_ENTER_PARAM_RCU()` removed the physical `ct_kernel_exit`
warning while both WFI and SPC counters advanced. This validates idle entry,
not suspend/resume. MPM wake routing is implemented with partial device checks;
deep RPMRS sleep-level policy remains unimplemented. The current
`sleep.target`/`suspend.target` unit state alone is not proof of a mask or of
working resume.

Retain watchdog, pstore/ramoops and error logging. BOOT remains immutable;
experimental SYSTEM kernels reside in separate microSD directories. Prior
suspend attempts are summarized here; no experimental suspend hook is enabled
in production.

The 2026-10-08 IRQ-diagnostic SYSTEM boot reached Phosh with `cpuidle.off=1`.
Its temporary source change added `-dirty` to the kernel release; modules
installed for the release without that suffix did not autoload, leaving the
Synaptics touchscreen absent. Building and installing modules for the exact
running release restored RMI4 probing and the `Synaptics TM1964-001` input
device without reboot. Touch interaction still requires physical acceptance.
This boot does not establish that the intermittent black-screen failure or
suspend/resume is fixed.

## MSM8660 MPM port

The next source stage adapts the maintained Qualcomm MPM irqchip to MSM8660's
legacy protocol. Sony 6.2.B.1.96, commit
`ae953d9a9f149db0c3a51e2b587074d0d911b7ea`, provides the mapping and protocol in
`arch/arm/mach-msm/devices-msm8x60.c` and `mpm.c` (`VERIFIED_VENDOR_SOURCE`):

- 64 pins, with separate RPM request (`0x1049d8`) and status (`0x104df8`)
  windows; no later-generation MPM timer words;
- ENABLE, edge/level DETECT, POLARITY and write-one CLEAR banks;
- APSS IPC at `0x2082008`, bit 1; RPM resource transactions use bit 2;
- GPIO wake mapping through the existing TLMM hierarchical IRQ support;
- separate buffered wake masks, noirq arm/disarm and pending-status snapshot;
- rollback of the runtime request buffer after disarm.

This is `IMPLEMENTING`, not hardware-verified support. The shared DT node
remains disabled. A separate stage adds wake-status replay and connects MPM
to RPMRS only when PXO is OFF or VDD_DIG is at RET_HIGH/RET_LOW, matching Sony's
`msm_rpmrs_use_mpm()`. The current conservative profile does neither and keeps
its existing path. A requested deeper profile fails and rolls back if MPM
is unavailable or rejects its wake configuration.

On exit, the driver snapshots pending pins before disarming and clearing MPM.
Edge events already observed by Linux are not replayed twice. Mapped GIC
edges use its pending-state interface. GPIO edges use the still-armed generic
IRQ flow to mark the event suspended/pending; device handlers are deferred to
normal IRQ resume and software resend. Writing TLMM INTR_STATUS cannot inject
such an event because that register is write-one-to-clear. Level interrupts
remain hardware-driven, as in Sony's implementation. MPM is disarmed before
RPMRS abort rollback, including when that rollback fails.

On 2026-10-08, a separate microSD candidate enabled MPM and TLMM's
`wakeup-parent` (`VERIFIED_DEVICE`, partial acceptance). It booted to hardware
Phosh without IRQ errors. A disposable module verified GPIO88 -> MPM5
(PM8058) and GPIO127 -> MPM57 (touch), then completed five noirq arm/disarm
cycles. The requested wake masks reached message RAM, duplicate entry returned
`-EBUSY`, and the original runtime enable masks were restored. This did not
exercise CPU collapse or pending-event replay.

CPU1 offlining succeeded, but subsequent onlining failed, including with a
holding-pen-only candidate. Sony's holding pen is required to avoid consuming
stale `secondary_data`; additionally, modern ARM `ipi_teardown()` masks the
wake SGI that this platform relies on. The combined holding-pen/wake-IPI
candidate subsequently passed one initial cycle and twenty consecutive
CPU1 offline/online cycles (`VERIFIED_DEVICE`), returning `0-1` each time.
Phosh remained on GLES2; this validates hotplug recovery, not suspend current
or full-system collapse. A five-second RTC alarm fired
while awake; a subsequent `freeze` test did not restore USB. Its ramoops ends
at console suspension, without a panic trace; the failing device callback is
not yet identified. Logs and checksummed test
bundles are in separate `/boot/hikari-mpm-probe-20261008` and
`/boot/hikari-hotplug-pen-20261008` directories; the production bundle is intact.

The subsequent PM-debug candidate failed before reaching its initramfs. Its
ramoops records repeated `unexpected IRQ trap at vector 21` (hexadecimal
Linux IRQ33), a charger I2C timeout and an RCU stall. This is an early-boot IRQ
storm, not evidence of a suspend panic. The initramfs log left on SD belonged
to the preceding kernel and must not be attributed to this attempt. The
failed console is preserved in
`/boot/hikari-pmcheck-20261008/results/boot-failed-ramoops.txt`. A separate
read-only diagnostic candidate confirmed IRQ33 is TLMM's summary interrupt,
GIC hardware IRQ48. BOOT retains enabled APPS GPIO forwarding across kexec,
while the receiving driver initially has no child IRQ handlers. A receiving
kernel safeguard masks those inherited APPS forwards before registering the
GPIO IRQ controller. It preserves latched status, raw detection, modem targets
and direct-connect routing. Consumers re-enable their own IRQs normally.

The safeguard candidate
`7.3.0-rc1-hikari-system-tlmmhandoff-20261008-g6d2d103e2952` passed three
BOOT-to-kexec starts with `Err: 0`, five inherited IRQs masked each time,
Phosh on GLES2/renderD128 and the Synaptics input device present. Ten further
CPU1 offline/online cycles passed. This is device evidence for the safeguard,
not proof that every intermittent cold-boot failure or suspend failure is
resolved. Read-only diagnostics remain outside the canonical patches. Logs
and checksums are in `/boot/hikari-tlmmhandoff-20261008/results`.

Next: isolate device suspend/resume, then audit wake
constraints and deeper levels.
Both-edge wake requests are rejected on entry rather than silently dropping
one edge on this single-polarity hardware. Unmapped wake sources, dual-edge
handling and their constraints must be audited before any PXO OFF level.
PXO OFF, deeper L2/VDD states and timed-wake policy remain disabled.

Local checks on 2026-10-08 passed: exact patch-series materialization,
ARM zImage and matching modules for both MPM stages, DT binding/example and
DTB schema checks, and the existing ten repository tests. The final prepared
tree is `73d66f75d52a05a215becb9f12485343680664ed`. These are build checks;
the physical checks above cover MPM arm/disarm only. At recovery the phone is
in immutable BOOT; the production SYSTEM bundle remains unchanged.

The hotplug stage updates the prepared tree to
`8b5eb5d1b7164def40ca5df00ea13ebc20943956`. Exact series materialization and
the ten repository tests passed. The device test used kernel
`7.3.0-rc1-hikari-system-irqsource-20261008-ge7b82749665b`, with read-only IRQ
diagnostics outside the canonical patches, matching modules, `cpuidle.off=1`
and MPM enabled only in its test DTB. Logs are in
`/boot/hikari-irqsource-20261008/results/hotplug-20.log`.

The TLMM handoff stage updates the prepared tree to
`d9fbfe8b6cc17531202e8792dd058c5cb40ba6cf`; exact materialization and all ten
repository tests passed. BOOT and the production SYSTEM bundle remain intact.

The handoff safeguard also handles unmapped PM8xxx interrupt sources. A
2026-10-08 diagnostic boot stalled in PM8058 parent-IRQ registration before
child IRQ mappings existed. The candidate masked and acknowledged unmapped
IRQ75 (keypad-stuck), then booted with `Err: 0` and hardware Phosh
(`VERIFIED_DEVICE`). Mapped sources retain their ordinary IRQ handling.
Exact materialization passes with prepared tree
`9978f3ab02f5cbb73a7f2193848c5a71ebc6f39b`.

Device-only suspend testing (`pm_test=devices`, `freeze`) returned successfully;
USB re-enumeration required restoring the host NCM link. Wi-Fi resume logged
an HTAvail timeout and remains unresolved. The subsequent `pm_test=platform`
passed all noirq callbacks but stopped during Adreno runtime resume: rail
enable completed, then `enable_clk()` did not return. Ramoops contains no
panic trace. GPU hardware re-init and CPU/RPM collapse were not reached.
Clock-call diagnostics remain outside the canonical patches. Logs are in
`/boot/hikari-pmichandoff-20261008/results/pm-platform` and
`/boot/hikari-tlmmhandoff-20261008/results/pm-devices`. This is an unresolved
resume failure, not verified suspend support.

Further read-only traces narrowed this failure to `gfx3d_clk` enable: OPP
rate setting and preparation of all four GPU clocks completed. Sony's
`clock-8x60.c` explicitly makes GFX3D depend on `gmem_axi_clk`, whereas the
current bulk enables core before memory/bus interfaces. A separate A220-only
candidate moves core last (and therefore disables it first). It builds and
passes checkpatch but has **not been physically tested**; it is a hypothesis,
not an accepted resume fix. Bundle: `/boot/hikari-gpuorder-20261008`, release
`7.3.0-rc1-hikari-system-gpuorder-20261008-g39c978ab5093`, zImage SHA256
`2e769e18b3f4da48dab1b32910123814c6b56476873118faf3df94cafbbd80c8`.
Failure logs are preserved in `/boot/hikari-gpubulk-20261008/results`.
At the owner's stop request the candidate was unloaded (`kexec_loaded=0`)
and the phone remained in immutable BOOT. Production BOOT/SYSTEM were not
modified. Clock ordering and temporary traces remain outside canonical patches.
