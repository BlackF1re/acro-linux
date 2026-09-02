# Hikari persistent early-boot logging

## Purpose and operating boundary

Boot attempts one through three had no independently accessible target-Linux
console.  A black display and absent USB therefore did not identify a kernel
failure stage.  Boot #4 uses the physically observed Hikari persistent-console
region so that a failed boot can be examined after restoring p3 and entering
TWRP.  This is diagnostic infrastructure only; it is not a target hardware
acceptance test.

The target write path is mainline `ramoops` console-only storage.  It is
built-in, so it starts before the initramfs.  The boot #4 initramfs adds three
distinctive `/dev/kmsg` markers after `/init` begins, but it never writes the
persistent region directly.

## Physical TWRP evidence

`VERIFIED_DEVICE` observations from TWRP 2.6.3.0, collected read-only on
2026-09-02, are recorded in
[the sanitized recovery evidence](../research/device/current/boot/twrp-persistent-ram-summary.md):

| Item | Observation |
| --- | --- |
| Region | `0x7ffe0000-0x7fffffff`, 131,072 bytes |
| Legacy owner | `ram_console` in `/proc/iomem` |
| Access path | TWRP exposes `/dev/mem`; ordinary `dd` reads are rejected, while read-only 32-bit `busybox devmem` accesses succeed. |
| Captured header | little-endian `DBGC`, `start=0x11f3a`, `size=0x11f3a` |
| ECC | TWRP dmesg reports `Memory policy: ECC disabled`; recovery board data sets every persistent-RAM ECC parameter to zero. |
| Current capture | 131,072-byte private baseline, SHA-256 `77ece199020ac0a6aa5e25493416740c113ff972307819bcbfa7da3ed8c6d9c1` |

The baseline was a later legacy TWRP log, not a mainline attempt.  It proves
the reader location and format, not prior target-kernel execution.

## Exact binary compatibility

The Fuji legacy source defines `MSM_RAM_CONSOLE_START` as `0x80000000 - 128
KiB`, gives its persistent-RAM descriptor all-zero ECC fields, and uses this
header on ARM32:

| Offset | Width | Meaning |
| ---: | ---: | --- |
| `0x00` | 4 | `sig`, little-endian `0x43474244` (`DBGC`) |
| `0x04` | 4 | `atomic_t start`, first byte when the data ring wraps |
| `0x08` | 4 | `atomic_t size`, valid byte count |
| `0x0c` | 131,060 | circular console bytes |

No header-ECC, data-ECC or parity area is present.  The TWRP runtime header
matches this exact layout.

For the project’s pinned upstream Linux revision, `fs/pstore/ram_core.c` uses
the same ARM32 `persistent_ram_buffer` layout and `DBGC` base signature.
`fs/pstore/ram.c` initializes its console zone with signature zero; the core
XOR gives `DBGC`.  The Hikari DT supplies one full-size `console-size` zone
and `ecc-size = <0>`.  Consequently:

`RAMOOPS_TWRP_BINARY_COMPATIBILITY = VERIFIED_COMPATIBLE`.

This classification is deliberately limited to the console-zone header/ring
format and zero ECC.  It does not claim that boot #4 has written a log yet.

At recovery startup legacy `persistent_ram_init_ringbuffer()` saves a valid
old `DBGC` buffer before it initializes a new one.  TWRP should then expose
that saved content as `/proc/last_kmsg`; `/dev/last_kmsg` and pstore paths are
also probed because availability is kernel-specific.  Capture the previous
log **first**.  The later raw `/dev/mem` read independently verifies the
region/header but may already contain TWRP's new console rather than the
previous mainline bytes.

## Host-side independent decoder

[`tools/hikari-persistent-ram.py`](../tools/hikari-persistent-ram.py) accepts
only a host-side raw dump, checks the expected `DBGC` header and bounds, and
reconstructs the ring in chronological order.  Its fixtures are synthetic;
private device RAM is never committed.  It intentionally rejects an unknown
or ECC-enabled layout instead of pretending to decode it.

[`scripts/capture-hikari-ramconsole.sh`](../scripts/capture-hikari-ramconsole.sh)
is a read-only TWRP capture helper.  It reads exactly 32,768 32-bit words from
`0x7ffe0000`, verifies the resulting 131,072-byte size, hashes it, and invokes
the parser.  Captures and reconstructed text remain below the private host
research directory, never in Git.

## Boot #4 mainline configuration and DT

The diagnostic writer is standard upstream ramoops, not an Android
ram_console port:

```text
CONFIG_PSTORE=y
CONFIG_PSTORE_RAM=y
CONFIG_PSTORE_CONSOLE=y
```

The DT node is under `/reserved-memory`, has `reg = <0x7ffe0000 0x20000>`,
`console-size = <0x20000>`, and `ecc-size = <0>`.  It does **not** use
`no-map`, because the console writer must map the storage.  There are no
record, ftrace or pmsg zones competing for the 128 KiB.

`scripts/check-hikari-persistent-ram.sh` is a build gate: it checks all three
built-in Kconfig options plus the exact DTB node, range, console allocation,
zero ECC and absence of `no-map`.

## Limits

The only verification at this point is the recovery reader path and its
format.  `PERSISTENT_LOG_WRITER = IMPLEMENTING`, pending a boot #4 write and
post-reset recovery capture.  A successful mainline log is required before
calling the writer `VERIFIED_DEVICE`.
