# Hikari build 0078 device observation

Date: 2026-09-12

Evidence state: `VERIFIED_DEVICE` for the recorded boot and USB-device
observations.  USB host/OTG remains `IMPLEMENTING`: no OTG adapter or
peripheral was attached during this run, so this run is not an OTG failure.

Build 0078 booted Linux 7.3.0-rc1, brought up the display, exposed the CDC ACM
gadget, and configured BQ24160 charging policy. The private captured ramoops
record is excluded because its raw command line contains device identifiers.
It contains no ChipIdea host-role transition, EHCI host
registration, source-regulator enable, or downstream USB enumeration.  The
operator subsequently confirmed that the OTG connection may have been omitted.

The same record explains why live serial diagnostics were unreliable.  The
interactive shell started at 3.118 seconds and exited at 4.889 seconds; later
sessions also started and exited quickly.  The synchronous supervisor then
waited for a disconnect and could miss short reconnects.  Build 0079 therefore
runs the shell as a supervised child, kills it when the UDC leaves
`configured`, retries after a bounded delay if a host-side COM probe closes it,
and logs USB-role transitions plus PM8901/BQ24160 raw register readback to
ramoops.
