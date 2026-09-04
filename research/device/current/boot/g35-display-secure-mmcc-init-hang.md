# Hikari g35 secure-MMCC initialization hang

Status: sanitized `VERIFIED_DEVICE` diagnostic evidence. Display scanout,
panel pixels, fbcon, and physical backlight output remain `NOT_VERIFIED`.

## Physical artifact and capture

```text
/home/paul/xperia/build/hikari-artifacts-g35-display/hikari-display-legacy-scm.elf
size: 12,519,371 bytes
SHA-256: 9f07942660a07ebb7678bffb80070707f23c8932d964247bb1ff93953d1e985c
kernel: 7.3.0-rc1-g90755ba8b809
```

TWRP recognized the valid persistent ring and exported it through
`/proc/last_kmsg`. The private, unredacted files are:

```text
/home/paul/xperia/research/private/hikari-recovery-debug/previous-proc-last_kmsg-20260904T114131Z.raw
size: 12,224 bytes
SHA-256: a304f261461a8522d0eb81e88670bc05e5ec6980e2da997315b5a04971daf91d

/home/paul/xperia/research/private/hikari-recovery-debug/recovery-dmesg-20260904T114131Z.raw
size: 48,330 bytes
SHA-256: 935a55cab947eafbe4a1bcca1eebf27bc7b986e6177cf2a78298232376f3f9d2
```

Raw logs remain outside Git.

## Last confirmed stage

The coherent previous-boot log confirms Hikari FDT, ramoops, RPM, all four
MSM8660 NoC providers, the SCM platform provider, the static g_serial driver,
AS3676 and the charging devices. The decisive final lines are:

```text
qcom_scm: convention: smc legacy
qcom_scm firmware:scm: MSM8x60 legacy SCM provider probe begin
qcom_scm firmware:scm: MSM8x60 legacy SCM provider ready for atomic SCM_IO
g_serial gadget.0: Gadget Serial v2.4
g_serial gadget.0: g_serial ready
mmcc-msm8660 4000000.clock-controller: secure MMCC initialization begin
```

There is no later MMCC stage marker, DRM probe, `/init`, Oops, panic, or
fault. Thus the last confirmed stage is entry into the first secure MMCC
register operation. The first unconfirmed stage is completion of the first
MMCC AHB read/modify/write. This early synchronous stall explains both the
black display and repeated host USB transitions: g_serial registered, but the
kernel never progressed to initramfs userspace and stable UDC operation. It is
not evidence of a new HSUSB PHY, ULPI, or ChipIdea regression.

## Exact source mismatch

Sony MSM8x60 `scm-io.c` treats the return value of `scm_call_atomic1()` as the
32-bit register value. On this device the runtime convention is explicitly
`smc legacy`. The generic current `qcom_scm_io_readl()` instead interpreted
`r0` as an SMCCC-style status and consumed `r1` as the payload. The local
kernel now decodes the legacy atomic ABI exactly while retaining the existing
SMCCC behavior for modern conventions.

The project MMCC bootstrap also defined `SAXI_EN_REG` as `0x01d8`. Exact Sony
`clock-8x60.c` shows that `SAXI_EN_REG` is at offset `0x0030` and `0x000001d8`
is the value written there. The corrected initialization also restores the
Sony AHB/MAXI masks and the `MAXI_EN2` operation instead of the unsupported
claim that RPM owned that register.

Kernel commit `9d823ead2c7bedb424dff16f547c2c1cdce910d7` contains both corrections.
They are deliberately one scoped fix because either ABI decoding or register
layout alone would leave the same first MMCC operation unsafe.

## Next local artifact

```text
/home/paul/xperia/build/hikari-artifacts-g36-display/hikari-display-secure-io-abi.elf
size: 12,519,595 bytes
SHA-256: 32a8ac35ad0b5c4084d2aeee9ebde28b329578f3a84fb316cce97349f87dfbe1
entry: 0x40208000
```

The artifact passed kernel build, final-DTB display and charging gates,
appended-DTB validation, Sony ELF validation, SMEM/ramoops checks, and ARM
zImage relocation/overlap analysis. It has not been sent to the device.

