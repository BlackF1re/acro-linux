# Hikari USB device debugging

This is the BOOT #5 host-debug design. It is not a physical USB acceptance
result and it authorizes no phone operation.

## Provenance and hardware model

`VERIFIED_VENDOR_SOURCE`: the Sony/Fuji downstream board file registers the
connector-facing HSUSB controller at `0x12500000`; its `msm_hsusb_ldo_init()`
uses PM8058 L6 at 3.05 V and L7 at 1.8 V. It also contains PM8058 MPP10 VBUS
and PMIC GPIO30 ID handling for Android OTG role switching. BOOT #5 does not
claim that those callbacks map to an upstream extcon, so it deliberately sets
the controller to `dr_mode = "peripheral"` only.

`VERIFIED_UPSTREAM`: Linux
[`786262be6048`](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=786262be6048deab760f68c8acc2c85607165894)
contains the `qcom,ci-hdrc` ChipIdea controller and the exact
`qcom,usb-hs-phy-msm8660` ULPI PHY binding. BOOT #5 therefore describes:

```text
USB connector -> HSUSB1 ChipIdea @ 0x12500000 -> ULPI HS PHY
              -> Linux gadget -> configfs ACM -> /dev/ttyGS0
```

The DT node supplies HSUSB1 XCVR/iface clocks, the HSUSB1 reset, ULPI PHY,
and the two evidenced PM8058 rails. The downstream VDDCX vote is not yet
represented by the current PHY binding; this, and physical confirmation of
vendor ULPI initialization, remain the main device-mode risks.

## BOOT #5 gadget

All controller, PHY, gadget and configfs options are built in. PID 1 mounts
configfs and creates exactly one ACM function (`acm.GS0`). It uses the
non-unique development identity `1d6b:0104`, manufacturer `Hikari`, product
`Hikari Mainline Debug`, and serial text `HIKARI-DEBUG`. That Linux Foundation
VID/PID is a local development identity only, never a production USB identity.

No ECM function is configured in BOOT #5. Adding a composite function before
the ACM transport has a physical result would make failure attribution worse.

If the UDC binds, the device is expected to create `/dev/ttyGS0`; a separate
supervisor runs BusyBox `sh` on that node and restarts it if it exits. PID 1
continues independently, logs its state to ramoops, and emits an `ALIVE`
marker every 30 seconds.

## Host use after an owner-approved physical boot

Keep the documented usbipd AutoBind/auto-attach PowerShell process running.
The target gadget will re-enumerate on the same physical port, and WSL is
expected to expose `/dev/ttyACM0` (the number is not guaranteed). Run:

```sh
./scripts/connect-hikari-console.sh
```

The helper waits for a non-unique `/dev/ttyACM*` candidate and reconnects after
a USB reset. It uses `picocom` when available, otherwise `screen`. Expected
read-only initial probes are `uname -a`, `dmesg`, `cat /proc/cpuinfo`, and
`ls /dev`.

## Patch status and acceptance gate

The project searched the claimed June 2026 v3 series *"phy: qcom: usb-hs:
MSM8x60 vendor ULPI init"* before this implementation. At the pinned revision
it was not merged, and its authoritative lore mbox could not be retrieved in
this environment. No unverifiable or rewritten third-party patch is applied.
No current MSM8x60 interconnect series is applied either: the existing device
mode description is deliberately the smallest path that can be built and
tested. Physical enumeration of a CDC ACM interface is required before any
USB state becomes `VERIFIED_DEVICE`.
