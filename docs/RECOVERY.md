# Recovery & destructive-operation safety

> [!CAUTION]
> **A reachable recovery menu is not a verified independent rollback path.** The current BOOT / p3 is the project's recovery anchor; ordinary development must not overwrite it.

## What is actually established?

| Evidence | Status / limit |
|---|---|
| eMMC user-area backup | Complete accessible user area was read to **private** recovery media; **boot0/boot1/RPMB not covered** |
| Sony p3 | Confirmed legacy BOOT role; controller and packaged recovery ramdisk inspected offline |
| TWRP | **TWRP 2.6.3.0 physically reached**; where it resides and whether it survives p3 replacement remain **unknown** |
| Recovery through p11 | p3 controller references an ELF on **p11**; the actual p11 payload was **not separately inspected** |
| Bootloader unlock state | Fastboot \`secure: no\` observed, but legacy \`unlocked\` value empty; not complete attestation |
| Generic p3 restore | **Not established as a validated independent route** |

A private image may contain TA-related, radio/NV or calibration data. Raw partitions, sensitive payloads, firmware and identifiers are **not** committed.

## Current safe workflow

\`\`\`mermaid
flowchart TD
  A["Known-good BOOT"] --> B["Experiment on microSD SYSTEM"]
  B --> C{"Test result"}
  C -->|pass| D["Record build + physical evidence"]
  C -->|fail| E["Hardware reboot → BOOT"]
  E --> F["Preserve logs / restore known-good SD bundle"]
\`\`\`

- Keep BOOT and the previous working SYSTEM bundle unchanged.
- **Never** kexec from running SMP SYSTEM into the UP/BOOT environment.
- Use BOOT's USB shell / transfer path for candidate bundles; preserve pstore before discarding evidence.
- [Boot architecture](BOOT.md) · [Testing](TESTING.md) · [Partition map](PARTITIONS.md)

## Original p3 recovery selector

Offline inspection of the confirmed p3 \`bootrec\` controller established:

- It listens to \`/dev/input/event0\` for a **fresh event** during a **three-second** window.
- Device/input history maps that event to **Volume Up**.
- A recovery choice reads an ELF from \`mmcblk0p11\` and starts its ramdisk \`/init\`; the p3-packaged TeamWin ramdisk is replaced in this path.
- The expected key operation is to **repeat Volume Up** across the first 3–5 seconds, not merely hold it before the event device opens.

> [!WARNING]
> The input sequence was derived from the **p3 artifact** and matching historical sources, **not accepted as a reproducible S1Boot-to-recovery physical procedure**. An attempt booted Android instead. A separate later entry into TWRP confirms TWRP is reachable, **not independent of p3**.

Read [sanitized p3 bootrec](../research/device/current/boot/p3-bootrec-sanitized.txt) and [recovery observations](../research/device/current/boot/recovery-characterization.md).

<details>
<summary><strong>Read-only research boundaries</strong></summary>

The read-only legacy investigation saw \`/fstab.semc\` and \`/init.semc.rc\`, but none of the checked conventional Android recovery files. Their absence cannot exclude other Sony FOTA paths.

Private full-user-area backup physically covers p1–p15, but their **contents were not individually interpreted**; no claim is made about unobserved partition roles. p11's exact payload and recovery independence remain unverified.

Android \`ro.bootloader=unknown\` does not establish lock state. Owner-supplied history and fastboot observations are relevant but not complete authorization.

</details>

## Mandatory gate for a future internal write

- [ ] Exact connected-device identity and partition geometry checked.
- [ ] **Independent** restore path proven without relying on the partition being modified.
- [ ] Critical accessible storage backed up, checksums checked, restore documented.
- [ ] One explicit target partition, artifact format/hash, and whitelist.
- [ ] Early console / persistent logging, stop conditions and rollback decision recorded.
- [ ] **Separate explicit owner approval for that specific destructive stage.**

> [!IMPORTANT]
> Only the confirmed legacy boot-role **p3** is even a *candidate* for a future narrow experiment, and it remains **prohibited** until **every gate above** is satisfied. **Never** include TA, bootloader, partition tables, modem/baseband, radio/NV, calibration, recovery or unknown partitions in a generic flash operation.

## Crash logging

Legacy dmesg records a 128 KiB \`ram_console\` allocation at \`0x7ffe0000\`. This does **not** prove a modern kernel can reuse that memory unchanged. Verify pstore/ramoops and bootloader retention before changing reservations; never assume an address is safe.
