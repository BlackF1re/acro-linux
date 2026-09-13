# Hikari USB device debugging

This records the BOOT #5 USB result and the BOOT #5.1 console-only retry. It
authorizes no phone operation.

## Provenance and hardware model

`HISTORICAL_SOURCE`: the Sony/Fuji downstream board file registers the
connector-facing HSUSB controller at `0x12500000`; its `msm_hsusb_ldo_init()`
uses PM8058 L6 at 3.05 V and L7 at 1.8 V. It also contains zero-based Sony
index 10 (physical PM8058 MPP11) VBUS and index 30 (physical PM8058 GPIO31)
ID handling for OTG role switching. The initial BOOT #5 model
deliberately used peripheral-only mode; the current local successor converts
the exact wiring to the upstream USB role-switch and regulator frameworks.

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

Builds through 0075 enabled `CONFIG_U_SERIAL_CONSOLE=y` and used
`console=tty0 console=ttyGS0,115200`. Physical OTG testing proved this unsafe
for a dual-role connector: an open gserial console prevents
`gserial_free_port()` from completing while ChipIdea removes the UDC. Build
0076 disables the ttyGS kernel-console feature and retains tty0 plus ramoops.

No ECM function is configured in BOOT #5. Adding a composite function before
the ACM transport has a physical result would make failure attribution worse.

If the UDC binds, g_serial creates `/dev/ttyGS0`. A separate supervisor opens
an interactive shell only while the authoritative USB role is `device` and
`/sys/class/udc/ci_hdrc.0/state` is `configured`. Addressed, powered and
suspended are ordinary device-side transients and no longer disarm the
supervisor. Leaving the device role terminates the shell before ChipIdea tears
down the gadget; an ordinary shell exit in device role gets a bounded
five-second retry. PID 1 remains independent, logs its state to ramoops, and
emits an `ALIVE` marker every 30 seconds.

Build 0080 physically recovered the redirected shell after EOF and then passed
two independent host opens, including a seven-second closed-port interval.
The same run exposed why an occasional incomplete command was difficult to
recover: a shell started with redirections alone had no controlling terminal,
so `Ctrl-C` was only echoed. Build 0081 tested `setsid cttyhack sh -i`, but
produced no USB shell bytes: BusyBox `cttyhack` discovers the kernel active
console (`tty0`) and switches all descriptors away from ttyGS0. Build 0082
used `setsid -c` and physically established ttyGS0 as the controlling terminal,
but `/proc/$pid/status` proved that ash retained PID 1's inherited `SIGINT`
`SIG_IGN`; even foreground `sleep` could not be interrupted.

Build 0083 uses the freestanding 4528-byte ARM EABI
`hikari-console-launch`. It opens ttyGS0, creates a session, applies
`TIOCSCTTY` and `TIOCSPGRP`, establishes canonical `ISIG` termios, resets
inherited signal dispositions and then execs interactive ash. On the physical
phone, `SigIgn` no longer contained the SIGINT bit; Ctrl-C recovered an
unfinished quote and interrupted `sleep 30`. EOF caused the supervisor to
create a new shell (PID changed to 482), and three more independent opens with
seven-second gaps all executed commands in `device:configured` state. This
diagnostic terminal path is therefore `VERIFIED_DEVICE`; it remains separate
from a production login/authentication design.

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

The later display-cleanup boot again proved initial controller, gadget and ACM
operation, including real shell traffic, but lost the host transport after
about 138 seconds. There was no kernel crash or USB-controller error, and PID1
continued beyond 515 seconds. A simultaneous BQ24160 USB-supply fault and later
input cycling are relevant but not yet proven causal. Reliable enumeration and
reconnect were therefore classified as `REGRESSION` at that stage; see
[the post-mortem](../research/device/current/boot/usb-charging-postmortem-2026-09-11.md).

## Local dual-role and OTG successor

The post-mortem successor adds the
exact Fuji/Hikari connector and source path found in OpenSEMC revision
`c4784b04c08d30f799b8b14b597aeb2124d2e6e1`:

```text
PM8058 GPIO31 (Sony index 30), active-low ID -> gpio-usb-b-connector
PM8058 MPP11 (Sony index 10), active-low VBUS -> gpio-usb-b-connector
connector role switch <-> HSUSB1 ChipIdea @ 0x12500000

BQ24160 OTG lock -> PM8901 MPP1 EXT_5V enable
                 -> NCP373 load switch, enable TLMM28
                 -> connector VBUS
NCP373 fault     -> TLMM104, active low
```

PM8901 is the second SSBI PMIC at `0x00c00000`, with its interrupt on TLMM91
active low and four MPPs. Patch 0066 adds the missing generic PM8901 MFD and
MPP matches. The DT changes HSUSB1 to `dr_mode = "otg"`, keeps peripheral as
the safe default, and represents both connector graph directions.

The source regulator chain enforces Sony's required order. Enabling host VBUS
first asserts the BQ24160 OTG lock and disables charging, then enables the
PM8901 external 5 V stage, and finally closes NCP373. Disable unwinds that
order and immediately restarts the conservative charging policy. This avoids
driving VBUS into the charger input and keeps the 500 mA sink policy unchanged.

The initramfs console correction and dual-role hardware model began as local
build results. The first 0073 device run falsely selected host mode because the
PM8058 USB-ID consumer encoded 29. The retained log shows `g_serial` becoming
ready, `ttyGS0` disabling, then the EHCI host controller registering at about
2.25 seconds. A source recheck found that Sony's `30` and `10` are explicitly
zero-based indices, mapping to physical GPIO31 and MPP11 in mainline. The local
DT now encodes those physical values. Build 0075 then passed sustained
High-Speed enumeration, root-shell traffic, and a physical
disconnect/reconnect. Its attempted transition to OTG did not supply VBUS, and
the notebook gadget did not return afterward. Retained `last_kmsg` shows
`ci_otg_work` blocked for more than 122 seconds in `gserial_free_port()` while
unbinding the ACM gadget; there is no subsequent EHCI registration. The
permanent ttyGS0 kernel console and immediate shell respawn, rather than the
VBUS wiring, prevented host mode from being entered. Build 0076 removed both
holds. On the phone it subsequently entered EHCI host mode three times and
returned to the High-Speed serial gadget without the teardown deadlock. No
attached peripheral enumerated because host VBUS was physically absent.

The 0076 debugfs state then isolated the VBUS failure below the regulator
graph. PM8901 MPP1 was inherited from the bootloader as `digital bi-dir`.
The generic SSBI MPP GPIO output callback set its output flag but neither
cleared the inherited input flag nor stored the requested value. Patch 0070
fixed both generic output paths in build 0077, but the physical test still
supplied no VBUS. Direct SSBI readback found the next and decisive defect:
PM8901 MPP1 register `0x27` remained `0x30` (output low), because mainline used
the PM8058 MPP base `0x50` for PM8901 as well. Sony's PM8901 source defines
the correct base as `0x27`. Patch 0071 selects that base for the PM8901
compatible.

Build 0079 then passed the target-Linux OTG acceptance boundary exercised in
this bring-up. The owner observed source power at the attached Mercusys Wi-Fi
adapter, and retained `last_kmsg` records EHCI registration, High-Speed
enumeration of its Realtek `2c4e:0102` `802.11n NIC`, disconnect, EHCI removal,
and return to device role. This is `VERIFIED_DEVICE` for OTG role switching,
VBUS source power, peripheral USB traffic/enumeration, teardown and return to
device mode. It is not verification of that adapter's Wi-Fi data path, which
requires its driver/firmware and a separate network traffic test.

Build 0075 contains that final mapping and physically verified High-Speed
device mode plus disconnect/reconnect. Build 0076 physically verifies the
serial teardown correction. Build 0077 verifies the complete logical host
sequence and isolates absent source power to the wrong PM8901 MPP register
base. Build 0079 physically verifies the corrected source path and complete
device-host-device cycle. The retained 0074 log remains the negative control for the intermediate
GPIO30/MPP10 mapping. Focused evidence is retained under
`research/device/current/boot/usb-otg-0076-device-test/` and
`research/device/current/boot/usb-otg-0077-device-test/`, with the successful
run under `research/device/current/boot/usb-otg-0079-device-test/`.

Required OTG acceptance uses a low-risk device such as a USB keyboard or
powered hub first. It must confirm the role transition, approximately 5 V on
VBUS, peripheral enumeration and real input/data traffic, with no BQ24160 or
NCP373 fault. Unpowered high-current disks are not an initial test load.

## BOOT #5 diagnostic boundary

Before its normal `ALIVE` loop, PID 1 records the contents of
`/sys/class/udc` and the currently present `/dev/ttyGS*` nodes to `/dev/kmsg`.
It never emits a synthetic USB-ready marker.  Thus a failed enumeration can be
distinguished in the preserved ramoops log from a later userspace failure.
