> Historical snapshot, superseded by docs/POWER.md. Do not use as current operating instructions.

# Power management

USB sink charging is physically verified; detailed policy and remaining tests
are in [CHARGING.md](../../../docs/CHARGING.md). OTG power works with real peripherals.

The running SYSTEM image exposes the BQ27520 fuel-gauge temperature, PM8058
XOADC channels and the MSM8660 on-die TSENS channel. Patch `0077` implements
the latter through the normal thermal framework using Sony's exact GCC
registers, SPI 178 interrupt and primary/backup QFPROM calibration bytes. On
2026-09-24 the physical device produced twelve stable samples at 42--43 C;
`sensors` reported the same value through the standard `soc_thermal` hwmon
device, systemd had no failed units, pstore was empty and the earlier TSENS
timeout/oops did not recur. This is `PARTIAL`: the sensor path is verified, but
cooling devices, protective trips and throttling still depend on correct
MSM8660 cpufreq support. Full DT schema checking also still needs the host
`yamllint` and `ruamel.yaml` packages.

The separate Fuji/Hikari board NTC on PM8058 MPP10 is also represented through
`generic-adc-thermal`, channel 7 and Sony's exact voltage/temperature table.
On 2026-09-24 a physical CPU busy-loop raised on-die TSENS from 39 to 42 C while
the NTC voltage fell monotonically from about 1.217 to 1.185 V, as expected for
the thermistor.  After reboot `msm-board-thermal` appeared through both thermal
sysfs and lm-sensors at 21.1 C.  This verifies the native measurement path, not
yet thermal trips or cooling control.

There is no upstream MSM8660 Scorpion CPU-clock/cpufreq provider. Enabling a
governor in the configuration cannot safely create frequency scaling: a native
implementation must coordinate both CPU SCPLLs, the shared L2 clock, voltage
rails and RPM/interconnect bandwidth described by the Sony BSP. This remains a
separate `RESEARCHING` driver task; `cpufreq-dt` is not an acceptable shortcut.

System suspend/resume, wake sources, cpuidle, cpufreq, thermal throttling,
cradle charging and long-duration idle consumption are not yet verified.
Active BQ24160 charging deliberately holds a wake source because its watchdog
requires service. This is a correctness constraint until a proven lower-power
design exists.

A release needs repeated suspend/resume, wake-by-button/USB/modem as
applicable, charging completion and unplug/replug tests, and external-meter
idle/active measurements without unexpected wakeups.

### 2026-10-04 suspend diagnostic boundary

On GPU-working SYSTEM #6, RTC-triggered s2idle failed to return; the power
button also did not restore display/USB. Pstore ends after freezing tasks.
Separate SYSTEM #7 preserves the same GPU code and enables PM callback tracing
and a DPM watchdog. With asynchronous PM disabled, freezer and ordinary device
PM tests returned successfully. The subsequent platform test lost both USB
and Wi-Fi; late/noirq callbacks require pstore inspection after recovery.
No deep-sleep or CPU DVFS acceptance is claimed. Evidence:
`research/device/current/power/20261004/RESULTS.md`.

The platform test subsequently triggered the DPM watchdog and rebooted itself
into BOOT. Pstore identifies a Wi-Fi SDIO resume timeout and a concurrent A220
interrupt flood (`RBBM_INT: AB51139E`). Earlier callback messages were overwritten
by that flood. An A220-only IRQ/power-gating diagnostic is being tested; no
completed sleep fix is claimed.

IRQ-gating candidate #8 reached `PM: suspend exit` without the former GPU IRQ
flood, but Wi-Fi had an HT clock timeout and MDP4 reported
`MDP4_IRQ_PRIMARY_INTF_UDERRUN` (`0x100`), matching the owner's blue screen.
Thus this is a partial diagnostic result; display/network resume remains
broken. Owner recovered into BOOT. Working GPU SYSTEM #6 is being restored;
real suspend remains unsafe and must not be enabled automatically.

Bounded #9/#10 tests used a hardware watchdog independently verified to return
BOOT. MDP global re-init did not resolve underrun. Retaining the MDP domain
removed the logged post-resume 0x100 interrupt, but the owner still saw blue
and the pre-suspend DSI video/DMA timeout remained. Wi-Fi/USB did not recover.
The DSI manager stops/resets video only after panel unprepare, while its host
comment explicitly requires this before off commands. An early-disable
candidate failed to establish SYSTEM access; its missing power/enabled guard
was corrected and built, but not boot-tested. Investigation is paused at
physical BOOT recovery while owner is unavailable. No sleep fix is verified.
All diagnostics are saved separately; source is restored to working GPU #6.

## BQ27520 host battery insertion (2026-10-04)

False 100% after deep discharge was physically traced to missing BAT_INSERT:
BAT_DET, INITCOMP and QEN were all clear. Volatile insertion 0x000d changed
SOC to 0..1% and enabled gauging. No reset, unseal or calibration writes.
Kernel source/DT fix built separately; not boot-tested while battery is low.
Current #6 uses an interim oneshot insertion helper; Phosh remains GPU GLES2.
See research/device/current/power/20261004/RESULTS.md and battery-insert-verified.txt.

## USB input adaptation and cradle (2026-10-04)

An isolated #14 kernel build adds source-aware current ramp and VIN-DPM
backoff. It remains unbooted while battery is low. Unknown/USB2 data sources
remain capped at 500 mA; Hikari's present source provider lacks USB_TYPE and
CURRENT_MAX, so automatic higher current needs capability detection first.
USB input hardware ceiling is 1500 mA. The distinct IN/cradle path supports
2500 mA in Sony source, with detect GPIO126, but is not implemented in current
DT/charger driver. Never infer 2500 mA USB support from the IN specification.
Physical 60 s charging sample confirms net charge 195..273 mA and increasing
charge counter despite unchanged integer percentage; cpufreq/cpuidle absent.
See charge-idle-60s.txt, charge-htop-paused.txt and RESULTS.md.

### Cradle and USB probing implementation (2026-10-04, supersedes #14 status)

Separate test kernel #16 physically boots with GPIO126 cradle detection and
BQ24160 IN input support. The cradle power-supply node is present, but actual
cradle charging remains unverified without a powered dock. IN hardware limits
are 1500/2500 mA; USB maximum is 1500 mA. Both inputs use 4.52 V VIN-DPM,
step back on droop and retain a learned limit. Battery/thermal limits unchanged.

Owner-authorized DT opt-in allows unknown USB-source electrical probing; USB3
host attachment alone does not grant a USB2 device >500 mA. Known advertised
limits remain respected. Physical USB ramp reached 1500 mA, DPM activated,
then backed off to stable 900 mA. Battery current increased to ~560..671 mA
while GPU Phosh stayed active. Separate artifacts preserve recovery and do not
replace BOOT or production hikari-next. See power/20261004/RESULTS.md.

Final #17 physically booted and confirmed fast final-step backoff to 900 mA
with DPM cleared, held across watchdog refresh. USB remained accessible;
battery net current ~488..777 mA, final 666 mA at 25.1 C. GPU Phosh remains
active. #17 is separate on microSD; the production boot bundle remains intact.
Powered-cradle and cradle+OTG acceptance remain unverified/unsupported.

## CPU frequency restart (2026-10-04)

A volatile CPU0 clock-only CPUFreq diagnostic is physically verified at
384–756 MHz, including hardware readback, compute checks and schedutil response.
CPU1, voltage scaling and deep cpuidle remain unimplemented. A separate untested
prototype had a wrong L2 mux phandle and CPU regulator ownership; Sony uses SAW
for CPU rails. No unsafe voltage or PLL recalibration path was executed.
See `research/device/current/power/cpu-sleep-20261004/RESULTS.md`.

Cradle experiments are paused: owner reports the assembled cradle also fails
under Android. No current Linux cradle-hardware failure conclusion follows.
