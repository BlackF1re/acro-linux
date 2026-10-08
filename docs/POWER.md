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
not suspend/resume. MPM wake routing and deeper RPMRS sleep-level policy remain
unimplemented. The current
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
