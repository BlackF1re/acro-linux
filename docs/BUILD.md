# Local-only Hikari kernel build

This is an offline development procedure. The scripts have no `adb`,
`fastboot`, USB, flash, reboot, restore, or phone-writing operation. Sources
and generated output remain outside this Git repository.

## Pinned inputs

- Canonical Linux source tree: `/home/paul/xperia/src/linux`.  Its exact HEAD
  is recorded with each artifact; it contains the pinned Linus base plus the
  documented, authorship-preserving MSM8x60 and Hikari bring-up commits.
- BusyBox source tree: `/home/paul/xperia/src/busybox`, commit
  `74ac096e895acd6b02976bb010e9b3511234e899`.
- Canonical active kernel output: `/home/paul/xperia/build/linux-hikari-current`.
- Canonical active initramfs output:
  `/home/paul/xperia/build/hikari-initramfs-current`.
- Canonical active artifact output:
  `/home/paul/xperia/build/hikari-artifacts-current`.
- Private RPM input: the confirmed p3 RPM segment outside the repository.

The Hikari DTS is copied into the external Linux worktree by
`scripts/prepare-hikari-kernel-tree.sh`.  Kernel sources and generated output
remain outside this repository, while project-owned DTS/config/build inputs
remain reviewable here.

Historical `linux-hikari-boot*`, `hikari-artifacts-g*`, and similarly named
directories are immutable experiment records.  They are not alternative
active source trees and must not be selected by default.  New work uses the
three `*-current` locations above, preventing silent builds against a stale
worktree while preserving the exact files used in previous physical tests.

## Reproducible host commands

```sh
./scripts/build-hikari-elf.sh
./scripts/test-sony-elf.sh
./scripts/test-hikari-firstboot-artifact.sh
```

`build-hikari-elf.sh` is the canonical end-to-end entry point.  On a fresh
output directory it first builds the host `gen_init_cpio` helper, then builds
the native static BusyBox diagnostic initramfs, rebuilds the kernel with that
initramfs, appends the Hikari DTB, and constructs a local Sony ELF32 with the
three segment classes observed in p3.  It refuses to overwrite output and
rejects output outside `/home/paul/xperia/build/`. The private RPM binary,
kernel outputs and ELF prototype are never added to Git.

## Validation results at this revision

- `make ... zImage qcom/qcom-msm8260-sony-hikari.dtb`: passed.
- `make ... dtbs`: passed; no DTC warning was emitted for the Hikari DTS.
- Targeted `make O=/home/paul/xperia/build/linux-hikari-current CHECK_DTBS=y
  qcom/qcom-msm8260-sony-hikari.dtb`: passed without a schema warning. The
  missing MSM8660 MMSS SFPB schema, DSI PHY name, controller fallback and
  register-name issues found by this check were fixed rather than suppressed.
- Direct `dt-doc-validate` of the project-added bindings and targeted
  `dt-validate` of the final Hikari DTB also passed. `dtschema` 2026.6 is kept
  in `/home/paul/xperia/build/dtschema-venv`, not global Python.
- The ELF self-test and artifact validator passed. The latter checks the
  original offline p3 hash and size, p3 capacity, appended-DTB tail, ELF32
  header, segment ranges and load-address overlap.
- Exact hashes and ranges of the current local artifact are recorded below and
  must be checked again before any owner-approved deployment.

This establishes local build integrity only. It is neither a boot test nor
authorization to deploy any artifact. The current deployment gate is in
[FIRST_BOOT_PLAN.md](FIRST_BOOT_PLAN.md).

## Corrected third local build

Following post-mortem analysis, the third local build uses the physical MSM8x60
low-memory base `0x40000000`, reserves its first 2 MiB through
`CONFIG_ARCH_QCOM_RESERVE_SMEM=y`, and uses the resulting upstream
`0x40208000` zImage load candidate.  Its initramfs is deliberately moved to
`0x42a00000`.  The exact artifact and code-derived range checks are recorded in
[THIRD_BOOT_PLAN.md](THIRD_BOOT_PLAN.md) and
[FIRST_BOOT_MEMORY.md](FIRST_BOOT_MEMORY.md).  It has not been sent to the
phone.

## Latest locally validated artifact

The current locally validated, **not deployed** artifact is:

```text
/home/paul/xperia/build/hikari-artifacts-g28-display/hikari-display-complete-dsi-quiesce.elf
size:   12,516,938 bytes
SHA-256 d0815b56d7137afd8b97f9f3f14ee718d7240cc946aa1c77986e4d93f56821ff
```

It was built from external kernel tree HEAD
`b44a7cd030f7a5e57ce2f3b3a0190776c3a6548b`. It preserves the verified
memory, RPM, ramoops, stable PID 1, and USB ACM shell foundation. Relative to
g27 it performs the complete source-derived MSM8x60 DSI boot-state teardown:
clear `CLK_CTRL`, clear `CTRL`, stop the 45 nm PLL, flush MMIO, then disable
master, slave, and AMP AHB in Sony order while retaining halt checks. Display
and useful positive-current charging remain unverified until physical
acceptance tests pass.

Its components are:

```text
zImage:     11,276,296 bytes, 2d839ea59a82e326fb8fc607d777a774bd74385baca4035b5304f2f0f15bbe67
zImage+DTB: 11,289,379 bytes, ce0a818ac59ee3f57c666de1793dc594981e85ff14c057df5b4e388b7fe2863b
DTB:            13,083 bytes
initramfs:  1,103,679 bytes, c9a0ea7651ffc6c8c7acb0695764e4278ec38bd984b53381f7cb2f0008ed3894
```

The Sony ELF loads segment 0 at `0x40208000`, segment 1 at `0x42a00000`, and
the private RPM segment at `0x00020000`. All decompressor, appended-DTB,
initramfs, RPM, SMEM and ramoops range gates pass. Passing these checks is
local artifact integrity, not permission to flash or a hardware claim.

The final Sony ELF segment table is:

```text
segment 0: offset 0x001000, paddr 0x40208000, size 0xac4323
segment 1: offset 0xac5323, paddr 0x42a00000, size 0x10d73f
segment 2: offset 0xbd2a62, paddr 0x00020000, size 0x01d3e8
```
