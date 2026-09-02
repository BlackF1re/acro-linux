# Local-only Hikari first-boot build

This is an offline development procedure. The scripts have no `adb`,
`fastboot`, USB, flash, reboot, restore, or phone-writing operation. Sources
and generated output remain outside this Git repository.

## Pinned inputs

- Linux source tree: `/home/paul/xperia/src/linux`, upstream commit
  `786262be6048deab760f68c8acc2c85607165894`.
- BusyBox source tree: `/home/paul/xperia/src/busybox`, commit
  `74ac096e895acd6b02976bb010e9b3511234e899`.
- Build output: `/home/paul/xperia/build/`.
- Private RPM input: the confirmed p3 RPM segment outside the repository.

The Hikari DTS is copied into the external Linux worktree by
`scripts/prepare-hikari-kernel-tree.sh`; it is not an upstream claim and does
not alter the source commit recorded above.

## Reproducible host commands

```sh
./scripts/build-hikari-initramfs.sh
./scripts/build-hikari-kernel.sh
./scripts/build-hikari-elf.sh
./scripts/test-sony-elf.sh
./scripts/test-hikari-firstboot-artifact.sh
```

`build-hikari-elf.sh` composes the zImage and appended DTB, builds a native
static BusyBox diagnostic initramfs, and constructs a local Sony ELF32 with the
three segment classes observed in p3. It refuses to overwrite output and
rejects output outside `/home/paul/xperia/build/`. The private RPM binary,
kernel outputs and ELF prototype are never added to Git.

## Validation results at this revision

- `make ... zImage qcom/qcom-msm8260-sony-hikari.dtb`: passed.
- `make ... dtbs`: passed as part of the build; no DTC warning was emitted for
  the new DTS.
- The relevant Hikari DT is validated directly with `dt-validate` against the
  processed schema and the controller, PHY and RPM regulator bindings. The
  current `dtschema` 2026.6 command-line interface is incompatible with this
  pinned kernel's broad `make dtbs_check` invocation: it reports positional
  DTBs as unrecognized while the kernel intentionally ignores checker exit
  status. This is a host-tool/version integration issue, not a Hikari schema
  pass; it is recorded explicitly and the direct targeted validation is the
  effective BOOT #5 gate. `dtschema` remains in the isolated build venv, not
  the global Python.
- The ELF self-test and artifact validator passed. The latter checks the
  original offline p3 hash and size, p3 capacity, appended-DTB tail, ELF32
  header, segment ranges and load-address overlap.
- Two fresh local ELF builds with fixed `SOURCE_DATE_EPOCH` and `KBUILD_*`
  identity inputs produced byte-identical output, SHA-256
  `cecf280c62023619274bff43ea370619c9d59f3272e0e4436ab2895481461f0e`.

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

## BOOT #5 interactive local artifact

The current locally validated, **not deployed** artifact is:

```text
/home/paul/xperia/build/hikari-artifacts-g7/hikari-boot5-interactive.elf
size:   11964672 bytes
SHA-256 e417d89c32d1bcae9553d83377bce964b840b9a88fc0338bac51e5555fb91ab8
```

It preserves the verified BOOT #4 load model and adds only a persistent PID 1
and the narrow built-in HSUSB peripheral/configfs/CDC-ACM path described in
[USB.md](USB.md).  Display is intentionally absent; its blockers are recorded
in [DISPLAY.md](DISPLAY.md).

To reproduce this artifact from the external source worktree, use explicit
paths rather than shell-profile defaults:

```sh
KERNEL_SRC=/home/paul/xperia/src/linux-hikari-boot5 \
KERNEL_BUILD=/home/paul/xperia/build/linux-hikari-boot5 \
KERNEL_FRAGMENT=kernel/configs/hikari-boot5.fragment \
REQUIRE_USB_DEBUG=1 \
ARTIFACT_DIR=/home/paul/xperia/build/hikari-artifacts-g7 \
OUTPUT=/home/paul/xperia/build/hikari-artifacts-g7/hikari-boot5-interactive.elf \
./scripts/build-hikari-elf.sh
```

The following are required local gates for that exact build: the Sony ELF
inspector, appended-DTB and memory checks in
`test-hikari-firstboot-artifact.sh`, the persistent-RAM check, and
`check-hikari-boot5-interactive.sh`.  Passing them establishes local artifact
integrity only; it does not establish USB or display functionality.
