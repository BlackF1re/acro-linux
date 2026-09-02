# Host USB workflow: Android, S1Boot fastboot, WSL

This document records the development host workflow observed on 2026-09-01. It is host setup information, not authorization to flash or unlock a phone.

## Why an ordinary attach is insufficient

The Xperia re-enumerates when it changes mode:

| Mode | USB VID:PID | Observed description |
| --- | --- | --- |
| Android ADB | `0fce:5176` | Xperia acro S / LT26W |
| Sony fastboot | `0fce:0dde` | Sony Ericsson S1Boot Fastboot |
| BOOT #5 debug gadget (expected) | `1d6b:0104` | Hikari Mainline Debug, CDC ACM |

An ordinary one-shot USBIP attach can be lost during that identity change. Before AutoBind/auto-attach was configured, this made S1Boot appear to disconnect from WSL and eventually fall through to charging mode. A persistent auto-attach PowerShell process made the same physical port stable across the re-enumeration.

## usbipd-win 5.3.0 procedure

The observed physical-port BUSID on this host was `2-1`. BUSIDs are host/port-specific: **always begin by discovering the actual value**, and do not copy `2-1` to another machine.

In Administrator PowerShell:

```powershell
usbipd list
usbipd policy list
usbipd policy remove --guid <GUID>       # only to remove an erroneous/stale policy
usbipd policy add --effect Allow --operation AutoBind --busid <BUSID>
usbipd policy list
```

Then, in ordinary PowerShell, keep this command running during the mode transition:

```powershell
usbipd attach --wsl XperiaDev --busid <BUSID> --auto-attach --unplugged
```

If the device is already connected and this usbipd release does not require `--unplugged`, the equivalent command without that option is acceptable. For the installed usbipd-win 5.3.0, the distribution selector is `--wsl XperiaDev`; `--distribution XperiaDev` is not a valid option.

Inside WSL, observe enumeration without sending a command to the phone:

```sh
watch -n 0.2 lsusb
```

After the normal Sony fastboot key sequence, a blue LED and `0fce:0dde ... S1Boot Fastboot` are the expected signs. Use ordinary `fastboot devices` and approved `fastboot getvar ...` commands. The installed modern host fastboot does not accept the obsolete `-i 0x0fce` option, so do not use it.

The Sony physical key guidance is: with the phone off, hold Volume Up while connecting USB for fastboot; Volume Down is Flashmode, not fastboot. See [Sony’s key-combination documentation](https://developer.sony.com/open-source/aosp-on-xperia-open-devices/get-started/flash-tool/useful-key-combinations).

## Forced recovery from a hung experimental kernel

`VERIFIED_DEVICE` operational observation on this handset: after the first
and second experimental native-kernel attempts hung on a black screen, an
ordinary Power hold and volume buttons did not recover it. Holding **Power +
Volume Up** together forced a reset/shutdown and made the handset recoverable
again.

This is distinct from fastboot entry:

```text
Power + Volume Up                 -> forced reset/shutdown
phone off + Volume Up + USB cable -> S1Boot fastboot
```

After a forced reset, use the documented phone-off Volume-Up USB sequence and
confirm `0fce:0dde` before any approved recovery action. This path does not
depend on Android userspace having booted.

## Expected mainline debug-gadget handoff

BOOT #5 uses the same physical connector but, if its MSM8x60 HSUSB device-mode
path probes, re-enumerates as the non-unique development identity
`1d6b:0104` (product string `Hikari Mainline Debug`, serial string
`HIKARI-DEBUG`). AutoBind applies to the physical BUSID, so the existing
auto-attach PowerShell process should carry this new identity into `XperiaDev`
too. It is a prediction from the local artifact, not a device verification.

Inside WSL, wait for `/dev/ttyACM*` and use the reconnecting helper:

```sh
scripts/connect-hikari-console.sh
```

The helper intentionally selects a CDC ACM node rather than any device serial.
Its expected device-side peer is `/dev/ttyGS0`; details and failure boundaries
are in [USB.md](USB.md).
