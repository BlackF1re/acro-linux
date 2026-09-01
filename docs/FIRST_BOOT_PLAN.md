# First native-Linux boot: proposal gate, not execution authorization

No kernel, fastboot `boot`, flash, or other phone deployment has been
performed. A local-only upstream kernel, Hikari DTB, native initramfs and Sony
ELF prototype have been built and validated; this plan still selects no device
deployment route until the owner reviews it.

## Candidate ranking

| Candidate | Status | Reason |
| --- | --- | --- |
| A. `fastboot boot` with a temporary Sony ELF | Not selected: `UNKNOWN` | Exact S1Boot `boot` support and its non-persistent semantics are not proven. |
| B. Independent recovery/FOTA route | Not selected: `UNKNOWN` | TWRP 2.6.3.0 exists, but its storage/boot-path independence from p3 is unproven. |
| C. Temporary chainload | Not selected: `UNKNOWN` | No evidence-backed mechanism has been found. |
| D. Controlled replacement of p3 | Conditional future candidate | p3 role, exact image format, backup and S1Boot access are known; it still requires an independently acceptable rollback route and explicit owner approval. |

Thus the safest present action is **further offline recovery-path research**, not an experimental boot. If it proves a rollback path independent of p3, the first later experiment may use candidate D with a single whitelisted p3 write.

## Required artifact contract

1. Use a Sony ELF32 ARM container compatible with the verified Hikari p3 structure. The current legacy reference has zImage at `0x40208000`, ramdisk at `0x41800000`, and RPM-marked payload at `0x00020000`; these are the strongest known-compatible starting candidates, not immutable mainline requirements. Any selection must validate decompressor, DTB, initramfs, firmware, reserved-memory and segment non-overlap.
2. Use `kernel/dts/qcom-msm8260-sony-hikari.dts` with
   `kernel/configs/hikari-firstboot.fragment`: an appended DTB, ARM ATAG-to-DT
   compatibility and native diagnostic initramfs. The exact legacy cmdline
   producer is still unknown. The prototype deliberately supplies no new
   `CONFIG_CMDLINE`; it preserves a bootloader ATAG command line only if one
   exists through `CONFIG_ARM_ATAG_DTB_COMPAT_CMDLINE_EXTEND`.
3. Build the smallest diagnostic ARMv7 kernel and initramfs only after an implementation phase is approved. Include no Android userspace.
4. Establish the required firmware payloads and their licensing/provenance; do not blindly reuse the private legacy p3 RPM payload.
5. Use the MSM serial-console configuration only as a diagnostic candidate:
   no physical serial route is yet verified. The initramfs emits an
   unmistakable marker on its active console. No target ramoops/pstore region
   is enabled until memory ownership is proven; legacy `ram_console` is only a
   lead. Preserve USB/physical serial diagnostics as an independent channel.
6. Record artifact SHA-256, exact size and program headers before deployment.

## Current local-only prototype

- Upstream source: Linus Linux `786262be6048deab760f68c8acc2c85607165894`.
- DTB method: appended `qcom-msm8260-sony-hikari.dtb`; the input tail is
  checked byte-for-byte by the host-only validator.
- Initramfs: native static BusyBox diagnostic `/init`, SHA-256
  `b290c36ae4595e4d37a851221d92bef14821ccf877910b4df177a62bfb3103c5`.
- Private local RPM input: the original p3 segment only; it is not in Git and
  has not been sent to the phone.
- ELF32 prototype: `11,937,690` bytes, SHA-256
  `cecf280c62023619274bff43ea370619c9d59f3272e0e4436ab2895481461f0e`.
  Segment 0 is the appended-DTB zImage at `0x40208000` (`0xa380e0` bytes),
  segment 1 is the initramfs at `0x41800000` (`0x10c2d2` bytes), and segment 2
  is the private RPM ELF at `0x00020000` (`0x1d3e8` bytes). It is within the
  20 MiB p3 capacity and has no ELF load-address overlap.

These are local format checks, not proof that the decompressor, bootloader or
target memory reservation accepts the artifact.

## Rollback and abort gate

- Original p3 reference: SHA-256 `c59be74873aa32a8422adf9b5402254b2acae619f7dc97bd50fc0e120984d0c1`, private backup offset 4,194,304 bytes, size 20,971,520 bytes.
- The full private user-area backup covers the p3 bytes, but it is a live capture and not an atomic filesystem snapshot.
- Do not write p3 until recovery/fastboot rollback is demonstrated or the owner explicitly accepts its remaining limitations.
- Abort immediately on device-identity mismatch, changed partition layout, unavailable backup, unknown artifact hash/format, missing diagnostics, or loss of the agreed rollback route.
- A separate owner approval must name the exact artifact, target partition, rollback procedure and stop conditions.
