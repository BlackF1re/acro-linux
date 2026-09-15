# Physical acceptance tests

## Debian migration checkpoint

The first attempt completed the storage portion of steps 1--3: the retained
kernel log showed `mmcblk0p1` mounted read/write, `HIKARI ROOT READY`, and
systemd running from Debian. It failed the display portion before userspace
because DRM/MSM returned `-ENODEV` when the build accidentally omitted the
required physical-scanout source patch. The corrected build has a source-code
gate in addition to its Kconfig/DTB gates. Repeat the sequence below with the
replacement artifact; do not treat the prior black boot as a card/rootfs
failure.

The next candidate corrected that KMS omission and proved the Debian/rootfs
and USB-console path, but not the panel. DRM registered a connected 720x1280
connector and fb0 while the physical display stayed black because the first
MDV22 command DMA transfer returned `-ETIMEDOUT`; blank/unblank reproduced it.
The late streaming-DMA experiment is therefore rejected. Retest with the
physically accepted coherent DSI command-buffer path restored.

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
   This passed twice on 2026-09-15: the loader exposed only CPU0, each load set
   `kexec_loaded=1`, and each SMP stage brought CPUs 0-1 online from microSD.
8. A normal reboot from the first SMP stage returned to the loader and the USB
   ACM console re-enumerated; the second transition then passed. A true
   power-off cold boot, card-absent rescue behavior and display observation
   across the transition remain to be tested separately.

## Internal Wi-Fi

Run the privacy-preserving physical gate on the phone:

```sh
scripts/check-hikari-wifi.sh --scan
```

It verifies the BCM4330 SDIO IDs, loaded `brcmfmac`, `wlan0` and at least one
active-scan result while printing no SSID, BSSID or MAC address. The scan gate
passed repeatedly on 2026-09-16 (six to nine BSSes) and establishes `PARTIAL`.
After explicitly associating with an authorized test network and obtaining an
address, add `--traffic-target` with a controlled reachable endpoint. Only a
successful packet test plus reconnect and suspend/resume coverage can promote
Wi-Fi to `VERIFIED`.

On root-mount failure, the initramfs must print `HIKARI ROOT FAILED` and retain
an emergency shell on the display console; `ttyGS0` is also attempted. Failure
of that rescue path blocks adoption of the new p3 image. Internal eMMC rootfs
work remains out of scope until this removable-storage checkpoint passes.
