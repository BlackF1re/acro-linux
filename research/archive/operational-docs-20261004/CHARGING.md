> Historical snapshot, superseded by docs/CHARGING.md. Do not use as current operating instructions.

# Battery and charging

## Verified behavior

The native BQ24160/BQ27520 path is `VERIFIED_DEVICE` for USB sink charging.
On the physical Hikari, patch 0075-era policy produced 148 seconds of
continuous charging: battery voltage rose from 3.997 V to 4.003 V, reported
current remained about +252–257 mA and the external USB meter stopped cycling.
The same policy was subsequently exercised by the SYSTEM SMP kernel. At 100%
and 4.204–4.205 V, six ten-second samples reported only +56–69 mA battery
current while the configured charge-current ceiling remained 1.525 A. This is
physical evidence that the upper-charge path tapers instead of continuing at
the maximum configured current.

The maintained driver now consolidates those functional fixes into one patch:

- never echo the write-only CONTROL reset bit;
- keep the conservative 500 mA USB input policy during safety holds;
- preserve hardware charge completion;
- refresh the charger watchdog without restarting the charge cycle;
- hold a wake source while active charging needs watchdog service;
- coordinate BQ24160 OTG lock with USB host VBUS;
- apply the revision-2.3 4.0/3.9 V hold only in the Sony warm range;
- disable battery charging on missing gauge data or out-of-range temperature.

Transient bring-up state logs were removed. Errors remain rate-limited and
observable through the kernel log.

## Not yet verified

Charging through the physical cradle is `BLOCKED` by the suspect cradle and
needs a known-good dock. A complete low-to-full cycle, unplug/replug endurance,
temperature-boundary behavior and suspend/resume need dedicated physical
acceptance. Never enable BQ27520 NVM updates during these tests.

Use `scripts/check-hikari-charging.sh` for a sampled device record; an external
meter is required to confirm real input current.
