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
- `make ... dtbs_check`: completed with no diagnostic for Hikari.  The broad
  Qualcomm DT set still emits unrelated existing diagnostics for other boards;
  direct `dt-validate` of `qcom-msm8260-sony-hikari.dtb`, targeted
  `dt-doc-validate`, `yamllint`, and single-process `dt-check-style` of the
  changed Qualcomm binding all pass with no output.  `dtschema` and its host
  tooling are installed in the isolated build venv, not the global Python.
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
