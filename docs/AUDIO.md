# Hikari native audio

## Hardware reference

`VERIFIED_VENDOR_SOURCE`: Sony 6.2.B.1.96, commit
`ae953d9a9f149db0c3a51e2b587074d0d911b7ea`.

- `board-semc_fuji.c`: GSBI7 I2C, Timpani core 0x0d, codec 0x77,
  PM8058 L0/S3, GPIO21 reset, analog S4.
- `qdsp6v2/board-semc_fuji-audio.c`: Hikari routes, speaker enables
  TLMM16/20, headphone L10/NCP supplies, microphone bias and audio pins.
- `qdsp6v2/timpani_profile_fuji_hikari.h`: ordered masked codec writes,
  stage transitions and settling delays. Generic board amplifier wiring
  must not replace these Hikari routes.
- `pil-q6v3.c`: Q6v3 boot/reset and RPM PLL4 vote.
- `smd.c`: ADSP SMD edge 1, SPI90, APCS GCC at 0x02082000 (mainline `l2cc`), IPC offset 8 bit15.
- `qdsp6v2/q6core.h`: legacy core version request 0x11152/response 0x11153.
  Current q6core uses a different protocol; unmodified modern QDSP6 clients
  are not proof of compatibility with the stock firmware.

## Implementation

`IMPLEMENTING`, not verified playback/capture.

`0021-hikari-audio.patch` provides:

- Sony bus/reset/power description and a native runtime-managed Timpani
  ASoC component. No dummy PCM or fake sound card is registered.
- Native QDSP6v3 remoteproc with fixed-address DDR/TCM split firmware loading,
  destination validation, PAS or Sony nonsecure startup and SMD/APR transport.
- DT bindings for both devices. DSP autoboot is disabled during bring-up.

The optional `kernel/configs/hikari-audio.fragment` enables the bring-up
modules. It is not yet part of the production configuration.

Firmware `q6.mdt` and `q6.b00` through `q6.b07` were extracted read-only
from the owner's Android backup. They remain outside Git. Firmware memory
is 0x46700000--0x47efffff; TCM is a separate address range at 0x28400000.
Neither is application RAM on the observed device.

## Remaining acceptance gates

1. Physical Timpani identification and suspend/resume of its control supplies.
2. Q6 firmware boot and real APR replies, including legacy service versions.
3. Native legacy AFE/ADM/ASM PCM protocol, clocks, ALSA machine routing and
   codec profile sequencing with shared-register ownership.
4. Speaker, receiver, headphones and microphone playback/capture; jack/mic
   bias, FM MI2S routing, simultaneous streams and repeated suspend/resume.

A successful module build or DSP `running` state does not establish sound.

## Device bring-up, 2026-10-09

- First audio bundle reached `/init`, but an obsolete saved config omitted
  `CONFIG_QCOM_MPM`, blocking TLMM-dependent USB/SD startup. Ramoops captured
  the root-wait failure. This was a config error, not an audio result.
- Rebuilding with the actual working wake2 config restored SYSTEM and Phosh.
  Timpani identified physically at `2-000d`; its codec interface is 0x77.
- Q6 firmware loaded through remoteproc; the DSP produced interrupts and
  advertised `apr_audio_svc`. The first APR opening failed because the SMD
  doorbell incorrectly referenced the clock GCC rather than APCS GCC.
  DT is corrected to `l2cc`; handshake acceptance remains required.
- The BOOT test helper was not idempotent: when `/system` was already mounted,
  its second mount failed, and a read-only remount later failed with
  `Device or resource busy`. The corrected helper reached kexec. Audio4 then
  stopped during early deferred probing at GSBI6, before `/init`, with no panic;
  the known booting audio2 image passed GSBI6/GSBI7 and reached `/init` under
  the same initcall tracing. This is not an APR test result. Audio2 was restored.
