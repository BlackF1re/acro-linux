# USB device/host/device path

`VERIFIED_DEVICE`: one complete role cycle passed on Hikari. In device mode,
the PC enumerated the ACM console. After switching to host mode, a powered USB
keyboard enumerated and real keypresses reached the phone. Returning to device
mode restored ACM without reboot; the PC again opened an interactive shell.

The reliable implementation keeps the configfs gadget definition available
across role changes and rebinds it when the ChipIdea UDC returns. This avoids
the old `g_serial` teardown path that blocked while the console was open.
Initramfs and Debian use separate watchers so no process from the old root
continues after `switch_root`.

This proves one powered HID cycle and device-mode return. It does not prove
repeated-cycle endurance, suspend/resume, or support for every high-current
peripheral. Current configuration and commands are in
[`../../../../docs/USB.md`](../../../../docs/USB.md).
