# Hikari single-core kexec loader acceptance (2026-09-15)

## Result

`VERIFIED_DEVICE`: a mainline single-core kernel in p3 loaded and executed the
full SMP Hikari kernel, DTB and initramfs stored on the `HIKARI_ROOT` microSD.
The complete loader -> SMP transition passed twice. Between the two passes a
normal reboot returned to the loader, so no fastboot or recovery operation was
needed for the second candidate boot.

This verifies the development boot architecture. It does not verify every
peripheral across kexec, direct Android selection, suspend/resume, or a cold
boot with the card absent.

## Why the loader is single-core

The full SMP kernel rejected a checksum-valid image with
`kexec_load failed: Invalid argument`; `/sys/kernel/kexec_loaded` remained 0.
The ARM implementation in `arch/arm/kernel/machine_kexec.c` deliberately
returns `-EINVAL` when secondary boot exists but complete CPU hotplug does not.
The current Qualcomm MSM8x60 SMP operations can start CPU1 and provide
`qcom_cpu_die()`, but provide no `cpu_kill` operation proving that CPU1 has
been completely powered down.

A physical hotplug probe reinforced that restriction: taking CPU1 offline
succeeded, but bringing it online again returned `EIO` and the kernel logged
`CPU1: failed to come online`. Adding a dummy success callback would therefore
be unsafe. The loader instead uses `CONFIG_SMP=n`, leaving CPU1 in bootloader
reset. The second-stage SMP kernel then starts CPU1 through its normal SCM
release path.

## Artifacts and flash scope

- loader Sony ELF: 12,630,460 bytes
- loader SHA-256: `6bd74c112d879b0074c2415ccaebbd2eae8cbf2915445fa3c3f0c3b9419b801a`
- retained prior SMP rollback ELF SHA-256:
  `33da9a3df6e770a843781a0ee09112f1c710e591ac13b8d6603d1764f5f70422`
- second-stage zImage SHA-256:
  `329dbefb268492bf5a0fc375b2a4fe286049f732f46a4aa7889d4b846e06913e`
- second-stage Hikari DTB SHA-256:
  `09e1139363a12e65430c2d73ab47958eada90862d9d8f2cb37e225fe980d08d0`
- second-stage initramfs SHA-256:
  `f8c66b6a6a43a142968b9dfa17aab1e9a91fbe9fe1e305e0ebae0e860a9d53e2`

S1Boot reported `secure: no`. Only logical `boot` was written; S1Boot mapped
it to partID `0x00000003` and reported a successful erase and flash. No other
partition was touched.

## Physical observations

First loader boot:

```text
Linux hikari 7.3.0-rc1-g33452d3bca12-dirty #1 PREEMPT armv7l GNU/Linux
online:   0
possible: 0
root:     /dev/mmcblk2p1 ext4 rw
kexec --load: rc=0
kexec_loaded: 1
```

First second stage:

```text
Linux hikari 7.3.0-rc1-g33452d3bca12-dirty #1 SMP PREEMPT armv7l GNU/Linux
online/present/possible: 0-1
root: /dev/mmcblk0p1 ext4 rw
SMP: Total of 2 processors activated
```

After a normal reboot, the loader again reported only CPU0. The second
`hikari-kexec --load` again set `kexec_loaded` to 1, and the second stage again
reported SMP CPUs `0-1` online with the ext4 card mounted read/write. The
microSD node varied (`mmcblk0`, `mmcblk1`, `mmcblk2`) across boots, confirming
why the boot path uses filesystem label `HIKARI_ROOT` rather than a device
number. The USB ACM console disconnected and enumerated again at every reboot
and both kexec transitions.

The second stage found the matching `/lib/modules/<release>` tree with 20
module files. Fifteen were live during inspection, including the RMI4, NFC,
Bluetooth UART, BMA180 and MPU3050 stacks. This is module ABI/load evidence,
not functional acceptance of those devices.

## Operational boundary

The running SMP stage still cannot safely kexec another kernel because MSM8x60
does not implement complete CPU shutdown. To test another kernel, replace the
checksum-protected files in `/boot/hikari-next`, issue a normal reboot into the
p3 loader, then run `hikari-kexec --load` and `hikari-kexec --exec`. The
loader's critical display, USB and storage paths are built in. SMP-built
modules are for the second stage and must not be expected to load in the
single-core rescue kernel.
