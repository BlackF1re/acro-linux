# Hikari build 0077 OTG source-power test

Date: 2026-09-12

Evidence state: `VERIFIED_DEVICE` for the observations below.  The tested
function remains `IMPLEMENTING` because connector VBUS and peripheral
enumeration failed.

With the build 0077 phone switched from the serial gadget to host role,
ChipIdea removed the UDC and registered the EHCI host controller.  The local
role monitor observed all three logical source regulators enabled, TLMM28
(`ncp373_en`) high, TLMM104 (`/FLG`) returning high after its short start-up
pulse, and BQ24160 register 1 equal to `0xf0` with the OTG lock asserted.
`/proc/interrupts` recorded six edge interrupts for GPIO104 under the
fixed-regulator `under-voltage` label.  No attached peripheral received
observable power or enumerated.

The decisive readback was the PM8901 SSBI regmap:

```text
027: 30
028: 30
029: 30
050: 00
```

Sony's PM8901 MFD source defines its MPP register base as `0x27`, whereas the
generic mainline SSBI MPP driver used the PM8058 base `0x50` for every
compatible.  Thus build 0077's debug GPIO cache showed MPP1 high while the
physical PM8901 MPP1 control register remained `0x30` (digital output low).
The host state should change register `0x27` to `0x31` and restore it to
`0x30` when source power is disabled.

Patch 0071 selects register base `0x27` for `qcom,pm8901-mpp` and retains
`0x50` for PM8058.  This is a source-backed correction; build 0078 still
requires a physical test of register readback, connector VBUS, peripheral
enumeration/data, and return to USB device mode.
