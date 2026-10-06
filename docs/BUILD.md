# Build and deployment

## Canonical paths

Use one maintained source/build set; do not create timestamped copies:

- Kernel source: `/home/paul/xperia/src/linux-hikari-current`
- Kernel objects: `/home/paul/xperia/build/linux-hikari-current`
- Debian rootfs: `/home/paul/xperia/build/hikari-rootfs-current`
- initramfs: `/home/paul/xperia/build/hikari-root-initramfs-current`
- release artifacts: `/home/paul/xperia/build/hikari-debian-current`
- BusyBox source/build: `/home/paul/xperia/src/busybox`,
  `/home/paul/xperia/build/busybox-hikari-current`

Production kernel source is pinned upstream Linux plus
[`../kernel/patches/series`](../kernel/patches/series), with its revision in
[`../kernel/source.lock`](../kernel/source.lock). OpenSEMC is a historical
hardware reference and is not part of this build.

## Build

```sh
scripts/build-hikari-debian-rootfs.sh
scripts/build-hikari-root-initramfs.sh
scripts/build-hikari-debian-kernel.sh
scripts/package-hikari-system-update.sh
```

To create a new source tree, materialize into a new path and pass it explicitly:

```sh
scripts/materialize-hikari-kernel.sh /tmp/linux-hikari
KERNEL_SRC=/tmp/linux-hikari scripts/build-hikari-debian-kernel.sh
```

The kernel helper verifies the complete prepared source tree before building.
Build outputs and generated images stay outside the repository. A leaf module
can be rebuilt with `scripts/build-hikari-module.sh DRIVER_DIR`; built-in code,
DT or ABI changes require a SYSTEM reboot.

## Recovery and deployment

The immutable BOOT loads SYSTEM bundles from microSD through kexec. Keep the
known-good bundle and recovery files intact. Test updates only through the
running BOOT transfer path; do not flash or replace BOOT during ordinary
development. Follow [BOOT.md](BOOT.md), [RECOVERY.md](RECOVERY.md) and
[TESTING.md](TESTING.md), and verify artifact hashes before a boot test.

```sh
scripts/send-hikari-system-update.sh /dev/ttyACM0
scripts/send-hikari-rootfs-update.sh /dev/ttyACM0
scripts/check-hikari-debian.sh
git diff --check
```

The system update includes zImage, DTB, initramfs, kernel release and matching
modules. The rootfs updater uses a temporary compressed stream. Do not keep
duplicate rootfs, Mesa source or candidate-build trees after their result has
been recorded in the relevant subsystem documentation.
