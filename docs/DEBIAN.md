# Native Debian architecture

## Status and purpose

`IMPLEMENTING`: the project is moving from a diagnostic BusyBox-only runtime
to a current minimal Debian `armhf` root filesystem. The physically verified
display, framebuffer console and dual-role USB path remain the rescue
foundation. A generated rootfs or successful cross-build is not a device
verification.

Debian supplies maintained userspace and package management. It does not
replace the Hikari kernel patches, Device Tree or matching kernel modules.

## Boot layers

1. Sony S1 loads the known-good ELF from eMMC p3.
2. Its full mainline kernel, DTB and small Hikari initramfs start.
3. The initramfs mounts `LABEL=HIKARI_ROOT` (overridable with
   `hikari.root=...`) and executes `switch_root`.
4. Debian systemd loads late hardware modules from `/lib/modules`.

The first Debian root target is a separate microSD. No eMMC partition-table
write is part of this stage. After removable storage is physically verified,
the same rootfs can later move to an explicitly approved internal partition.

Preparing a card is deliberately outside the build and requires both the exact
whole-disk path and an erase token. Inspect the printed identity before running
this destructive command:

```sh
lsblk -o NAME,MODEL,SERIAL,SIZE,TYPE,RM,MOUNTPOINTS
sudo scripts/prepare-hikari-microsd.sh /dev/sdX \
  I-UNDERSTAND-THIS-ERASES-/dev/sdX
```

The helper refuses non-removable or mounted disks and the disk backing the host
root filesystem. It creates one DOS type-83 partition beginning at 4 MiB,
formats it ext4 as `HIKARI_ROOT`, copies the one canonical rootfs, and performs
a read-only filesystem check. This does not make any eMMC change.

## What remains built in

The boot and rescue boundary must work without `/lib/modules`: CPU/SoC basics,
clocks, regulators, PMIC, eMMC/microSD, DOS partitions, ext4, devtmpfs,
display/fbcon, USB gadget/host/role switching, charging coordination, pstore
and the USB terminal. Display and Adreno share DRM/MSM infrastructure, so
turning that infrastructure into a late module would regress the known-good
visible rescue console.

Leaf hardware under active bring-up is modular: Wi-Fi, Bluetooth, NFC, RMI4
touch and motion sensors. More devices should move to modules only after their
probe ordering and rescue implications are understood.

The Debian builder also removes the hundreds of unrelated modules enabled by
the multi-board `qcom_defconfig`, then restores only the modules named by the
Hikari fragment and dependencies selected by Kconfig. Stale object files may
remain harmlessly in the one incremental build directory, but they are not
installed into Debian and are not rebuilt on later runs.

## Build and update workflow

All generated state is reused in place:

```sh
scripts/build-hikari-debian-rootfs.sh
scripts/build-hikari-debian-kernel.sh
scripts/install-hikari-kernel.sh
scripts/build-hikari-debian-elf.sh
```

The only kernel object directory is
`/home/paul/xperia/build/linux-hikari-current`; the only root tree is
`/home/paul/xperia/build/hikari-rootfs-current`. Do not create timestamped
copies. `/boot/hikari-next` contains only the currently staged next kernel.
The first completed `trixie`/`armhf` minbase tree is 207 MiB with 110 package
records and 20 stripped Hikari leaf-driver/dependency modules. These numbers
are a host-build checkpoint, not a permanent package-count requirement.

For a modular driver change that does not alter Kconfig, exported ABI or DT:

```sh
scripts/build-hikari-module.sh drivers/nfc
```

After synchronising the changed module to the phone, it may be unloaded and
reloaded if hardware state permits. Otherwise one reboot is required, but no
fastboot flash is required.

## Kernel and DT updates without fastboot

The Debian profile enables ARM kexec and installs `hikari-kexec`. MSM8x60's
upstream SMP implementation can start CPU1 but cannot completely power it down,
so an SMP first-stage kernel is deliberately rejected by ARM kexec. The stable
p3 rescue/loader kernel is therefore built with `CONFIG_SMP=n`: CPU1 remains in
the bootloader's reset state until the second-stage SMP kernel starts it through
the normal SCM path. Build that loader in the same source and output trees:

```sh
scripts/build-hikari-kexec-loader.sh
OUTPUT=/home/paul/xperia/build/hikari-debian-current/hikari-kexec-loader.elf \
    scripts/build-hikari-debian-elf.sh
```

The safe sequence on the phone is:

```sh
hikari-kexec --check
hikari-kexec --load
hikari-kexec --exec
```

The commands validate `/boot/hikari-next/SHA256SUMS` before loading. Execution
is deliberately separate from loading. On 2026-09-15 the physical Hikari passed
two complete loader-to-SMP transitions, with both CPUs online in the second
stage and a normal reboot returning to the loader between them. The USB ACM
console re-enumerated on every transition. See the
[acceptance record](../research/device/current/boot/kexec-loader-acceptance.md).

The SMP stage still cannot safely kexec directly because it cannot prove CPU1
powered down. For each new candidate, atomically replace the files and
`SHA256SUMS` in `/boot/hikari-next`, reboot normally into the loader, and use
the three commands above. This needs reboots, but no boot flash or recovery
cycle. Keep the prior working p3 ELF as an offline rollback artifact.

Changing DT never takes effect by merely replacing a module. It needs a reboot
into a kernel using the new DTB. Changes to core kernel ABI may require a full
incremental kernel build and a matching `/lib/modules/<release>` tree. `make`
still reuses unchanged objects; neither case justifies cloning the source or
build directory.

After building the loader, run `scripts/build-hikari-debian-kernel.sh` once to
return the shared host `O=` directory to the normal SMP profile. Future builds
then remain incremental and produce second-stage candidates. The flashed
loader is not rebuilt during ordinary driver work.

## Minimal userspace policy

The package manifest intentionally contains systemd/udev, kmod, kexec-tools,
basic storage and network diagnostics, CA certificates and apt. SSH and a
graphical desktop are not installed yet. During bring-up, root has no password
and is available only on local framebuffer/USB consoles; this must be removed
before networking is treated as production-ready.

Build outputs have apt indexes and package archives removed. The host package
cache is shared rather than copied into each rootfs.

The pinned download endpoint is the geographically suitable Yandex Debian
mirror. Trust does not rely on the mirror: `debootstrap` is required to verify
Debian's signed Release metadata using the official archive keyring before it
accepts packages. `DEBIAN_MIRROR` may temporarily point at a local caching
proxy during a host build; the generated target `sources.list` is always reset
to the pinned public endpoint.
