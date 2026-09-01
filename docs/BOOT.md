# Boot observations and diagnostics

The handset was already booted into the custom Android legacy baseline when
collection began. The initial reconnaissance performed no reboot, recovery,
fastboot, flashing, mount change, or raw partition inspection. Later C2 work,
with explicit owner authorization, sequentially read the complete accessible
eMMC user area (`/dev/block/mmcblk0`) into a private raw backup. Thus p1--p15
and potentially sensitive TA-related, radio/NV, and calibration-bearing bytes
are physically present in private recovery media, but were not separately
inspected, parsed, interpreted, extracted, exposed, or committed. The legacy
kernel did not expose eMMC boot0, boot1, or RPMB nodes, so those areas were not
covered.

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
Physical fastboot is now directly observed: Sony S1Boot enumerates as
`0fce:0dde`, implements fastboot protocol `0.5`, reports version
`CRH1099189_R10C008`, and returns `secure: no`. Its `unlocked`,
`max-download-size`, and boot partition query variables are empty; an empty
legacy variable is not a negative attestation. See the [sanitized fastboot
record](../research/device/current/boot/fastboot-summary.md).

Owner-provided history says the bootloader was previously unlocked and a custom
ROM/root were installed. This is not substituted for device attestation, but
is consistent with the observed fastboot result and custom legacy kernel.

The p3 artifact has now been inspected offline under explicit owner approval.
It is a Sony-style ARM ELF with a zImage at `0x40208000`, a gzip ramdisk at
`0x41800000`, and an RPM-marked ELF payload at `0x00020000`. See
[BOOT_FORMAT.md](BOOT_FORMAT.md). Cmdline handling and temporary `fastboot boot`
support remain UNKNOWN.

Two narrowly approved native-Linux Sony-ELF attempts were then made. S1Boot
accepted each through logical `boot`/p3, but neither gave an observable target
marker, ADB, fastboot, or new USB target in 120 seconds. Both were recovered
with the exact private original p3 through S1Boot and Android returned. This
is direct physical proof of the p3 restore route, but not of target boot. The
second attempt's only TWRP previous-boot log is proven to be a later legacy
Android/recovery transition, so its target failure boundary remains UNKNOWN;
see [secondboot post-mortem](../research/device/current/boot/secondboot-postmortem.md).

The later read-only runtime check found no common Android recovery descriptor,
install script, recovery patch, or pending recovery command at the checked
paths.  It also found no `/dev/block/mmcblk0boot0`, `mmcblk0boot1`, or
`mmcblk0rpmb` device node.  This limits the accessible golden backup to the
eMMC user area; it does not identify the bootloader's own storage model.

`ro.bootloader` currently returns `unknown`.  This is a legacy-ROM property
value, not evidence of either a locked or unlocked Sony bootloader. It is
separate from the direct S1Boot fastboot observation documented above.
See the [sanitized runtime check](../research/device/current/boot/recovery-runtime-check.txt)
for the exact checked paths and property values.

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
| Current Hikari legacy artifact layout | `VERIFIED_DEVICE` through private offline p3 copy | Documented in `BOOT_FORMAT.md`; not a target-Linux artifact specification. |
| Recovery partition identity and recovery route | UNKNOWN | TWRP was observed, but cannot be assumed independent of p3. |
| TWRP presence | `VERIFIED_DEVICE`: TWRP 2.6.3.0 recovery runtime | It is not yet a proven independent rollback route. |
| Bootloader state | `secure: no`; empty legacy `unlocked` variable | Owner history and evidence are consistent with an unlocked state, but no standard unlocked attestation exists. |
| Persistent logs | legacy ram_console at `0x7ffe0000` was observed | A target kernel must be designed to preserve/retrieve logs only after approval. |

## Safest first experimental-boot path (not authorized or executed)

Do not flash or fastboot-boot under the current authorization. Before any
experimental boot, the owner must
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
