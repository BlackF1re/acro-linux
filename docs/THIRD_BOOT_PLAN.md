# Third Hikari boot iteration — local build gate

## Narrow purpose

The second Sony ELF used both `0x40200000` as the DTS memory base and
`CONFIG_ARCH_QCOM_RESERVE_SMEM=y`. Current upstream reserves the first 2 MiB
of *System RAM* for MSM8x60 when that option is selected. This likely shifted
the target kernel one additional 2 MiB from the Hikari legacy-compatible
address.

This iteration changes only the target memory model and the initramfs marker:

- physical low memory node: `0x40000000-0x42dfffff`;
- upstream-reserved SMEM: `0x40000000-0x401fffff`;
- `PHYS_OFFSET`: `0x40000000`;
- upstream `TEXT_OFFSET`: `0x00208000`;
- Sony ELF zImage + appended DTB load candidate: `0x40208000`;
- initramfs marker: `HIKARI MAINLINE BOOT #3`.

The address model is an evidence-backed bootstrap hypothesis, not yet a
`VERIFIED_DEVICE` target-Linux claim. Its sources are current upstream ARM and
Qualcomm Kconfig/Makefiles, historical OpenSEMC MSM8x60 shared-memory code,
and the verified legacy p3 zImage load address. See
[FIRST_BOOT_MEMORY.md](FIRST_BOOT_MEMORY.md) and
[SOURCES.md](SOURCES.md).

## Required offline gates

The artifact must be built outside Git and pass all of the following:

1. `CONFIG_ARCH_QCOM_RESERVE_SMEM=y` and `CONFIG_PHYS_OFFSET=0x40000000`.
2. Hikari DTB is present and byte-appended after the built zImage.
3. The ARM decompressor model accounts for its self-relocation and rejects
   overlaps among SMEM, decompressed kernel, relocated code/DTB and initramfs.
4. Sony ELF program headers are valid, use only kernel/ramdisk/RPM segment
   classes, and total size remains below p3's 20 MiB capacity.
5. The original p3 restore artifact still matches its verified SHA-256.

No command in this document authorizes ADB, reboot, fastboot or any write to
the phone. A future physical attempt requires a separate owner approval after
reviewing the resulting exact artifact hash and diagnostics plan.

## Resulting local artifact

The completed third artifact is deliberately outside Git:

- ELF: `/home/paul/xperia/build/hikari-artifacts-g5/hikari-thirdboot.elf`
- Size: 11,939,082 bytes
- SHA-256: `6775d7910d791e123ccf044ae2f7182187da342a0f7b0b977d1ccf1dfcbd6c4be`
- zImage plus appended DTB SHA-256:
  `88178a1e03008a634583cc3af7084efbeca229d7f94dae509fd6524624edd82c`
- DTB SHA-256: `ce99ca74d62b5b7ca18246294065c93b6e1c5bbcfec1bdaa95b62983426a8acd`
- initramfs SHA-256:
  `fa6e7d74d1a663893f3dadd73783b339127c06a0a6344f550facaeaf523d5162`

Its Sony ELF segments are kernel plus appended DTB at `0x40208000` (10,847,526
bytes), native initramfs at `0x42a00000` (1,098,556 bytes), and the private
legacy RPM payload at `0x00020000` (119,784 bytes).  The project ELF and
artifact validators passed, as did the corrected memory gate.  This is a
local-build result only: there is no authorization here to flash it.

## Diagnostic limitation

The initramfs leaves a native BusyBox shell after emitting its marker and
runtime information. It does not mount Android storage. An externally
accessible Hikari UART/USB diagnostic path is still unproven, so a black screen
or lack of USB would again be `BOOT_PROOF=NOT_OBSERVED`, not proof that the
kernel did not execute.
