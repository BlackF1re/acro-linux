# Sources and provenance

This file records external material used to interpret device evidence. A
source records an interpretation; it never replaces evidence from the
physical handset.

## Qualcomm socinfo ID table

| Field | Value |
| --- | --- |
| Authority | upstream Linux, Linus Torvalds tree |
| Repository | `https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git` |
| Revision checked | `786262be6048deab760f68c8acc2c85607165894` (HEAD queried 2026-09-01) |
| Exact file | `include/dt-bindings/arm/qcom,ids.h` |
| Direct URL | `https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/include/dt-bindings/arm/qcom,ids.h` |
| Relevant definition | `QCOM_ID_MSM8260 70`; neighbouring values distinguish `MSM8660` (71), `MSM8660A` (122), and `MSM8260A` (123). |
| Corroborating upstream file | `drivers/soc/qcom/socinfo.c`, which converts the ID table to the reported SoC name. |
| What it establishes | The physical read `soc0/id = 70` normalizes to **MSM8260**, not MSM8660A. It does not interpret the separate build_id string. |
| Evidence joined to it | `research/device/current/kernel/socinfo.txt` |

## Sony legacy material

Sony’s [Xperia Open Devices driver archive](https://developer.sony.com/open-source/aosp-on-xperia-open-devices/downloads/drivers)
lists an “Xperia acro S driver for ICS” release dated 2012-07-30. This is an
official vendor provenance lead for Phase B source archaeology. It does **not**
by itself establish the physical SoC SKU; no Sony document directly asserting
MSM8260 has yet been recovered in this pass.
