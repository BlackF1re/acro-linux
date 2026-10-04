# Battery and charging

The Hikari port uses BQ24160 charging and the BQ27520 G1 gauge. The native
policy preserves hardware charge completion, services the watchdog without
restarting the charge cycle, coordinates OTG and applies temperature/gauge
safety checks. Gauge insertion initialization and USB/cradle adaptive input
limits are carried by patch 0081 and canonical DTS.

USB adaptive probing was physically observed at 500/800/900/1500 mA, with
VIN-DPM limiting an earlier source to 900 mA. This is source-dependent;
the configured input limit is not a measurement of consumed current.
The 2026-10-04 live audit reports USB charging, a 1500 mA input limit, gauge
100%, 4.208 V and zero reported net battery current. That snapshot does not
independently validate SOC calibration or charging speed.

The cradle is represented separately in the driver, but the available dock
also failed under Android. Powered cradle acceptance is blocked by external
hardware; retain its source implementation without claiming verification.

Never enable BQ27520 NVM updates. Keep watchdog servicing and rate-limited
errors. Charging across sleep, a complete low-to-full cycle, temperature
boundaries and repeated unplug/replug still require physical acceptance.
Use `scripts/check-hikari-charging.sh` and an external meter.
