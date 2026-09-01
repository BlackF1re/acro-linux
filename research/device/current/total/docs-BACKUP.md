# Physical-device backup policy and media topology

## Scope and safety boundary

Before an experimental boot, the golden backup must cover every byte of the
complete eMMC user area, `/dev/block/mmcblk0`.  The captured byte stream covers
the partition table and p1 through p15 without separately inspecting,
parsing, interpreting, exposing, or committing sensitive partition data.  In
particular, TA-related, radio/NV, and calibration-bearing unknown-partition
bytes are present only in the private raw backup.  It is private recovery
material and is never stored in this repository.

Copying such an image is an owner-authorized operation.  The phone-side source
is fixed to `if=/dev/block/mmcblk0`; no backup command may name a phone block
device as an output.  A complete image is accepted only after exact source and
destination size comparison plus SHA-256 verification.  eMMC boot areas and
RPMB, if exposed, require separate handling; neither may be made writable for
this purpose.

## Removable-card reader observation

An owner-supplied microSD was observed in the running legacy baseline as
`mmcblk1` with `mmcblk1p1`, on the distinct MMC host path `mmc1:59b4`.
The host reports device type `SD` and name `NCard`.  This is evidence for the
physical removable-card reader path, independent of the internal eMMC
(`mmcblk0`).

At observation time the card had one NTFS filesystem mounted through Android's
`vold`/FUSE path at `/mnt/media_rw/sdcard1` (user-facing
`/storage/sdcard1`), with approximately 29.5 GiB free.  NTFS itself permits a
single approximately 14.6-GiB raw eMMC image; FAT32 would not, because FAT32
has a 4-GiB file-size limit.  Separately, the particular legacy Android
NTFS/FUSE path used during this operation did not safely support the attempted
single file once it exceeded 4 GiB.  That is an implementation/path limitation
observed during this acquisition, not an NTFS format limitation.  The card
UUID, label, contents, and other unique media metadata are intentionally not
recorded in the repository.

This is a legacy-runtime observation, not an acceptance test of target Linux
microSD support.  Target implementation status remains `UNKNOWN`.

## Storage and handling

Private images, manifests, hashes, and any metadata containing unique device
identifiers belong outside the repository.  Treat a raw image as sensitive: it
can contain personal data, credentials, TA material, radio/NV material, and
calibration data.  Do not inspect such partition contents merely because they
are present in a backup.

The removable-card copy was transport/staging material.  The one canonical,
verified host-side copy is
`/home/paul/xperia/backups/hikari/20260901T111716Z/hikari-golden-backup-20260901T190000Z`.
The outer timestamp directory is the host-side C2 session/staging container;
the nested `hikari-golden-backup-20260901T190000Z` directory is the acquisition
directory and is the canonical backup path.  Retain its hash manifest and keep
the card offline where practical.  No restore procedure is provided or
authorized by this project stage.

## 2026-09-01 golden backup result

The owner explicitly authorized a one-way, read-only copy from the phone's
`/dev/block/mmcblk0` to the removable card.  An initial direct single-file
attempt was stopped after the legacy Android NTFS/FUSE path exhibited unsafe
greater-than-4-GiB behaviour; it is not part of the accepted backup.  The
successful acquisition instead used one continuous phone-side stream:

```
busybox dd if=/dev/block/mmcblk0 bs=4M 2>/dev/null | \
  busybox split -b 1024m - mmcblk0.part-
```

The command record is retained as session provenance, not as an executable
restore recipe.  `split` consumed the single ordered `dd` stream, so the
accepted representation is a sequence of 15 byte-contiguous files:
`mmcblk0.part-aa` through `mmcblk0.part-ao`.  Fourteen parts are 1,073,741,824
bytes each and the final part is 601,882,624 bytes.  Their total is exactly
15,634,268,160 bytes, the observed size of `mmcblk0`.

Each part has an entry in `mmcblk0.parts.sha256`; the phone-side verification
reported every part `OK` before the card was unmounted.  A private host copy
was then made outside the repository.  A later offline audit rechecked all 15
part hashes, their lexical order and lengths, reconstructed the complete stream
without reading the phone, and obtained logical-stream SHA-256
`d3747bbb06de01007014182349c3ddb524fbdfe6b1a77c8749e01bcd86001133`.
The Android-path strings embedded in the original hash manifest are transport
metadata, not a requirement that the card remain mounted at that path;
normalize them to the local directory before using `sha256sum -c` on the host.
Reconstruct the byte stream only in a private location with sufficient free
space, for example:

```
cat mmcblk0.part-* > mmcblk0.img
```

This is an offline reconstruction instruction, not a restore command.  It
must never be redirected to a block device without a separately approved
restore procedure.

This was a live acquisition from a running Android system.  It establishes
full byte coverage of the accessible user area, but it is not guaranteed to be
an atomic filesystem-consistent snapshot: writable mounted filesystems could
have changed while their ranges were read.  The partition table and p1--p15 are
included, and static or rarely changing areas remain valuable recovery
material; writable filesystems may be crash-consistent or inconsistent with
any single instant.  Before future full repartitioning, obtain a second offline
backup from a safely established recovery or temporary minimal environment in
which eMMC filesystems are not mounted read-write.

The running legacy kernel did not expose `mmcblk0boot0`, `mmcblk0boot1`, or
`mmcblk0rpmb` under `/dev/block` at the time of collection.  Consequently the
golden backup fully preserves the accessible eMMC *user area* (including the
partition table and p1--p15), but does not claim coverage of absent/unexposed
eMMC boot hardware areas or RPMB.

`scripts/backup-device.sh` is an unexecuted, reviewable host-side helper for a
future owner-approved backup.  It is Hikari-specific: it refuses a non-LT26w/
Fuji ADB target, accepts only an explicit eMMC read-source whitelist, verifies
the observed user-area size for `mmcblk0`, and refuses destinations in `/dev`
or the repository.  It uses 512-byte sector skip/count values consistently,
writes only to an unmistakable `.partial` host file until all chunks and the
final size validate, reserves space for the temporary chunk plus a safety
margin, and provides no restore path.

## Evidence

- Read-only physical-device snapshot collected via root shell: `/proc/partitions`,
  `/proc/mounts`, `/sys/block/mmcblk1`, and filesystem capacity metadata.
- [Offline backup validation](../research/device/current/storage/backup-offline-validation.txt)
  records the sanitized stream provenance and host-only partition-table check.
- Legacy partition-role provenance remains in
  [PARTITIONS.md](PARTITIONS.md) and its linked sanitized fstab evidence.
