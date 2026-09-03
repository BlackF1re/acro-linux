# Hikari display and charging runtime diagnosis

Status: sanitized `VERIFIED_DEVICE` diagnostic evidence. USB console remains
working; neither the display nor battery charging has passed its functional
acceptance test.

The deployed artifact was 12,515,749 bytes with SHA-256
`7722f8f08b305121b4e303aebd8c584563e2e62b57e14402842602d9150d3352`.
It booted mainline Linux, enumerated `0525:a4a7`, exposed `/dev/ttyACM0`, and
accepted bidirectional commands through the target `/dev/ttyGS0` shell.

## Display boundary

The backlight controller was physically detected at I2C address `0x40` and
exported `as3676-backlight` with brightness 32/127. No DRM card or connector
was registered. Relevant sanitized kernel output was:

```text
clk: failed to reparent dsi1_byte_clk to dsi1pllbyte: -22
clk: failed to reparent dsi1_pixel_clk to dsi1pll: -22
clk: failed to reparent dsi1_esc_clk to dsi1pllbyte: -22
msm_dsi 4700000.dsi: error -EINVAL: dsi_get_config: Invalid version
msm_dsi 4700000.dsi: msm_dsi_host_init: get config failed
msm_dsi 4700000.dsi: probe failed error -22
```

A read-only register check returned zero from the generic DSI version register
at physical `0x047001f0`. MSM8x60 predates the identification scheme used by
the generic DRM/MSM V2 discovery path. The next kernel therefore selects the
source-verified V2 host variant from the explicit
`qcom,msm8660-dsi-ctrl` compatible instead of rejecting a zero version. This
fix is locally built but not yet physically verified.

## Charging boundary

The target kernel physically probed both `bq24160-charger` at `0x6b` and the
`bq27520-0` gauge at `0x55`. USB input was online at the conservative 500 mA
limit, but the exported charger state was `Not charging` with health
`Unspecified failure`; battery current was negative. USB gadget operation at
High Speed does not constitute a charging acceptance test.

The revision-5, source-derived 4.00/3.90 V hysteresis can legitimately hold
charging off at the observed battery voltage, while the health result also
shows non-zero hardware fault bits. The existing safe policy is unchanged.
The next kernel logs raw BQ24160 status transitions so the exact STAT/FAULT
cause can be identified without register writes.

Raw console output remains outside Git and no unique bootloader/device
identifier is included here.

## Later display/charging attempt

The later g24 artifact retained the same three `-EINVAL` DSI reparent
failures, physically detected AS3676 (`0xae`, `0x52`), enabled the backlight,
and reported the BQ24160 raw state as `0x23` (`STAT=2`, latched `FAULT=3`).
It then failed to provide a stable userspace USB terminal. The retained log
does not establish a panel command failure or a current charger fault: it
establishes that the invalid DSI clock graph was still present in the final
DTB and that the read-to-clear charger fault history was observable.

The exact Fuji clock model led to one focused correction: remove the
APQ8064-style DSI source/assigned-parent DT description, expose the direct
MSM8x60 byte and fixed escape branches, and use the shared MDP pixel RCG at
69.672960 MHz. The corresponding local kernel commits are
`a9c320a7dbec` and `73e268175648`. Physical display and positive-current
charging remain unverified.
