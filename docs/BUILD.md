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
  `dt-validate` of the final Hikari DTB also passed. `dtschema` 2026.6 is
  installed in an isolated `pipx` environment, not global Python.
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
/home/paul/xperia/build/hikari-artifacts-g34-display/hikari-display-scm-provider.elf
size:   12,519,195 bytes
SHA-256 82979892a9a431bec11b8e75cb8648acab8212cd79414c0f81840c4c5fdb32fc
```

It was built from signed external kernel tree HEAD
`073f7ab967d08d6c60f9c491e7ac2fa81fb1600f`. It preserves the verified
memory, RPM, ramoops, stable PID 1, and USB ACM shell foundation. The
source-derived firmware-state reset now runs exactly once during DSI probe,
with a tracked common-clock-framework reference held across the operation.
The three MSM8x60 DSI AHB clocks remain referenced for this early bring-up
artifact, so ordinary runtime suspend/resume cannot repeat the destructive
reset or enter the physically failing branch-disable path. Driver removal and
probe unwind release the reference. This deliberately trades display-block
idle power for deterministic bring-up; it is not the final runtime-PM policy.
Display and useful positive-current charging remain unverified until physical
acceptance tests pass. In addition to the `MDP_GDSC` relationship it now
reproduces the exact Sony/C.A.F. eight-clock MDP footswitch initialization.
MDP4 refuses MMIO if clock preparation fails and probes MDP4/DSI asynchronously
as a USB-console fail-safe. Physical g33 evidence then showed the secure-MMCC
driver deferred before probe because the DT contained no SCM platform device;
the early architecture convention message was insufficient. This artifact
adds `qcom,scm-msm8660` with the required RPM Daytona core clock. It is a narrow
correction for the observed supplier boundary, not a display acceptance claim.
The initramfs also installs three read-only reports for general hardware,
display, and power/charging diagnosis. It retains the same BusyBox binary and
408-applet set.

Its components are:

```text
zImage:     11,277,096 bytes, 82c31ad9075c2dacadfdeee1ec0ee693acb88ee29315f8cfd1c81229dd4d7932
zImage+DTB: 11,290,325 bytes, cbdbf9d7d388cb9258b6c06fed7051d1ee5d9cf49867f95ed412a7716157d736
DTB:            13,229 bytes
DTB SHA-256: 91a672b32e3dfd06f83e5385a1ba081a03b442b85ace12da9b9ae3246f9abd09
initramfs:  1,104,990 bytes, 0481f7e2764ba10fb2a70e1f07983df5e0d09ad7c656c3686223e0aa3777b690
```

The Sony ELF loads segment 0 at `0x40208000`, segment 1 at `0x42a00000`, and
the private RPM segment at `0x00020000`. All decompressor, appended-DTB,
initramfs, RPM, SMEM and ramoops range gates pass. Passing these checks is
local artifact integrity, not permission to flash or a hardware claim.

The final Sony ELF segment table is:

```text
segment 0: offset 0x001000, paddr 0x40208000, size 0xac46d5
segment 1: offset 0xac56d5, paddr 0x42a00000, size 0x10dc5e
segment 2: offset 0xbd3333, paddr 0x00020000, size 0x01d3e8
```
