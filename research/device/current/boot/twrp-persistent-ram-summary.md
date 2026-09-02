# TWRP persistent-RAM reader evidence

Evidence level: `VERIFIED_DEVICE` for the described recovery runtime and
read-only access.  The raw capture is private and intentionally not in Git.

## TWRP 2.6.3.0 observations (2026-09-02)

TWRP exposes `/dev/mem` as a root-owned character device.  A normal `dd`
read of the reserved range failed with `Bad address`; read-only 32-bit
`busybox devmem` accesses to the same physical address succeeded.  A host
loop read exactly `0x20000` bytes at `0x7ffe0000` and reconstructed a private
little-endian binary.  No phone state was modified.

| Item | Value |
| --- | --- |
| Range in `/proc/iomem` | `0x7ffe0000-0x7fffffff : ram_console` |
| Region size | 131,072 bytes (`0x20000`) |
| Header signature | `DBGC` (`0x43474244`, little-endian) |
| Header `start` / `size` at capture | `0x11f3a` / `0x11f3a` |
| TWRP dmesg | `Initialized persistent memory from 7ffe0000-7fffffff` |
| ECC result | `Memory policy: ECC disabled` |
| Private raw size / SHA-256 | 131,072 bytes / `77ece199020ac0a6aa5e25493416740c113ff972307819bcbfa7da3ed8c6d9c1` |

The captured buffer contains a legacy TWRP boot record, not a mainline boot
attempt.  It must not be used to identify the failure stage of boot #3.

At this TWRP invocation `/dev/last_kmsg`, `/proc/last_kmsg`,
`/proc/ram_console`, and `/sys/fs/pstore` were absent.  TWRP had earlier
reported an invalid pre-existing signature (`0xc0c0c0c0`), so it had no valid
old buffer to publish.  A valid mainline `DBGC` console should instead be
captured by the legacy old-buffer path before the raw region is reinitialized;
this remains to be verified on a future owner-approved boot.
