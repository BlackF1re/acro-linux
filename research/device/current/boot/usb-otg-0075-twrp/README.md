# BOOT 0075 USB device and failed OTG transition

Date: 2026-09-11 (Asia/Tomsk)

## Evidence classification

- `VERIFIED_DEVICE`: build 0075 enumerated on the notebook as the static
  `0525:a4a7` CDC ACM gadget at High Speed, exposed `/dev/ttyACM0`, accepted
  bidirectional root-shell commands, and repeated that result after a physical
  disconnect/reconnect.
- `VERIFIED_DEVICE`: with notebook VBUS present, native Linux reported the
  connector role `device`, BQ24160 input online, and BQ27520 at 4.080--4.096 V,
  96--97%, and approximately -0.25 A. Charging was intentionally held off by
  the source-backed Sony revision-23 4.0/3.9 V restriction; this is not a
  positive-current charging acceptance result.
- `VERIFIED_DEVICE`: after replacing the notebook cable with a low-risk OTG
  peripheral, the owner observed no peripheral power. Reconnecting the notebook
  did not enumerate the gadget.

## Retained failure

TWRP read `/proc/last_kmsg` from the failed 0075 run. Identifying command-line
values were redacted in the retained raw log. The decisive sequence is:

```text
2757.180  HIKARI SHELL EXIT rc=0
2757.187  HIKARI SHELL RESTART
2759.199  HIKARI SHELL START
2772.678  printk: legacy console [ttyGS0] disabled
2788.988  usb-conn-gpio connector: repeated role: none
2947.128  kworker/u8:0 blocked for more than 122 seconds
           Workqueue: ci_otg ci_otg_work
           schedule -> gserial_free_port -> gserial_free_line
           -> acm_free_instance -> gs_unbind -> usb_del_gadget_udc
           -> udc_stop -> ci_handle_id_switch -> ci_otg_work
```

There is no subsequent EHCI-host registration or peripheral enumeration. The
role worker blocked while tearing down the ACM gadget, before it could enter
host mode and request the VBUS regulator chain. Thus the absence of OTG power
does not disprove the GPIO31/MPP11/MPP1 wiring or the regulator chain.

## Root cause and successor requirement

The diagnostic configuration held gserial line zero open in two independent
ways: `console=ttyGS0,115200`/`CONFIG_U_SERIAL_CONSOLE=y`, and an initramfs
shell supervisor that reopened `/dev/ttyGS0` two seconds after cable removal.
`gserial_free_port()` waits for open users to release the line, deadlocking the
ChipIdea role-transition worker.

The 0076 successor removes ttyGS0 from the kernel console, disables
`CONFIG_U_SERIAL_CONSOLE`, starts the optional serial shell only when the UDC
state is `configured`, and after shell exit refuses to reopen it until a full
UDC disconnect has been observed. Ramoops and framebuffer tty0 retain
diagnostics across host mode. Physical USB-device reconnect and OTG power/data
tests remain mandatory.

