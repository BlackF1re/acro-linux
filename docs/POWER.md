# Power management

USB sink charging is physically verified; detailed policy and remaining tests
are in [CHARGING.md](CHARGING.md). OTG power works with real peripherals.

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
