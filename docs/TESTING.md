# Physical acceptance

Run checks after static build validation. Record durable facts in
`status/hardware.yaml`; keep raw logs under `research/device/current/` only
when they contain evidence not represented elsewhere.

## BOOT and update path

1. Cold boot p3 and confirm the visible banner ends in `BOOT`.
2. Wait at least 60 seconds with the card inserted: SYSTEM must not start.
3. Verify local keyboard input, USB ACM shell and USB NCM
   `192.168.77.2/30`.
4. Send a SYSTEM update and confirm all archive and module hashes pass.
5. Run `hikari-system`; confirm the banner ends in `SYSTEM`, root is the
   labelled microSD and both CPUs are online.
6. Run `hikari-boot`; confirm S1Boot returns to BOOT and again stops.

## Network and USB

- Cycle device→host→device with a keyboard and a real USB data connection.
- Transfer a file larger than the kernel bundle over NCM and compare SHA256.
- Reboot SYSTEM and verify automatic association to the configured AP, DHCP,
  real IP traffic and SSH from another host.
- During bring-up, confirm `root` can log in with an empty password and with the
  provisioned key; require normal authentication before production release.

## Power

- With an external meter, sample charger power_supply state, voltage and
  current through connect, steady charge and disconnect.
- Confirm host mode asserts OTG power without reporting sink charging.
- Repeat role cycling while externally powered.
- Cradle charging requires a known-good cradle and is a separate test.

## GPU

Run `scripts/test-hikari-gpu.py` as root on SYSTEM. Acceptance requires an
FD220 renderer, successful GLES2 shader compilation and draw, the expected
RGBA readback, and no new GPU fault, timeout or hang in the kernel log. Context
creation alone is not an acceptance test. Repeat the test before evaluating a
Wayland compositor.

## Memory

Confirm `/proc/iomem` exposes `0x40000000-0x42dfffff` and
`0x48000000-0x7fefffff`, while boot logs reserve the first 2 MiB for SMEM and
report the upper range as HighMem.  `/proc/meminfo` must report at least
928000 kB `MemTotal` and retain a 65536 kB CMA pool.  Touch at least 640 MiB
with two complementary full write/read patterns, then check for page errors,
allocation failures, aborts, Oopses and panics.  Finally repeat an accelerated
FD220 render test because display scanout allocates from upper-bank CMA.

## Touchscreen

Capture a real interaction from the stable input symlink:

```sh
evtest /dev/input/by-path/platform-16280000.i2c-event
```

Verify taps, drags, releases and simultaneous contacts. The Hikari panel must
report direct input, X `0..719`, Y `0..1279`, distinct tracking IDs and no
`SYN_DROPPED`. Compositor/libinput integration and all-edge calibration remain
separate graphical-session tests.

## Regression floor

Display/backlight, both terminals, microSD read/write, pstore, Wi-Fi traffic,
LEDs/sensors already reached during bring-up, and the original p3 recovery
route must not regress.
