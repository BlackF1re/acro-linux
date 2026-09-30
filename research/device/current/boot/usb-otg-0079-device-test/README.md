# Hikari build 0079 USB OTG device test

Date: 2026-09-13

Evidence state: `VERIFIED_DEVICE`.

Build 0079 supplied connector VBUS to an attached Mercusys USB Wi-Fi adapter,
changed ChipIdea from gadget to EHCI host, and enumerated the real high-speed
peripheral as Realtek `2c4e:0102` (`802.11n NIC`).  Removal generated the
peripheral disconnect, deregistered the host bus, restored g_serial, and
returned the role switch to `device`.  This verifies Hikari USB OTG source
power, host-role switching, USB 2.0 signalling/enumeration, and return to
device mode.  Wi-Fi network operation was not tested and is a separate driver
and firmware acceptance test.

The raw TWRP ramoops capture is intentionally excluded from git because it
contains device identifiers. Its private hash remains in the local evidence
set.
Relevant timestamps are:

- 166.802 s: device role leaves `configured` and becomes `none`;
- 197.298 s: ChipIdea registers the EHCI host controller;
- 197.656 s: downstream high-speed device detected;
- 197.826 s: Realtek `2c4e:0102` descriptor accepted;
- 257.105 s: downstream device disconnect;
- 257.153 s: EHCI bus deregistered;
- 264.569 s: controller returns to device role.

The same capture explains the CDC ACM terminal instability.  Normal host-side
bus activity changed the UDC between `configured`, `addressed`, and
`suspended`.  The 0079 supervisor treated those device-side transients like a
physical disconnect and could leave the shell disarmed after the UDC returned
to `configured`.  The next build gates teardown on the authoritative USB role
instead: device-side UDC transients permit a delayed respawn, while `none` or
`host` kills the shell before OTG teardown.
