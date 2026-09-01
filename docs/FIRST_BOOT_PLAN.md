# First native-Linux boot: proposal gate, not execution authorization

No kernel, DTS, image, fastboot `boot`, or flash operation has been performed. This plan selects an evidence-based candidate only after the next owner review.

## Candidate ranking

| Candidate | Status | Reason |
| --- | --- | --- |
| A. `fastboot boot` with a temporary Sony ELF | Not selected: `UNKNOWN` | Exact S1Boot `boot` support and its non-persistent semantics are not proven. |
| B. Independent recovery/FOTA route | Not selected: `UNKNOWN` | TWRP 2.6.3.0 exists, but its storage/boot-path independence from p3 is unproven. |
| C. Temporary chainload | Not selected: `UNKNOWN` | No evidence-backed mechanism has been found. |
| D. Controlled replacement of p3 | Conditional future candidate | p3 role, exact image format, backup and S1Boot access are known; it still requires an independently acceptable rollback route and explicit owner approval. |

Thus the safest present action is **further offline recovery-path research**, not an experimental boot. If it proves a rollback path independent of p3, the first later experiment may use candidate D with a single whitelisted p3 write.

## Required artifact contract

1. Use a Sony ELF32 ARM container compatible with the verified Hikari p3 structure. The current legacy reference has zImage at `0x40208000`, ramdisk at `0x41800000`, and RPM-marked payload at `0x00020000`; any deviation needs new evidence, not analogy.
2. Build the smallest diagnostic ARMv7 kernel and initramfs only after an implementation phase is approved. Include no Android userspace.
3. Establish the required firmware payloads and their licensing/provenance; do not blindly reuse the private legacy p3 RPM payload.
4. Include early console plus a planned target ramoops/pstore region. Legacy `ram_console` is a lead, not a target reservation. Preserve USB/physical serial diagnostics as an independent channel.
5. Record artifact SHA-256, exact size and program headers before deployment.

## Rollback and abort gate

- Original p3 reference: SHA-256 `c59be74873aa32a8422adf9b5402254b2acae619f7dc97bd50fc0e120984d0c1`, private backup offset 4,194,304 bytes, size 20,971,520 bytes.
- The full private user-area backup covers the p3 bytes, but it is a live capture and not an atomic filesystem snapshot.
- Do not write p3 until recovery/fastboot rollback is demonstrated or the owner explicitly accepts its remaining limitations.
- Abort immediately on device-identity mismatch, changed partition layout, unavailable backup, unknown artifact hash/format, missing diagnostics, or loss of the agreed rollback route.
- A separate owner approval must name the exact artifact, target partition, rollback procedure and stop conditions.
