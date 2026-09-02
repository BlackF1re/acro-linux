# BOOT #5.1 USB console (sanitized)

Evidence level: `VERIFIED_DEVICE`. No device serial number, Android
identifier, private command line, or raw log is stored here.

## Artifact and flash result

The approved artifact was
`hikari-boot5-console-retry-r1.elf`, 11,970,886 bytes, SHA-256
`036c84308bf985ab59c240df8b2ab4f414791fbf128b75f6789bc797674be615`.
S1Boot accepted its logical `boot` write and reported S1 partID `0x00000003`.
No other partition was written.

## Physical acceptance result

After ordinary S1Boot reboot, the host observed the non-unique static
`g_serial` CDC ACM identity `0525:a4a7` and created `/dev/ttyACM0`. The
device stayed enumerated during the observation window.

The target exposed `/dev/ttyGS0`; the host exposed `/dev/ttyACM0`. The owner
used that transport to obtain an interactive root prompt and execute commands
on the target. The initial shell exited with status zero and the independent
PID 1 supervisor spawned another one. This is a physical acceptance test for
bidirectional interactive I/O and shell respawn.

The host also observed USB High Speed (480 Mbps). Target kernel messages
identify `ci_hdrc.0`, `ttyGS0`, a ready UDC and gadget, a successful raw TX
write, and shell start. Repeated `HIKARI ALIVE` markers span from uptime 2.18
to 1082.67 seconds, proving that PID 1 and its supervisor remained alive for
at least 18 minutes.

The earlier `uname: not found` result was **not** a missing BusyBox applet.
The same built BusyBox binary already contained `uname`, `ls`, `top`, and
other applets; the BOOT #5.1 CPIO lacked their BusyBox symlinks. The host-side
initramfs builder now installs canonical symlinks for already compiled
applets. It does not change the BusyBox configuration or add applets.

## Status

`USB_CONTROLLER`, `USB_PHY`, `USB_ULPI`, `USB_DEVICE_MODE`,
`USB_HIGH_SPEED`, `USB_ACM_GADGET`, `USB_TTYGS0`, `USB_CONSOLE`,
`USB_INTERACTIVE_ROOT_SHELL`, and `USB_SHELL_RESPAWN` are
`VERIFIED_DEVICE`. ECM, USB host/OTG, power-cycle, runtime-PM, and
suspend/resume behaviour remain untested.
