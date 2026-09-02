# Boot #4 mainline post-mortem (sanitized)

Evidence level: `VERIFIED_DEVICE` for mainline execution and the persistent
logging handoff. The complete previous-boot export remains private; no raw log,
serial number, TA-related command-line value, or other unique identifier is in
Git.

## Acquisition

The approved `hikari-boot4-debug.elf` was accepted by the handset's S1Boot
logical `boot` target. After restoring the exact original p3 artifact, the
owner entered TWRP directly, without Android userspace. TWRP reported:

```text
persistent_ram: found existing buffer, size 11117, start 11117
```

TWRP exported the previous ring as `/proc/last_kmsg`. The private host capture
is 11,161 bytes and has SHA-256
`b07da0bc6b7befa473fa68b26cec070805450eca2ed835c3ab07a7088e916e42`.
The `adb shell` fallback normalized only transport-added CRLF endings and then
matched TWRP's reported 11,161-byte endpoint length exactly. `/dev/last_kmsg`
was absent.

`POSTMORTEM_BOOT4 = VERIFIED` and
`PERSISTENT_LOG_WRITER = VERIFIED_DEVICE`.

## Runtime timeline

| Stage | Evidence | Result |
| --- | --- | --- |
| ARM zImage/decompressor handoff | `Booting Linux on physical CPU 0x0` begins the recovered log. | Completed sufficiently to execute mainline kernel. |
| Mainline kernel | `Linux version 7.3.0-rc1-g786262be6048-dirty`. | `VERIFIED_DEVICE` execution. |
| Hikari FDT | `OF: fdt: Machine model: Sony Xperia acro S (Hikari)`. | DTB accepted. |
| RAM / SMEM-compatible layout | Normal RAM begins at `0x40200000`; the log includes the two historical banks `0x40200000..0x42dfffff` and `0x48000000..0x7fefffff`. | Consistent with the corrected layout; the boot #2 `0x40408000` double-offset is not used. |
| SMP | `SMP: Total of 2 processors activated`. | Both CPUs reached kernel bring-up. |
| Ramoops | `ramoops: using 0x20000@0x7ffe0000, ecc: 0`; pstore registered its backend. | Compatible persistent writer registered. |
| RPM | `qcom_rpm 104000.rpm: RPM firmware 2.0.102`. | RPM payload is accepted far enough for driver probe. |
| Initramfs | `Trying to unpack rootfs image as initramfs`; later `Freeing initrd memory`. | Unpacked. |
| `/init` | `Run /init as init process`. | `VERIFIED_DEVICE`; target lifecycle is `BOOTS` at the initramfs boundary. |
| Termination | `Kernel panic - not syncing: Attempted to kill init! exitcode=0x00000000`. | Deterministic diagnostic-init failure, not an unexplained early hang. |

The console contains no `HIKARI_*` initramfs marker. The most direct
evidence-backed explanation is that PID 1's BusyBox shell exited after the
script reached `exec /bin/sh`; the observed zero exit code triggered the
kernel's required panic path. This is not a display, DT, SMEM, decompressor or
ramoops failure.

## Boundaries

`LAST_CONFIRMED_STAGE = /init executed as PID 1`.

`FIRST_UNCONFIRMED_STAGE = initramfs diagnostic shell remains alive and emits
its userspace markers`.

No target peripheral is marked working by this result. The one next technical
change for a later owner-approved iteration is to make PID 1 persist (for
example, an explicit initramfs wait loop rather than an interactive shell that
can exit without a console), while retaining the proven ramoops path.
