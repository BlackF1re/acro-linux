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

### Exact legacy TWRP export order

The Fuji recovery-generation `ram_console` driver calls
`persistent_ram_init_ringbuffer()` from `ram_console_probe()`.  In
`__persistent_ram_init()`, a valid, bounds-checked `DBGC` header causes
`persistent_ram_save_old()` to copy the circular bytes into allocated
`old_log`; it **then** writes `DBGC`, `start = 0`, and `size = 0` back to the
physical persistent buffer for the recovery console.  A `late_initcall`
creates `/proc/last_kmsg` only when `persistent_ram_old_size()` is non-zero.

Thus `/proc/last_kmsg` is the primary previous-boot export on this legacy
implementation.  The exact driver contains no `/dev/last_kmsg` exporter;
that path remains a harmless runtime probe because another recovery build
could provide it.  The observed TWRP session had neither endpoint because
the pre-existing signature was `0xc0c0c0c0`, not `DBGC`, so no `old_log` was
created.  This agrees with TWRP's `persistent_ram: no valid data in buffer`
message.

Capture `/proc/last_kmsg` and then `/dev/last_kmsg`, if present, **before any
other recovery diagnostics**.  A later raw `/dev/mem` read is explicitly
classified as `CURRENT_RECOVERY_PERSISTENT_BUFFER`: it is useful for header,
format and troubleshooting analysis, but is not evidence of previous-boot
content unless independently tied to a pre-reinitialization capture.

## Host-side independent decoder

[`tools/hikari-persistent-ram.py`](../tools/hikari-persistent-ram.py) accepts
only a host-side raw dump, checks the expected `DBGC` header and bounds, and
reconstructs the ring in chronological order.  Its fixtures are synthetic;
private device RAM is never committed.  It intentionally rejects an unknown
or ECC-enabled layout instead of pretending to decode it.

[`scripts/capture-hikari-ramconsole.sh`](../scripts/capture-hikari-ramconsole.sh)
is a read-only TWRP capture helper.  After `adb wait-for-device`, it first
checks and immediately copies `/proc/last_kmsg` and `/dev/last_kmsg` if they
exist, requiring each saved file to be non-empty and recording its size and
SHA-256.  Only then does it save recovery `dmesg` and `/proc/iomem`, emit a
private `grep -Ei 'found existing buffer|persistent_ram|ram_console'` status
file, and read exactly 32,768 32-bit words from `0x7ffe0000`.  The latter
131,072-byte raw capture is named and reported as the current recovery
persistent buffer.  Captures and reconstructed text remain below the private
host research directory, never in Git.

The boot #4 diagnostic success criterion is therefore: mainline ramoops
writes a compatible `DBGC` ring; after a warm reset and p3 restore, TWRP logs
an existing buffer and exports the previous mainline log through
`/proc/last_kmsg` (or, only if provided by that recovery build,
`/dev/last_kmsg`).  Raw `/dev/mem` is a secondary integrity/troubleshooting
capture, not the primary post-mortem source.

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

## Local validation

The local boot #4 build passed `make dtbs`, the Hikari-specific persistent-RAM
gate, appended-DTB gate, Sony-ELF validator and a direct `dt-validate` of the
built `qcom-msm8260-sony-hikari.dtb` against the pinned build's processed
schema.  A scoped `make dtbs_check` completed with the current host
`dtschema` 2026.6 after using colon-separated schema limits; it reported two
pre-existing `qcom.yaml` violations for the unrelated OnePlus Bacon DTB.  It
reported no Hikari diagnostic.  The Hikari DTB's direct schema validation is
therefore the relevant clean result; no warning was suppressed or disabled.

## Limits

The only verification at this point is the recovery reader path and its
format.  `PERSISTENT_LOG_WRITER = IMPLEMENTING`, pending a boot #4 write and
post-reset recovery capture.  A successful mainline log is required before
calling the writer `VERIFIED_DEVICE`.
