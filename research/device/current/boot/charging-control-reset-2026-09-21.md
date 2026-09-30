# BQ24160 CONTROL-reset correction (2026-09-21)

Evidence state: `VERIFIED_DEVICE`. Charging implementation state: `PARTIAL`.

The deployed second-stage kernel was
`7.3.0-rc1-hikari-g33452d3bca12-dirty`. It booted with CPUs `0-1` online,
`HIKARI_ROOT` mounted from microSD, working fbcon/backlight and the USB ACM
console. The test source was the notebook USB data port, so its safe input
ceiling remained 500 mA.

## Root cause and correction

BQ24160 CONTROL register bit 7 is a write-only reset command and always reads
back as one. The previous driver used `regmap_update_bits()` on CONTROL. Its
read-modify-write therefore echoed bit 7 as one and repeatedly reset the
charger configuration, including the USB input limit, to the 100 mA default.
The exact Sony driver clears bit 7 before every CONTROL write; the TI BQ24160
datasheet independently specifies the same read/write behavior.

Patch 0073 adds a CONTROL-specific update helper that always clears RESET
before writing. It also applies the conservative USB input policy before
temperature, gauge and revision-23 voltage policy exits. Those exits still
hold battery charging disabled; they no longer leave the running system at
the chip's 100 mA reset default.

## Physical observations

Before the correction, CONTROL read `0x8c`: IUSB bits `000`, the 100 mA
default. After deployment, four watchdog-spaced samples retained CONTROL
`0xae`. Because bit 7 always reads as one, `0xae` decodes as IUSB `010`
(500 mA), EN_STAT=1, TE=1, CE=1 and HZ=0. This physically verifies that the
input-limit programming now survives the driver's 10-second watchdog cycle
while the high-voltage hold leaves the input power path enabled.

The clean reboot result remained consistent:

```text
Linux 7.3.0-rc1-hikari-g33452d3bca12-dirty, CPUs 0-1
bq24160: status raw=0x48 stat=4 fault=0
bq24160: charging enabled: input=500000uA ... battery=3966000uV
bq24160: status raw=0x28 stat=2 fault=0
CONTROL: 0xae
charger: online=1, status=Not charging, input_current_limit=500000
gauge: 3928000uV, -289000uA, capacity=100, temp=251
```

Forcing a policy resynchronization briefly released CE and produced CONTROL
`0xac` plus `STAT=0x48` (charging). With normal display load the measured
battery current improved from about -299 mA to -49 mA before voltage crossed
the 4.0 V safety threshold. With backlight off and CPU1 offline it approached
-5 mA; with framebuffer blanked it approached -38 mA. The controller then
returned to the source-backed revision-23 high-voltage hold. No sample was
positive and SOC was already 100%.

Therefore this run verifies the reset-command fix, persistent 500 mA input
policy, CE release and high-voltage hold. It does **not** verify net battery
charging. The present bring-up system's load consumes the available standard
USB budget, and a valid acceptance run still requires a battery below the
3.9 V restart threshold, sustained positive gauge current, rising voltage/SOC
and a subsequent clean stop. Cradle/IN and suspend charging remain unverified.
