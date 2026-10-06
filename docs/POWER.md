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

Only s2idle is currently advertised. Prior platform/suspend tests caused
Wi-Fi/USB and display underrun regressions. Reliable suspend/resume and
cpuidle are not established; do not enable automatic suspend without a new
acceptance test. The current `sleep.target`/`suspend.target` unit state alone
is not proof of a mask or of working resume.

Retain watchdog, pstore/ramoops and error logging. BOOT remains immutable;
experimental SYSTEM kernels reside in separate microSD directories. Prior
suspend attempts are summarized here; no experimental suspend hook is enabled
in production.
