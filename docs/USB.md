# USB device, host and updates

Hikari uses one dual-role USB controller. The role-switch path keeps the gadget
configuration resident while host mode is active. A small initramfs watcher
retries the configfs binding if ChipIdea's automatic UDC probe fails when
returning to device mode.

SYSTEM stops the initramfs watcher before `switch_root` removes its old root.
Debian then takes ownership through `hikari-usb-gadget-watch.service`. This
prevents the stale process from looping on missing initramfs applets and keeps
role recovery active in the full system.

Device mode is a composite configfs gadget:

- ACM `/dev/ttyGS0` for the interactive terminal;
- NCM `usb0` for bulk transfer and SSH;
- device address `192.168.77.2/30`, host address `192.168.77.1/30`;
- fixed locally administered MACs: host `02:86:60:00:00:01`, device
  `02:86:60:00:00:02`.

BOOT accepts SYSTEM bundles on TCP 7777 and full rootfs streams on TCP 7778.
Every received artifact is staged and SHA256-checked before activation. Failed
kernel receives leave the prior boot inputs in place. XMODEM over ACM remains
a slow fallback:

```sh
scripts/send-hikari-system-update.sh /dev/ttyACM0
scripts/send-hikari-system-update.sh --xmodem /dev/ttyACM0
scripts/send-hikari-rootfs-update.sh /dev/ttyACM0
sudo scripts/hikari-acm-command.py --device /dev/ttyACM0 uname -a
```

The command helper switches the already-open ACM descriptor to raw/no-echo
before reading. This is required under WSL USB/IP: reading an ACM node with its
default echoing line discipline can feed device output back into the shell.

In SYSTEM the same NCM address is configured by systemd-networkd and SSH can
be used for ordinary file/module work. On Windows the whole composite device
must be attached to the XperiaDev WSL instance before Linux sees ACM and NCM.

Host mode must pass a real powered-device test. Enumeration alone is
insufficient; keyboard input or network traffic is required. Sink charging
and host VBUS are mutually coordinated by the BQ24160 OTG guard.
