# Boot observations and diagnostics

The handset was already booted into the custom Android legacy baseline when
collection began. No reboot, recovery, fastboot, flashing, mount change, or
block-device read/write was performed.

The legacy kernel is board-file based: it exposes neither
/sys/firmware/devicetree nor /proc/config.gz. That is evidence about this
baseline only, not a requirement for target native-Linux boot.

## Persistent diagnostics

Dmesg reserves 0x7ffe0000-0x7fffffff (128 KiB) as ram_console, and
/proc/iomem also lists ramdumpinfo at 0x7ff00000-0x7ff00fff and amsslog at
0x7ff01000-0x7ff04fff. The registered platform devices are ram_console and
ramdumplog.

At sampling time /proc/last_kmsg, /proc/ram_console, /proc/apanic_console,
/proc/apanic_threads, /sys/fs/pstore, and the checked debugfs ram_console path
were absent. The confirmed mechanism is therefore a reserved legacy
ram-console region with no exposed readout endpoint in the running ROM, not a
tested recovery mechanism.

For the first experimental native-kernel boot, reserve a documented ramoops
region and expose it through pstore; retain serial/USB logging separately.
That is a design recommendation, not a change made in this pass.

# Boot-chain research

## Established for this handset

The read-only legacy fstab evidence maps `mmcblk0p3` to `/boot` in the
recovery-only stanza.  That establishes a legacy boot role for p3; it does
not identify a recovery partition or authorize reading any partition content.
The physical bootloader state, lock state, exact load addresses, boot image
payload layout, and persistent boot-log recovery route are still UNKNOWN.

## Sony ELF format

Historical Xperia LT26 device configuration in Android Open Source Project
commit `b644924c93b3c89e0e6f3aeeb85fb9a23147350f` adds
`custombootimg.mk` and Sony Mobile’s `tools/mkelf.py` to make a `boot.elf`.
This directly establishes that the LT26 family used Sony’s ELF-style boot
container in that historical build flow.  It does not establish the addresses
or components required by this particular acro S image.

Later upstream Sony Xperia work independently describes the format as carrying
kernel, ramdisk, RPM firmware and cmdline.  It is useful tooling provenance,
but its MSM8960 example must never be substituted for MSM8260/Hikari addresses.

| Fact | Confidence / provenance | Consequence |
| --- | --- | --- |
| p3 is legacy `/boot` | `fstab-semc-extract.txt` | It is a protected, never-blindly-overwrite target. |
| Sony ELF container was used by historical LT26 build configuration | AOSP LT26 commit above | Future artifact research needs an ELF-capable, reproducible tool. |
| Exact Hikari load addresses, RPM inclusion and cmdline format | UNKNOWN | Must be derived from a permitted source artifact or a non-destructive inspection. |
| Recovery partition identity and recovery route | UNKNOWN | Cannot be assumed from p2/p5–p11. |
| Persistent logs | legacy ram_console at `0x7ffe0000` was observed | A target kernel must be designed to preserve/retrieve logs only after approval. |

## Safest first experimental-boot path (not authorized or executed)

Do not flash, fastboot-boot, reboot or modify the device under the current
read-only authorization.  Before any experimental boot, the owner must
explicitly approve a plan that first verifies exact device identity, bootloader
state, partition sizes, a recoverable signed backup path, artifact hashes and
the expected Sony ELF layout.  The initial artifact should be the smallest
diagnostic kernel/initramfs with a preplanned persistent/serial log route and a
single explicitly whitelisted boot target.  No safe temporary-boot mechanism
has been established for this exact handset; it is therefore UNKNOWN rather
than assumed from related Xperia devices.

## Sources

- [Historical LT26 custom boot ELF change](https://android.googlesource.com/device/sony/lt26/%2B/b644924c93b3c89e0e6f3aeeb85fb9a23147350f%5E%21/)
- [Upstream Xperia SP boot-format discussion](https://lore.kernel.org/lkml/20250622204546.390249-6-kurniasoemardi@gmail.com/)
- [Sanitized partition evidence](../research/device/current/storage/fstab-semc-extract.txt)
