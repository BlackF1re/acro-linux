# BOOT #5.1 USB console (sanitized)

Evidence level: `VERIFIED_DEVICE` for the target mainline USB peripheral
path and basic interactive shell. No device serial number, Android identifier,
or private log is stored here.

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

The host sent only the read-only line `uname -a` through this transport. The
reply contained a BusyBox root prompt and the shell's response
`/bin/sh: uname: not found`. The latter confirms that the shell received the
line; it is expected because the deliberately minimal initramfs does not
include the `uname` BusyBox applet. This is a successful bidirectional console
acceptance test, not a claim that the full diagnostic userspace is present.

## Status

`USB_CONTROLLER`, `USB_PHY`, `USB_DEVICE_MODE`, `USB_ACM_GADGET`, and
`USB_CONSOLE` are `VERIFIED_DEVICE`. ECM, USB host/OTG, power-cycle and
suspend/resume behaviour remain untested.
