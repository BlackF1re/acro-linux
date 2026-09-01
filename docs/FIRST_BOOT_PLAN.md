# First native-Linux boot: proposal gate, not execution authorization

No kernel, fastboot `boot`, flash, or other phone deployment has been
performed. A local-only upstream kernel, Hikari DTB, native initramfs and Sony
ELF prototype have passed the final host-side gates. Deployment still requires
a new explicit owner approval.

## Candidate ranking

| Candidate | Status | Reason |
| --- | --- | --- |
| A. `fastboot boot` with a temporary Sony ELF | Not selected: `UNKNOWN` | Exact S1Boot `boot` support and its non-persistent semantics are not proven. |
| B. Independent recovery/FOTA route | Not selected: `UNKNOWN` | TWRP 2.6.3.0 exists, but its storage/boot-path independence from p3 is unproven. |
| C. Temporary chainload | Not selected: `UNKNOWN` | No evidence-backed mechanism has been found. |
| D. Controlled replacement of p3 | Selected conditional candidate | Official historical LT26 evidence maps `boot` to p3 and historical LT26/Hikari material uses `fastboot flash boot`; exact original p3 and independent physical S1Boot entry exist. It remains untested as a write on this handset and needs explicit owner approval. |

Thus the next action, if separately approved, is the one-write candidate D
procedure in [FIRST_PHYSICAL_BOOT.md](FIRST_PHYSICAL_BOOT.md), with a single
whitelisted p3 `boot` write and an exact original-p3 rollback artifact.

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
  `03e6d9597a613f6218de756ef8000661f611f1ef678ee278fbdf976af6a1a855`.
- Private local RPM input: the original p3 segment only; it is not in Git and
  has not been sent to the phone.
- ELF32 prototype: `11,937,605` bytes, SHA-256
  `467d08a2fbafe86c61f5422946115a899f3bfa559f429d79dd13f9867ceb046f`.
  Segment 0 is the appended-DTB zImage at `0x40208000` (`0xa3807e` bytes),
  segment 1 is the initramfs at `0x42400000` (`0x10c2df` bytes), and segment 2
  is the private RPM ELF at `0x00020000` (`0x1d3e8` bytes). It is within the
  20 MiB p3 capacity and has no ELF load-address overlap.

The explicit decompressor and range gate passes for these exact inputs; see
[FIRST_BOOT_MEMORY.md](FIRST_BOOT_MEMORY.md). These are still host-side
checks, not proof that the bootloader accepts the artifact or that Linux boots.

## Rollback and abort gate

- Original p3 reference: SHA-256 `c59be74873aa32a8422adf9b5402254b2acae619f7dc97bd50fc0e120984d0c1`, private backup offset 4,194,304 bytes, size 20,971,520 bytes.
- The full private user-area backup covers the p3 bytes, but it is a live capture and not an atomic filesystem snapshot.
- The bootloader-level p3 route is strongly supported by historical LT26 evidence, but not physically write-tested here.  Do not write p3 until the owner explicitly accepts that remaining limitation.
- Abort immediately on device-identity mismatch, changed partition layout, unavailable backup, unknown artifact hash/format, missing diagnostics, or loss of the agreed rollback route.
- A separate owner approval must name the exact artifact, target partition, rollback procedure and stop conditions.
