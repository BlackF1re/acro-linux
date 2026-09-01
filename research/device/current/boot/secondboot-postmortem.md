# Second mainline-boot post-mortem capture

## Classification

`POSTMORTEM_BOOT2=WRONG_BOOT`.

The second experimental ELF was removed from p3 with the verified original-p3
restore before this capture. A direct recovery-selection attempt did not reach
recovery: the handset subsequently booted the legacy Android baseline. TWRP
was later entered manually, so its previous-boot buffer records that later
legacy boot/reboot path rather than secondboot.

## Read-only capture in TWRP

TWRP exposed only `/proc/last_kmsg`; `/dev/last_kmsg`, `/proc/ram_console`,
and `/sys/fs/pstore` were absent. The non-empty raw capture is private and is
outside Git:

| Item | Value |
| --- | --- |
| Private file | `proc-last_kmsg-recovery-after-android.adb-pull.raw` |
| Size | 55,000 bytes |
| SHA-256 | `e210ccbb674030414e835ecf0accc3362c3142b34366582edd2263ce99d7edcf` |
| Access | mode 0600, outside the repository |

The private raw text contains unique legacy identifiers and is deliberately
not reproduced here.

## Provenance result

The captured log identifies the legacy `3.4.0-Elite-1.5+` kernel and ends in a
legacy restart-to-recovery sequence. It contains neither `HIKARI MAINLINE BOOT
#2` nor `HIKARI INITRAMFS STARTED`, nor a mainline kernel identity. Therefore
it cannot establish whether secondboot reached the decompressor, `start_kernel`,
DT parsing, initramfs unpacking, or `/init`.

| Question about secondboot | Result |
| --- | --- |
| Decompressor completed | UNKNOWN |
| `start_kernel` reached | UNKNOWN |
| Appended DTB accepted | UNKNOWN |
| Initramfs unpacked | UNKNOWN |
| `/init` executed | UNKNOWN |
| Last confirmed target stage | S1Boot accepted and flashed the Sony ELF; post-reboot execution is NOT_OBSERVED |

This is an evidence-preserving negative result, not a diagnosis of a kernel
panic or a claim that secondboot did not execute.
