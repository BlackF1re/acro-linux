# Configfs ACM device-host-device acceptance, 2026-09-15

Evidence state: `VERIFIED_DEVICE`

Artifact:

- `hikari-debian-fastboot.elf`
- size: 12,856,796 bytes
- SHA-256: `33da9a3df6e770a843781a0ee09112f1c710e591ac13b8d6603d1764f5f70422`
- flashed only to the boot partition through fastboot

The preceding negative-control boot used legacy built-in `g_serial`.  When
Debian `agetty` held `ttyGS0` open, the ChipIdea role worker blocked in
`gserial_free_port()` while removing the gadget.  Host mode did not finish and
the gadget did not return.  The tested successor disables `g_serial` and has
the initramfs create one persistent configfs ACM function instead.

## Physical acceptance

1. Debian booted and the PC enumerated `0525:a4a7`, exposing `/dev/ttyACM0`.
2. Before the role change, sysfs reported `role=device` and UDC
   `state=configured`; the configfs gadget was bound to `ci_hdrc.0`.
3. The owner disconnected the PC and connected a USB keyboard through OTG.
4. The keyboard received source power, enumerated, and real keystrokes entered
   a command in the visible framebuffer console.
5. The owner removed OTG and reconnected the PC.  Without rebooting, the PC
   again enumerated `0525:a4a7`, exposed `/dev/ttyACM0`, and carried an
   interactive shell.

Relevant target log excerpt:

```text
[  209.340226] ci_hdrc ci_hdrc.0: EHCI Host Controller
[  209.341649] ci_hdrc ci_hdrc.0: new USB bus registered, assigned bus number 1
[  209.388706] usb-conn-gpio connector: repeated role: host
[  209.398721] ci_hdrc ci_hdrc.0: USB 2.0 started, EHCI 1.00
[  209.848550] usb 1-1: new low-speed USB device number 2 using ci_hdrc
[  210.021498] usb 1-1: New USB device found, idVendor=04f3, idProduct=0103
[  210.047541] input: HID 04f3:0103 as .../input/input4
[  210.159868] hid-generic 0003:04F3:0103.0001: input: USB HID v1.10 Keyboard [HID 04f3:0103] on usb-ci_hdrc.0-1/input0
[  279.599978] usb 1-1: USB disconnect, device number 2
[  279.630074] ci_hdrc ci_hdrc.0: remove, state 1
[  279.913971] ci_hdrc ci_hdrc.0: USB bus 1 deregistered
```

Post-cycle state at 389 seconds uptime:

```text
role=device
udc=configured
ttyGS0=present
gadget=ci_hdrc.0
hung=0
```

The `hung=0` query covered `blocked for more than`, `hung_task`,
`gserial_free_port`, `gserial_free_line`, `acm_free_instance`, and
`gs_unbind`.  This is acceptance of one complete powered HID role cycle and
the return path.  It does not yet establish repeated-cycle endurance,
suspend/resume behavior, or arbitrary high-current peripheral support.
