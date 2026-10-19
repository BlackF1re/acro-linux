# Build & deployment

> [!IMPORTANT]
> **Build does not mean flash.** Keep the original BOOT and verified SYSTEM recovery bundle unchanged. New kernels are deployed as independent **microSD SYSTEM** candidates.

## Paths in the maintained workspace

| Artifact | Path |
|---|---|
| Kernel source | \`/home/paul/xperia/src/linux-hikari-current\` |
| Kernel objects | \`/home/paul/xperia/build/linux-hikari-current\` |
| Debian rootfs | \`/home/paul/xperia/build/hikari-rootfs-current\` |
| Root initramfs | \`/home/paul/xperia/build/hikari-root-initramfs-current\` |
| Release artifacts | \`/home/paul/xperia/build/hikari-debian-current\` |
| BusyBox source / build | \`/home/paul/xperia/src/busybox\` · \`/home/paul/xperia/build/busybox-hikari-current\` |

These are **owner-workspace paths**, not paths required on every host. Use explicit arguments for a different source checkout. See [Workspace](WORKSPACE.md).

## Reconstruct and compile

\`\`\`sh
# Materialize a NEW source directory from pinned upstream + project patches.
scripts/materialize-hikari-kernel.sh /path/to/new/linux-hikari

# Compile the verified prepared tree.
KERNEL_SRC=/path/to/new/linux-hikari scripts/build-hikari-debian-kernel.sh

# Optional local test suite (not a physical hardware test).
python3 -m unittest discover -s tests
\`\`\`

The materializer refuses to reset an existing tree. The pinned base, patch order and exact source identity are in [\`kernel/source.lock\`](../kernel/source.lock) and [\`kernel/patches/series\`](../kernel/patches/series). Sony/OpenSEMC trees are research references, **not** the production base.

## Assemble a SYSTEM

\`\`\`sh
scripts/build-hikari-debian-rootfs.sh
scripts/build-hikari-root-initramfs.sh
scripts/build-hikari-debian-kernel.sh
scripts/package-hikari-system-update.sh
\`\`\`

| Artifact | When needed |
|---|---|
| SYSTEM bundle | Kernel, DTB, initramfs and **matching** modules |
| Rootfs stream | Debian base / package / system configuration changes |
| Single module | \`scripts/build-hikari-module.sh DRIVER_DIR\` — **only** when source/ABI constraints allow |

> [!NOTE]
> Built-in kernel code, device tree and ABI changes need an appropriately matched SYSTEM boot. Do not mix a newly built kernel with modules from another release.

## Transfer and acceptance

\`\`\`sh
# Operate only through the established BOOT USB transfer path.
scripts/send-hikari-system-update.sh /dev/ttyACM0
scripts/send-hikari-rootfs-update.sh /dev/ttyACM0

# Then run checks appropriate to the selected target/runtime.
scripts/check-hikari-debian.sh
git diff --check
\`\`\`

The transfer path stages received artifacts and verifies hashes. Preserve the previously working SD bundle; transfer success alone does **not** establish a working desktop.

**Next:** [Boot architecture](BOOT.md) · [Recovery gate](RECOVERY.md) · [Physical acceptance](TESTING.md)

> [!CAUTION]
> Never flash BOOT, replace the known-good bundle, kexec directly from SMP SYSTEM, or treat the build scripts as authorization to alter phone partitions.
