# CPU and power metadata

- cpufreq driver: `msm`; available governors include `conservative`,
  `interactive`, `ondemand`, `performance`, and others. The sampled policy was
  192–1512 MHz under `conservative`; hardware table exposed 192–1890 MHz.
- cpuidle driver/governor: `msm_idle` / `menu`. CPU0 exposes WFI, retention,
  standalone power-collapse, and power-collapse states; CPU1 exposes the first
  three.
- Device paths identify bq27520 fuel gauge, bq24160 charger, `chargalg`,
  SEMC battery data and charging cradle support, PM8058 RTC, MSM watchdog, and
  eight legacy thermal zones.
- Standard `/sys/class/power_supply`, `/sys/class/thermal`, and
  `/sys/class/rtc` were empty in this kernel despite the device paths above.

Legacy runtime observations in the sanitized dmesg show BQ24160
charge-current/state transitions and BQ27520 capacity/full-state changes.
They are useful baseline observations, not target-Linux implementation or a
formal acceptance test. The 1890 MHz table entry belongs to a custom kernel
and is not evidence of a Sony-approved OPP.
