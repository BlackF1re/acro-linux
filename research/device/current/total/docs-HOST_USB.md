# Host USB workflow: Android, S1Boot fastboot, WSL

Observed 2026-09-01. This is host setup information, not authorization to flash
or unlock a phone.

| Mode | USB VID:PID | Observed description |
| --- | --- | --- |
| Android ADB | `0fce:5176` | Xperia acro S / LT26W |
| Sony fastboot | `0fce:0dde` | Sony Ericsson S1Boot Fastboot |

Re-enumeration can break a one-shot USBIP attach. The observed BUSID on this
host was `2-1`, but BUSIDs are host/port-specific: start with `usbipd list`.

Administrator PowerShell:

```powershell
usbipd list
usbipd policy list
usbipd policy remove --guid <GUID>       # only erroneous/stale policy
usbipd policy add --effect Allow --operation AutoBind --busid <BUSID>
usbipd policy list
```

Ordinary PowerShell; keep it running through re-enumeration:

```powershell
usbipd attach --wsl XperiaDev --busid <BUSID> --auto-attach --unplugged
```

If the device is already connected and this release does not require it, omit
`--unplugged`. usbipd-win 5.3.0 accepts `--wsl XperiaDev`, not
`--distribution XperiaDev`.

In WSL: `watch -n 0.2 lsusb`. Fastboot is expected as blue LED plus
`0fce:0dde ... S1Boot Fastboot`; use ordinary `fastboot devices` and approved
`fastboot getvar ...`. Do not use obsolete `fastboot -i 0x0fce`. Sony documents
Volume Up while connecting USB for fastboot; Volume Down is Flashmode.
