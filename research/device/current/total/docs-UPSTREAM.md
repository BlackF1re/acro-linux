# Upstream state: MSM8x60 and Hikari

Checked 2026-09-01 against Linus Linux revision
`786262be6048deab760f68c8acc2c85607165894` and linux-next revision
`89c07d98716a13454ec3fd9f97689e812cc71bd4`.  This is a source-archeology
record, not an implementation plan or a claim that Hikari boots upstream.

## What is present upstream

`arch/arm/boot/dts/qcom/qcom-msm8660.dtsi` supplies shared MSM8x60 DT
infrastructure: dual Scorpion CPUs, GIC, timer, TLMM pin controller, GCC and
GSBI/QUP peripheral blocks.  The compatible name `qcom,msm8660` is an
upstream shared-platform identifier; it does not overturn the physical
socinfo evidence that this handset has SKU MSM8260 (ID 70).

Upstream also has example MSM8x60 board descriptions
`qcom-apq8060-dragonboard.dts` and `qcom-msm8660-surf.dts`, plus PM8058 DT
description.  They are useful patterns only: neither describes Sony Hikari
wiring.

The current tree contains DRM/MSM A2xx code (`drivers/gpu/drm/msm/adreno/`),
including `a2xx_gpu.c`, `a2xx_catalog.c` and A2xx register definitions.  It
also contains generic drivers that match portions of the observed BOM:
PN544 NFC, LM3560 flash, MPU-3050 IIO gyro, BQ2415x charger family, and common
Qualcomm infrastructure.  Presence of a driver is not proof that its exact
variant, DT binding, power sequencing, firmware, or Hikari wiring is ready.

## Material gaps

No Hikari board DTS is upstream.  The physical panel path is legacy
Renesas R63306 and the touch path is Sony/ClearPad; no Hikari-ready upstream
panel/touch integration was established.  Current CAMSS source contains newer
generation blocks and this pass did not establish MSM8x60 VFE/CSIC support.
The legacy modem, QDSP6 voice/audio, camera, GNSS and FM paths therefore remain
major integration/research gaps.  Generic SMD/remoteproc and userspace modem
frameworks do not by themselves establish a usable MSM8260 modem on this board.

## Current patch-series discipline

Patch status is time-sensitive.  Before implementation, query lore and the
relevant subsystem tree at that time, record author, subject, revision,
Message-ID, dependencies and merge state.  One current DRM example located in
lore is Dmitry Baryshkov’s “[PATCH v2] drm/msm/adreno: fix userspace-triggered
crash on a2xx-a4xx”, Message-ID
`20260407-adreno-fix-ubwc-v2-1-7ff73624635e@oss.qualcomm.com`.
It is maintenance context, not a Hikari enablement patch; merge status must be
rechecked against the selected kernel revision before use.

A 2026-09-01 lore search specifically for `MSM8660`, `APQ8060`,
`qcom-msm8660` and `MSM8x60` returned no current dedicated patch series.  This
negative search result neither proves that no work exists nor replaces a fresh
pre-implementation lore review.

The complete subsystem-by-subsystem assessment is in
[UPSTREAM_MATRIX.md](UPSTREAM_MATRIX.md).  Source provenance is in
[SOURCES.md](SOURCES.md).
