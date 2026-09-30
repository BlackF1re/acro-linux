# Hikari build 0076 USB/OTG physical test

Evidence state: `VERIFIED_DEVICE`  
Date: 2026-09-12

Build 0076 enumerated the `g_serial` gadget at High Speed and survived a
physical notebook-cable disconnect/reconnect. The focused serial trace records
three successful registrations of the ChipIdea EHCI host controller and their
subsequent removal. The serial gadget returned after the final transition.
This proves that removing the permanent ttyGS0 console and gating the optional
shell resolved the 0075 UDC teardown deadlock.

No OTG peripheral enumerated and the owner observed no VBUS power. After the
phone returned to device mode, regulator debugfs showed the VBUS chain idle and
GPIO debugfs showed PM8901 `mpp1 : digital bi-dir 0Ohm`. Source inspection then
found that `pm8xxx_mpp_direction_output()` retained an inherited input flag and
ignored its `value` argument. Thus the fixed regulator could report the
external 5 V stage enabled without asserting the physical MPP output. Patch
0070 is the smallest generic correction and is carried by build 0077.

Files:

- `serial-focused.txt`: shell transcript, regulator/GPIO debugfs state and the
  focused kernel log.
- `serial-after-otg.txt`: empty capture attempt retained as negative evidence.

This run verifies the dual-role controller transition and return-to-device,
not host VBUS or USB host data. OTG remains `IMPLEMENTING` pending measured
VBUS, real peripheral enumeration and traffic on build 0077.
