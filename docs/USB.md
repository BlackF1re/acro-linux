# Hikari USB device debugging

This records the BOOT #5 USB result and the BOOT #5.1 console-only retry. It
authorizes no phone operation.

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

`CONFIG_U_SERIAL_CONSOLE=y` is built in. In the pinned 7.3-rc1 tree, static
`g_serial` creates an ACM function; `acm_alloc_instance()` calls
`gserial_alloc_line()`, which invokes `gs_console_init()` for line 0 and
registers `ttyGS0` as a console. BOOT #5.1 therefore uses
`console=tty0 console=ttyGS0,115200`. This is a **late** console: it cannot
replace early diagnostics before the UDC/ACM function appears, so ramoops
remains mandatory.

No ECM function is configured in BOOT #5. Adding a composite function before
the ACM transport has a physical result would make failure attribution worse.

If the UDC binds, g_serial creates `/dev/ttyGS0`; a separate supervisor waits
indefinitely for it and restarts the console service if it exits. First it
writes an explicit raw transport marker, then starts `/bin/sh -i` with stdin,
stdout, and stderr all attached to `/dev/ttyGS0`. This deliberately proves
basic I/O before a later getty/controlling-TTY refinement. PID 1 remains
independent, logs its state to ramoops, and emits an `ALIVE` marker every 30
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
That is a scope decision for this first gadget attempt, not evidence that
every USB workload will work. BOOT #5 physically verified the HS PHY, MSM8x60
vendor ULPI initialization, ChipIdea UDC, and static `g_serial`: the host saw
`0525:a4a7` at USB High Speed (480 Mbps) and created a CDC ACM node. BOOT #5.1
then physically verified the interactive path: the target exposed
`/dev/ttyGS0`, the host opened `/dev/ttyACM0`, and an interactive root shell
executed target commands. The first shell exited with status zero and the
independent supervisor spawned another one. This verifies the shell-respawn
path as well as the transport.

## BOOT #5.1 initramfs console correction

Inspection of the CPIO that was actually embedded in BOOT #5 found an empty
`/dev` directory and only `/bin/sh` alongside BusyBox. The script then called
unqualified `mount`, `mkdir`, `sleep`, and `cat`; those BusyBox applet links
did not exist. Its first mount therefore never ran, `devtmpfs` never created
`/dev/kmsg`, and the old best-effort redirection silently discarded every
expected marker. Separately, the archive had no `c 5:1 /dev/console`, which
explains the kernel's pre-`/init` "unable to open an initial console" warning.

BOOT #5.1 generates its CPIO with the kernel `gen_init_cpio` file-list
mechanism. It contains `c 5:1 /dev/console`, `c 1:3 /dev/null`, and canonical
BusyBox links installed from the already-built BusyBox applet metadata. This
does not add applets or alter the BusyBox configuration. Each mount is followed by a
kernel-visible return-code marker. Once `/dev/ttyGS0` exists, a child first
writes `HIKARI TTYGS0 RAW TX VERIFIED`, records that result in ramoops, and
only then starts a simple redirected interactive shell. PID 1 remains alive
if either operation fails.

The L6 `voltage operation not allowed` message remains unresolved, but is
`NON_BLOCKING_FOR_CURRENT_USB`: physical High-Speed CDC ACM enumeration and
an interactive shell already occurred. The current likely origin is the HS
PHY's `regulator_set_voltage_triplet()` request for the v3p3 rail while Hikari
maps it to fixed 3.05 V PM8058 L6. The live regulator summary shows L6 at
3050 mV and its ULPI v3p3 consumer enabled; this is evidence of a constraint
interaction, not a safe reason to change the working topology. A later focused
power-cycle/suspend/runtime-PM/OTG investigation must establish the exact
cause.

## BOOT #5 diagnostic boundary

Before its normal `ALIVE` loop, PID 1 records the contents of
`/sys/class/udc` and the currently present `/dev/ttyGS*` nodes to `/dev/kmsg`.
It never emits a synthetic USB-ready marker.  Thus a failed enumeration can be
distinguished in the preserved ramoops log from a later userspace failure.
