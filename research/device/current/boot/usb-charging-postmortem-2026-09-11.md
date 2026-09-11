# USB and charging post-mortem (2026-09-11)

Evidence state: `VERIFIED_DEVICE`. USB reliability state: `REGRESSION`.
Charging state: `PARTIAL`. OTG host state: `UNKNOWN` / not implemented.

TWRP exported 23,665 bytes from the preceding mainline boot through
`/proc/last_kmsg` before recovery diagnostics touched the persistent buffer.
The private capture has SHA-256
`31c24cf8df50320cf0d8047a7c1d34d1256dd1dd7d88a11157336550e622122f`.

The log proves that the mainline HSUSB peripheral path initially initialized:

```text
[    0.753091] g_serial gadget.0: Gadget Serial v2.4
[    0.753384] g_serial gadget.0: g_serial ready
[    4.842747] HIKARI USB SYSFS UDC: BEGIN
[    4.844366] HIKARI USB SYSFS UDC: ci_hdrc.0
[    4.847719] HIKARI USB TTY: ttyGS0
[    4.859519] HIKARI SHELL START
```

The host also physically enumerated `0525:a4a7` and exchanged shell data, so
this is not a failure to probe the controller, PHY, gadget or ACM function.
At 138 seconds the shell exited normally after the host transport closed. No
kernel Oops, panic or USB-controller error followed, and PID1 remained alive
through at least 515 seconds. The current initramfs attempts to reopen ttyGS0
after a two-second delay; its raw write can block without an open host. That is
a diagnostic-console recovery defect, but does not by itself explain loss of
electrical USB enumeration.

The same interval exposed an unstable BQ24160 USB-input state:

```text
[  137.876383] status raw=0x76 stat=7 fault=6
[  138.296343] status raw=0x06 stat=0 fault=6
[  141.186402] status raw=0x22 stat=2 fault=2
[  141.415936] charging enabled ... battery=3579000uV
[  453.826326] status raw=0x00 stat=0 fault=0
[  461.316358] status raw=0x22 stat=2 fault=2
```

Sony's exact BQ24160 driver defines `stat=7` as current FAULT and `fault=6` as
USB supply fault. The mainline log repeatedly alternated between no valid
source, USB ready and charging; its sampled battery voltage fell from 3.597 V
to 3.570 V. This fails useful-charging acceptance. The temporal correlation
with USB loss is strong but does not yet prove that charger programming caused
the data-link loss.

The original TWRP control boot used the same cable and PC. It kept ADB in
`CONFIGURED`, classified the source as a standard downstream port, explicitly
selected the BQ24160 USB input, set OTG lock off and applied a 500 mA input
limit. Live fuel-gauge readings showed `current_now=366000`, battery capacity
increased from 8% to 9%, and voltage reached 3.766 V. This verifies the
connector, cable, PC port, BQ24160 and BQ27520 under the vendor stack and
localizes both regressions to the target Linux implementation.

OTG host mode cannot be accepted from the current image: the final DTB fixes
the controller to `dr_mode = "peripheral"` and does not model the PM8058 ID
input, PM8058 MPP10 VBUS detection, NCP373 VBUS switch or the BQ24160 OTG-lock
coordination present in the Sony source.
