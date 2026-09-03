# Hikari native charging

## Scope and state

`HIKARI_NATIVE_CHARGING` is `IMPLEMENTING`. The driver and physical I2C path
have now run on the Xperia: BQ24160 and BQ27520 both probed, USB input was
reported online at 500 mA, but the charger reported `Not charging` and
`Unspecified failure` while battery current remained negative. No charging
claim is `VERIFIED_DEVICE` until an acceptance test proves positive battery
charge current and increasing state of charge.

The existing proven USB gadget path, ramoops, initramfs supervisor, and display
work remain independent of this stack.

## Evidence-backed topology

Exact Fuji/Hikari downstream sources identify the already-enabled GSBI8 QUP
I2C bus as carrying all three relevant devices:

| Device | I2C address | Hikari wiring | Current role |
| --- | --- | --- | --- |
| AS3676 | `0x40` | existing backlight path | unchanged |
| TI BQ27520 | `0x55` | SOC_INT GPIO123 | mainline `bq27xxx` fuel gauge |
| TI BQ24160 | `0x6b` | charger IRQ GPIO125 | native `power_supply` charger |

The legacy cradle-detect line is GPIO126.  Cradle/IN source selection is not
enabled in this first native implementation: there is no safe physical source
classification yet, and enabling its legacy 2.5 A policy could create an
unsafe dual-input condition.  It remains `BLOCKED` pending a separate physical
test.

## Safety policy

The BQ24160 driver is deliberately conservative.

- An unknown USB source is capped at **500 mA**; no DCP/current boost is
  inferred from a data cable.
- It limits charge voltage to **4.20 V**, maximum charge current to
  **1.525 A**, and termination current to **50 mA**.
- It obtains temperature and voltage read-only from the BQ27520.  A missing
  or failed reading, a temperature below 5 C, or a temperature above 55 C
  disables battery charging while retaining the BQ24160 input power path.
  45–55 C is limited to 400 mA.
- The BQ24160 watchdog is refreshed every 10 seconds.  During suspend this
  initial driver disables battery charging rather than rely on an unserviceable
  12-second watchdog.  Suspend charging is therefore not yet implemented.
- The revision-`0x05` legacy quirk uses the exact 4.00/3.90 V stop/restart
  hysteresis only when that revision is actually read.
- Hardware `STAT=CHARGE_DONE` remains online and is exported as
  `POWER_SUPPLY_STATUS_FULL`. The watchdog worker does not toggle charge
  enable in that state, avoiding an unintended restart of the completed
  cycle. This matches the Sony driver's interpretation of DONE.
- The BQ27520 is never unsealed, reset, put into ROM mode, or written through
  DataFlash.  `CONFIG_BATTERY_BQ27XXX_DT_UPDATES_NVM` is explicitly disabled.

The legacy BQ24160 driver is a hardware and policy reference only; no Android
charger framework, wakelock, or fuel-gauge programming code is retained.

The first physical run occurred above the revision-`0x05` 4.00 V hold
threshold, so the source-derived hysteresis may have deliberately disabled
charging. Independently, `Unspecified failure` proves that the raw hardware
fault field was non-zero. The next locally built kernel reports raw BQ24160
STAT/FAULT transitions to distinguish those conditions. It does not relax the
500 mA input cap, voltage/temperature limits, watchdog policy, or fuel-gauge
write prohibition.

## Required physical acceptance test

After owner-approved deployment, use the already verified USB ACM root shell
and only read power-supply state first:

```sh
ls -la /sys/class/power_supply
for p in /sys/class/power_supply/*; do
  echo "== $p =="
  grep -H . "$p"/{type,online,status,health,voltage_now,current_now,capacity,temp} 2>/dev/null
done
dmesg | grep -Ei 'bq24160|bq27|charger|battery'
```

Acceptance requires observed external USB power, valid fuel-gauge properties,
and an actual charging state without faults.  It must not write storage,
fuel-gauge NVM, registers through `devmem`, or I2C devices manually.

## Provenance

Hardware addresses, GPIOs, limits, watchdog cadence, and revision quirk are
from the exact Fuji/Hikari Sony downstream tree at
`/home/paul/xperia/src/opensemc-msm8x60`: `board-semc_fuji.c`,
`charger-fuji_hikari.c`, `bq24160_charger.c`, and the associated battery
policy files.  The BQ27520 driver and binding are current upstream Linux.
