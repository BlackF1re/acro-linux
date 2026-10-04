# Reproducible build and deployment

## Canonical state

Reuse these paths; do not create timestamped source, object or rootfs copies:

- source: `/home/paul/xperia/src/linux`
- kernel objects: `/home/paul/xperia/build/linux-hikari-current`
- Debian rootfs: `/home/paul/xperia/build/hikari-rootfs-current`
- initramfs: `/home/paul/xperia/build/hikari-root-initramfs-current`
- release artifacts: `/home/paul/xperia/build/hikari-debian-current`

The BOOT profile is UP and SYSTEM is SMP. The build helper records the active
profile and runs `make clean` only when switching between them; builds within
one profile remain incremental.

## SYSTEM

```sh
scripts/build-hikari-debian-rootfs.sh
scripts/build-hikari-root-initramfs.sh
scripts/build-hikari-debian-kernel.sh
scripts/install-hikari-kernel.sh
scripts/package-hikari-system-update.sh
```

The update archive contains zImage, DTB, initramfs, the exact kernel release
and matching stripped modules. With the phone at BOOT:

```sh
scripts/send-hikari-system-update.sh /dev/ttyACM0
```

For a complete userspace refresh, use
`scripts/send-hikari-rootfs-update.sh /dev/ttyACM0`. It creates only a
temporary compressed stream and deletes it after transfer.

A leaf module may be rebuilt with `scripts/build-hikari-module.sh DRIVER_DIR`.
Hot replacement is allowed only when the driver and hardware state make unload
safe; DT, built-in code and ABI changes require a SYSTEM reboot.

## BOOT

```sh
scripts/build-hikari-root-initramfs.sh
scripts/build-hikari-kexec-loader.sh
OUTPUT=/home/paul/xperia/build/hikari-debian-current/hikari-kexec-loader.elf \
  scripts/build-hikari-debian-elf.sh
```

Before flashing, verify device identity, fastboot mode, p3 size, ELF layout,
artifact hash and size. Flash only logical `boot`. BOOT must then pass the
manual-stop, display, USB ACM/NCM, charging and BOOT→SYSTEM tests in
[TESTING.md](TESTING.md).

## Checks and cleanup

```sh
scripts/check-hikari-debian.sh
git diff --check
git status --short
```

Package caches, obsolete module ABI directories and transient update archives
are removed in place. Do not keep duplicate rootfs trees or old ELF builds.

## Consolidated source checkpoint — 2026-10-04

GitHub publishes one branch, `main`. The kernel is reconstructed from this
repository, rather than from independent unpublished feature branches:

```sh
scripts/materialize-hikari-kernel.sh /path/to/new/linux-hikari
KERNEL_SRC=/path/to/new/linux-hikari scripts/build-hikari-debian-kernel.sh
```

`kernel/patches/series` now contains 17 final subsystem patches. It incorporates
the complete source integration commit
`f7a6e62ff206edff9cee8c04226e85f1102a9a85`, subsequent maintenance cleanup,
and all former strict transforms. Original exports and author metadata remain
in `research/patches/pre-subsystem-series-20261005/`; `post-series` is empty.
The original commit has a verified SSH ED25519 signature, fingerprint
`SHA256:NF7UE1n7G4bcbFLO6CyE9Bz5M4zZh/72LX7EK5a80t8`.
Export/application was checked to reproduce its exact tree:
`0f8c54cd473ea22c13407fd3ec5fb6d91347a0c2`.

This integration includes the A220 KGSL-derived lifecycle implementation,
CPU DVFS, per-core SAW regulators, battery/charging changes, navigation input,
and the complete current board DTS. Canonical DTS files match that commit;
preparation must not overwrite them with an earlier board configuration.
The SYSTEM fragment enables the new CPU and regulator Kconfig symbols.

The latest existing build is recorded in
`kernel/configs/hikari-system-20261004.config` (full resolved configuration).
It contains a local initramfs path; generic builds regenerate that archive.
Configuration SHA256: `11c40e5152639175c01732ffc9787de1b80c8f7a9c31e84e232ff0cba42b9847`.
Release: `7.3.0-rc1-hikari-system+`.
Existing zImage SHA256:
`5d4d56514eae35ab580bc48ee0e25c1f3566b50ad6d5a5fc6d6677f7456819ce`.
These are provenance records, not a new hardware acceptance test.

Mesa remains separate from the kernel: the verified GPU runtime uses Mesa
`7bcaafa20c99ea1dd6c7ba8105da0be4b8044871`, libgallium SHA256
`e907085656c8445aab198f14f7df5b81e4beec4be97e29447acbc6f611e5e428`.
When using an isolated Mesa installation, set all three library/backend paths
(`LD_LIBRARY_PATH`, `LIBGL_DRIVERS_PATH`, `GBM_BACKENDS_PATH`).
The repository Phosh profile requests GLES2; the renderer helper provides a
reversible runtime Pixman recovery option.

BOOT and production SD bundles are not changed by source publication.
Historical test worktrees remain local references, not release branches.

## Maintenance patch audit

See [PATCH-AUDIT.md](PATCH-AUDIT.md). The original integration export is
archived; the final subsystem patches preserve the maintained prepared tree
exactly. Logging cleanup is incorporated in the owning subsystem. Root access, diagnostic packages, BOOT and GPU hardware
sequencing are retained. No maintenance kernel has been deployed as part of
this source cleanup.


## One subsystem per patch — 2026-10-05

The new 17-patch series independently materialized from the pinned upstream
base with all source gates passing. Its entire tree is byte-identical to the
previous 60-mail-patch + 4-transform prepared source:
`e3d73fd2f7bffefd6e42b0ec789d4e0af81fde45`.
The materializer now enforces that tree hash and rejects dirty preparation.
No target code changed; no phone kernel/runtime was installed or restarted.
Existing DT schema defects and physical acceptance limits remain unchanged.
See `kernel/patches/README.md` for ownership and original-to-subsystem mapping.


## Patch-only source preparation — 2026-10-05

The default build/install source is now
`/home/paul/xperia/src/linux-hikari-current`, materialized from the locked
17-patch series. Explicit `KERNEL_SRC` overrides remain available.

```sh
scripts/materialize-hikari-kernel.sh /home/paul/xperia/src/linux-hikari-current
scripts/build-hikari-debian-kernel.sh
```

If the source directory already exists, the materializer refuses to reset it:
use a fresh path and explicit KERNEL_SRC. `prepare-hikari-kernel-tree.sh` is
now a read-only check. It cannot copy DTS, replace source text, delete old
profiles, or edit Makefiles. Board prerequisites already belong to patch
`0017-hikari-board.patch`; missing/divergent files stop the build.

The old `/src/linux` uncommitted source changes were losslessly exported under
`research/patches/direct-source-edits-20261005/` without touching its worktree or
index. They are historical, not a replacement for the latest integrated SYSTEM.
No source change was made to the working kernel or deployed to the phone.

Build and install entry points additionally require the complete clean source
tree to match `HIKARI_PREPARED_TREE`. Unexported C/driver changes are rejected
before compilation or installation, not just divergent DTS. Ignored build
outputs are excluded; the check never resets, stages or edits source.
