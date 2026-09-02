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
              -> built-in g_serial CDC ACM -> /dev/ttyGS0
```

The DT node supplies HSUSB1 XCVR/iface clocks, the HSUSB1 reset, ULPI PHY,
and the two evidenced PM8058 rails. The downstream VDDCX vote is not yet
represented by the current PHY binding; this, and physical confirmation of
vendor ULPI initialization, remain the main device-mode risks.

## BOOT #5 gadget

All controller, PHY and gadget components are built in.  BOOT #5 deliberately
uses the static legacy `g_serial` composite rather than userspace configfs:
its default `use_acm=true` binds one CDC ACM function when the UDC appears,
without waiting for PID 1 to create a gadget.  The expected gadget identity is
the non-unique upstream g_serial CDC ACM default `0525:a4a7` (NetChip/Linux
USB Serial Gadget); it has no device-derived serial string.  It is a debug
identity only, not a production USB identity.

`CONFIG_U_SERIAL_CONSOLE=y` is built in, but the current static `g_serial`
driver does not call `gserial_set_console()` to register `ttyGS0` as a kernel
console.  Therefore BOOT #5 does **not** add `console=ttyGS0,115200` or claim
an early console.  Ramoops remains the early path; after `ttyGS0` appears, the
initramfs starts the interactive shell below.

No ECM function is configured in BOOT #5. Adding a composite function before
the ACM transport has a physical result would make failure attribution worse.

If the UDC binds, g_serial is expected to create `/dev/ttyGS0`; a separate
supervisor waits indefinitely for that node and restarts the console service
if it exits. It launches BusyBox as `setsid -c cttyhack sh -i`, with stdin,
stdout and stderr explicitly redirected to `/dev/ttyGS0`. Thus the shell has
the gadget node as all three standard streams and a controlling terminal; it
is not merely a shell with output redirected to USB. PID 1 continues
independently, logs its state to ramoops, and emits an `ALIVE` marker every 30
seconds.

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

## MSM8x60 vendor ULPI initialization

`VERIFIED_UPSTREAM` source review found that the pinned Linus revision did not
contain the required MSM8x60 vendor ULPI writes.  The external BOOT #5 kernel
worktree therefore carries a mechanical rebase of Herman van Hazendonk's
author-preserved v3 series dated 2026-06-16:

| Commit in external worktree | Original public message | Effect |
| --- | --- | --- |
| `a2e1e55ae3b266d90dc7c7a0629f4398b4cc41f7` | [v3 1/2](https://lkml.iu.edu/2606.2/01062.html), Message-ID `<20260616-submit-phy-usb-hs-vendor-init-seq-v3-1-7d21fb1d1484@herrie.org>` | Adds the optional `qcom,hs-drv-slope` binding. |
| `7d2353796ad5317c04c14465fcf3321f2f89c225` | [v3 2/2](https://lkml.iu.edu/2606.2/01073.html), Message-ID `<20260616-submit-phy-usb-hs-vendor-init-seq-v3-2-7d21fb1d1484@herrie.org>` | On MSM8660 power-on, writes ULPI `0x32[5:4] = 0b11` and sets bits 1 and 2 of ULPI `0x36`; an explicitly supplied slope controls only `0x32[3:0]`. |

The rebase was needed solely because the current driver had moved since the
series was posted; it retains the original author, author date, subject,
Message-ID and Signed-off-by.  It is not a project-authored reimplementation.

Sony's downstream Fuji/Hikari code has no board-specific HS driver-slope
override.  The final Hikari DTB consequently **omits** `qcom,hs-drv-slope`,
leaving the documented Sony/silicon default of zero rather than inventing a
board value.

No current MSM8x60 interconnect series is applied: static inspection of the
ChipIdea controller and HS-PHY probe paths found no interconnect consumer.
That is a scope decision for this first gadget attempt, not physical evidence
that USB traffic will work. Physical CDC ACM enumeration remains required
before any USB state becomes `VERIFIED_DEVICE`.

## BOOT #5 diagnostic boundary

Before its normal `ALIVE` loop, PID 1 records the contents of
`/sys/class/udc` and the currently present `/dev/ttyGS*` nodes to `/dev/kmsg`.
It never emits a synthetic USB-ready marker.  Thus a failed enumeration can be
distinguished in the preserved ramoops log from a later userspace failure.
