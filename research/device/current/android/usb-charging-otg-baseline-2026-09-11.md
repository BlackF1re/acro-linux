# Hikari vendor USB, charging and OTG baseline (2026-09-11)

Evidence state: `VERIFIED_DEVICE` for the tested legacy Android/Sony stack only.
This is hardware-reference evidence, not validation of the mainline target.

## USB charging

With the phone connected to the notebook, the vendor stack identified a
standard downstream port and selected a 500 mA USB input limit.  Across a
physical disconnect/reconnect cycle:

- disconnected: `usb online=0`, charger `Discharging`, battery current about
  -0.16 to -0.28 A and voltage about 4.04 to 4.08 V;
- reconnected: `usb online=1`, charger changed to `Charging` within about one
  second, battery current became +0.31 to +0.36 A;
- voltage rose from about 4.09 to 4.18 V and state of charge advanced from 93%
  to 94%.

This verifies that the USB charge path transfers useful power on the physical
device.  The detailed sample stream is in
`hikari-power-monitor-usb-cycle.log`; the initial power-supply, GPIO and kernel
snapshot is in `vendor-power-usb-baseline.txt`.

## USB OTG host

During a physical OTG test the vendor stack performed this sequence:

- PM8901 physical MPP1 (`ext_5v_en`, legacy global GPIO 225) asserted high;
- TLMM GPIO 28 (`ncp373_en`) asserted high;
- NCP373 active-low fault input on TLMM GPIO 104 remained normally high;
- the Qualcomm EHCI host started and enumerated real peripherals.

Observed devices were a QUMO mass-storage device (`090c:1000`), a Kingston
DataTraveler (`0951:1665`), and a Compx keyboard/mouse receiver (`25a7:fa61`).
Short NCP373 over-current indications occurred at insertion, cleared after
about 300 ms, and enumeration then succeeded.  On OTG removal the BQ24160 OTG
lock was released and host power was disabled.

The sampled state is in `hikari-power-monitor-otg-cycle.log` and the complete
test-window kernel log is in `hikari-power-monitor-otg-dmesg.txt`.  Device and
interface identifiers have been redacted from committed evidence.

## Cradle limitation

The cradle phase was not performed because the available cradle appears
defective.  Cradle charging therefore remains `NOT_VERIFIED`; this result says
nothing about the phone-side cradle path.

## Mainline consequence

Mainline diagnostic boot 0072 registered both PM8058 and PM8901 MPP GPIO
controllers but still returned `-EPROBE_DEFER` for the external 5 V fixed
regulator.  The SSBI MPP GPIO consumer binding uses physical, one-based MPP
numbers and translates them to zero-based internal offsets.  The Hikari DT had
specified PM8901 MPP1 as `0`, which cannot match any line.  The same error was
present for PM8058 MPP10 VBUS detection as `9`.  They must be described as `1`
and `10`, respectively; `gpio-ranges` remains zero-based.
