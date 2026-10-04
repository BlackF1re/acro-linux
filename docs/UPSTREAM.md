# Upstream status

The production direction is current upstream Linux frameworks. Sony/Android
sources are research evidence for Hikari wiring and sequences, not a runtime
dependency.

The reproducible base is pinned in [kernel/source.lock](../kernel/source.lock).
The ordered series contains shared MSM8x60 clock/interconnect/DRM work,
Hikari DT/panel/power support and project corrections. Charger bring-up
iterations were consolidated into one functional patch; pure diagnostic
logging patches are not part of the maintained series.

Patch `0077` is a local MSM8660 TSENS implementation candidate. It reuses the
current Qualcomm TSENS, NVMEM and thermal frameworks and contains only the
MSM8660-specific calibration/topology described by the Sony BSP. It is not an
accepted upstream change. Its temperature/hwmon path is hardware-verified, but
its trip/IRQ policy is not yet accepted or physically exercised. MSM8660 cpufreq is
not papered over with `cpufreq-dt`: upstream still lacks the required Scorpion
SCPLL/L2/regulator/RPM coordination, the local integration now provides this support, with physical acceptance tracked separately.

Before submission, shared changes must be split by subsystem, validated
against current bindings and maintainers' trees, and checked for newer public
series. Keep authorship, revision and Message-ID for imported work in
[SOURCES.md](SOURCES.md). Device verification and upstream acceptance are
separate evidence states.
