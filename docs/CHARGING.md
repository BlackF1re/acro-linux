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

The first physical run reported raw status `0x27`. In the BQ24160 encoding its
current `STAT` field is USB-ready while its low fault field is the latched,
read-to-clear history value 7. The old project driver incorrectly treated any
non-zero history as a current fatal condition and could therefore disable a
presently usable input. The corrected driver follows the TI/Sony separation:
charge disable and `POWER_SUPPLY_HEALTH_UNSPEC_FAILURE` now require the current
`STAT=FAULT` state (or an actually unsupported current state), while the fault
history remains logged for diagnosis. This does not relax the 500 mA input
cap, voltage/temperature limits, watchdog policy, revision-5 hysteresis, or
fuel-gauge write prohibition.

This is an evidence-backed software correction, not a physical charging
claim. Acceptance still requires positive battery current and increasing
state of charge on the Xperia.

The g27 attempt sampled raw state `0x23`, logged one successful `charging
enabled` transition after CE/HZ release at the conservative 500 mA input
limit, and later sampled raw state `0x40` with `FAULT=0`. This physically
verifies native driver programming and charger activation/status transition.
It does not yet verify useful battery charging: the retained evidence lacks a
reliable positive-current observation and state-of-charge increase.

The g29 post-mortem again logged successful conservative charger programming
at 500 mA input, 1.525 A charge-current limit and 4.20 V regulation. Its later
asynchronous policy reads returned `-EAGAIN` once and then `-ETIMEDOUT` while
the main init thread was stalled in the unpowered display island. These events
prove neither useful positive battery current nor a charger root cause. They
remain a separate charging reliability issue to retest after display init no
longer stalls the kernel-init path.

The recurring `l6: voltage operation not allowed` warning comes from the
Qualcomm USB HS PHY requesting the 3.05--3.30 V voltage triplet on PM8058 L6,
which Hikari already exposes as a fixed 3.05 V rail. The local PHY correction
skips only that redundant voltage request when the regulator already reports
a value inside the driver's supported range. It preserves regulator load,
enable, topology, and the proven USB path. Power-cycle, suspend/resume, and
positive charging remain physically unverified.

The display-cleanup boot confirms that useful charging is still not working.
After initially entering USB charging, BQ24160 reported current `STAT=FAULT`
with fault code 6 (USB supply fault), then repeatedly alternated through no
valid source, USB ready and charging. Sampled battery voltage declined from
3.597 V to 3.570 V. In the immediate TWRP control boot on the same cable, ADB
remained configured, the vendor stack explicitly selected USB at 500 mA, the
fuel gauge reported +366 mA, and capacity increased from 8% to 9%. Target
charging is therefore `PARTIAL`, not accepted. See
[the post-mortem](../research/device/current/boot/usb-charging-postmortem-2026-09-11.md).

## USB-supply and OTG coordination successor

The working TWRP control and exact Sony driver both explicitly select the USB
input in BQ24160 register 0 and release `OTG_LOCK` in register 1 before normal
sink charging. The target driver previously did neither. Patch 0068 now
performs both operations at probe; this is the smallest source-backed change
that directly addresses the target-only USB-supply fault.

The same patch exports an `usb-otg-guard` regulator consumed by the external
5 V/NCP373 VBUS chain. Host enable asserts `OTG_LOCK` and CE-disable before
either 5 V switch can turn on. Host disable removes the lock and schedules an
immediate normal policy update. It therefore makes source and sink modes
mutually exclusive without importing the Android charger framework.

The complete 0073 display/GPU/safe bundle has compiled and passed the
DT/config/source guards. Its compiled display DTB contains physical one-based
PM8901 MPP1 for `ext_5v_en`, the then-assumed PM8058 MPP10 for VBUS detection, and the
BQ24160 post-init dependency needed to break the regulator probe cycle. The
display ELF SHA-256 is
`59a77176ffaf9090d56b91129f52e521363900485728e1b32409d07a288593f3`.
The 0073 image physically booted and BQ24160 saw the attached USB input as
`USB_READY` (`raw=0x2b`), but a separate PM8058 GPIO numbering error falsely
selected host mode and disabled `ttyGS0` at about 2.25 seconds. The local DT
initially changed USB ID to 30. A source recheck then proved Sony's GPIO30 and
MPP10 values are zero-based indices, requiring physical GPIO31 and MPP11 in
mainline; the current local DT uses those physical specifiers. Charging
remains `PARTIAL`: acceptance still needs stable device-mode USB, positive
battery current and rising state of charge. OTG-source operation is a separate
acceptance test and must not be counted as charging success.

The final GPIO31/MPP11 correction is build 0075. On the phone it sustained
High-Speed gadget traffic and a physical disconnect/reconnect. With notebook
power attached, both the USB charger and BQ24160 reported online while the
gauge measured 4.080--4.096 V, 96--97% and about -0.25 A. The lack of positive
charge current at that voltage is expected: Sony's source-backed revision-23
safety policy stops charging above 4.0 V and releases the hold only at or below
3.9 V. Thus input detection is physically verified, but positive-current
charging and a voltage/SOC rise below the restart threshold remain unverified.

The failed 0075 OTG attempt did not reach host-controller registration: the
retained log shows ChipIdea blocked while freeing an open diagnostic serial
port. Build 0076 corrected that independent role-switch teardown defect by
disabling the `ttyGS0` kernel console and preventing shell respawn until a
complete disconnect. The physical 0076 run entered and removed EHCI host mode
three times and returned to the serial gadget. It still supplied no VBUS.
Debugfs showed PM8901 MPP1 inherited as `digital bi-dir`: the generic SSBI MPP
output callback did not clear input mode or honor the requested GPIO value, so
the logical `ext-5v` regulator enable never asserted its physical enable pin.
Patch 0070 corrected that generic output-state defect for build 0077. Its
physical test exposed a second source-mode defect: the driver used PM8058's
MPP register base `0x50`, while PM8901 MPP1 is register `0x27`; direct readback
showed it still at output-low value `0x30`. Patch 0071 selects the Sony-backed
PM8901 base for build 0078. These source-mode fixes do not change the
conservative sink-charging policy or constitute positive-current charging
evidence.

## Sony-derived Android control measurement

The physical control run on 2026-09-11 verifies that the phone and current
USB cable can deliver useful charge. With the notebook disconnected the
fuel-gauge current was about -0.16--0.28 A and BQ24160 reported
`Discharging`. After reconnect, the legacy stack identified a standard
downstream port, selected a 500 mA input limit, reported `Charging`, measured
+0.31--0.36 A into the battery, and advanced SOC from 93% to 94%. This is a
legacy-baseline result only; target Linux remains `PARTIAL` until it passes
the same transition test. Cradle charging remains `NOT_VERIFIED` because the
available cradle appears defective.

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
