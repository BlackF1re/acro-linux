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
