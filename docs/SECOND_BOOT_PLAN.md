# Second Hikari boot plan: diagnostic gate only

No second artifact has been built and no second physical attempt is authorized.
The first attempt is recorded as `NOT_VERIFIED`; the original p3 rollback is
`VERIFIED_DEVICE` in [ROLLBACK.md](ROLLBACK.md).

## Most likely boundary

The failure boundary is **early boot through the decompressor and earliest
kernel setup**, not a diagnosed kernel panic. S1Boot accepted and flashed the
Sony ELF, then no target USB device, marker, or display evidence appeared.
The first artifact had no demonstrated diagnostics channel: its built-in
cmdline was empty, no physical MSM UART route was identified, its initramfs did
not configure USB gadget, and no safe pstore/ramoops area was established.

There is also a concrete pre-kernel configuration defect: firstboot omitted
`CONFIG_ARCH_QCOM_RESERVE_SMEM=y`, although current upstream declares the
first 2 MiB RAM reservation required for MSM8x60. Its built decompressor used
`zreladdr=0x40208000`; a corrected build must use `0x40408000`. This is a
strong candidate for failure, not proof that it was the sole cause. That
corrected destination would overlap the current `0x40208000` compressed-input
range; upstream has generic relocation code, but its safety in this exact Sony
ELF path is still unproven and is a separate deployment blocker.

## Required changes before authorizing another attempt

1. Enable `CONFIG_ARCH_QCOM_RESERVE_SMEM=y`; rebuild from the documented
   upstream commit and prove the new `zreladdr`, all compressed-input,
   decompressed-output, DTB work-space, initramfs and RPM intervals. Select a
   proven non-overlapping input address, or separately prove the required
   relocation behaviour for this Sony path.
2. Keep the appended-DTB strategy, but verify it again byte-for-byte. Upstream
   ARM supports an FDT appended at zImage `_edata` and ATAG-to-DT conversion;
   the legacy p3 itself has no appended DTB, so exact S1Boot/ATAG hand-off is
   still unproven.
3. Establish one deterministic early diagnostics route before writing: first
   identify the Hikari physical UART pins and the matching MSM UART instance,
   then build a forced early serial console and capture it externally. Do not
   guess a UART port or reserve arbitrary ramoops memory. USB gadget and
   display are not current proof channels.
4. Re-run DT, ELF, p3-size, config, and corrected memory checks. A check
   failure is an abort condition, not a reason to try the old artifact again.

## Unmistakable success criterion

The next artifact must emit a unique early kernel marker on the externally
captured, proven UART before relying on initramfs. `HIKARI INITRAMFS STARTED`
is a later independent marker. A black screen or lack of host USB alone is not
success evidence.

## Rollback and abort

Use only the already verified route: forced reset if needed (**Power + Volume
Up**), phone off + Volume Up + USB, verify S1Boot, verify the original p3
SHA-256, then—with separate owner approval—flash only logical `boot` with the
original restore ELF and reboot. Abort on any hash, size, partition-layout,
USB identity, fastboot response, memory-gate, or UART-route mismatch. Never
use erase, another partition, `fastboot boot`, or a second experimental write
without new explicit approval.
