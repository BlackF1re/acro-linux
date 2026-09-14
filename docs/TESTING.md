# Physical acceptance tests

## Debian migration checkpoint

Host builds and static checks do not verify hardware. The next test uses a
separate microSD and preserves the verified p3 rollback image. Before any
flash, record the card identity and confirm that the prepared filesystem is
ext4 with `LABEL=HIKARI_ROOT`.

Acceptance sequence:

1. Boot the candidate ELF once through the existing p3 recovery procedure.
2. Observe `HIKARI ROOT READY` and a Debian login on both fbcon and `ttyGS0`.
3. Record `/proc/cmdline`, `findmnt /`, `uname -a`, `systemctl --failed`, full
   `dmesg`, `/proc/interrupts`, power-supply state and USB role state.
4. Disconnect and reconnect the notebook cable and prove bidirectional shell
   traffic after enumeration.
5. Load each staged module with `modprobe`; a successful probe is recorded as
   `PROBES`, not as functional hardware verification.
6. Run the relevant real-world test before promoting a device: touch events,
   Wi-Fi traffic, Bluetooth transfer, NFC exchange or sensor readings.
7. Validate `hikari-kexec --check`, then `--load`, then `--exec`. Confirm the
   new kernel release and matching `/lib/modules` tree after the transition.
8. Repeat one kexec cycle and one cold boot while retaining working display,
   USB terminal and the documented fastboot/recovery route.

On root-mount failure, the initramfs must print `HIKARI ROOT FAILED` and retain
an emergency shell on the display console; `ttyGS0` is also attempted. Failure
of that rescue path blocks adoption of the new p3 image. Internal eMMC rootfs
work remains out of scope until this removable-storage checkpoint passes.
