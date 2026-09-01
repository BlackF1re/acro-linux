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

## Source archaeology inventory (2026-09-01)

All revisions below were retrieved as metadata only.  “Reference” means that
the tree can explain legacy wiring or history, not that its code is suitable
for production.  “Candidate” means maintained upstream-oriented material that
may be evaluated later; it is not yet selected or integrated.

| Source | Revision / branch checked | Licence | Authority and role | Hikari relevance |
| --- | --- | --- | --- | --- |
| [Linus Linux](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git) | `786262be6048deab760f68c8acc2c85607165894` (HEAD) | GPL-2.0-only (kernel) | Primary upstream; candidate code | `qcom-msm8660.dtsi`, PM8058 DT description, DRM/MSM A2xx and many generic drivers. |
| [linux-next](https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git) | `89c07d98716a13454ec3fd9f97689e812cc71bd4` (HEAD) | GPL-2.0-only (kernel) | Upstream integration snapshot; candidate/review source | Check pending MSM and DRM work before implementation. |
| [DRM/MSM lore archive](https://lore.kernel.org/dri-devel/) | searched 2026-09-01 | per submitted patch | Authoritative mailing-list record for unmerged/revised work | Current A2xx–A4xx maintenance must be checked here, rather than copied from forks. |
| [Mesa](https://gitlab.freedesktop.org/mesa/mesa) | `eaa8cb690243d25c9b5ccc40e11a0d0d5a836d0f` (HEAD) | mixed; inspect files used | Primary userspace graphics source; candidate | Freedreno userspace counterpart to DRM/MSM; Adreno 220 viability requires real-device validation. |
| [Sony Open Devices driver archive](https://developer.sony.com/open-source/aosp-on-xperia-open-devices/downloads/drivers) | Xperia acro S ICS listing, 2012-07-30 | archive-specific; not yet inspected | Official vendor source lead; reference | Potential Sony/Fuji BSP provenance.  No archive content was imported. |
| [OpenSEMC Sony MSM8x60 kernel](https://github.com/OpenSEMC/android_kernel_sony_msm8x60) | `kk_chocolate_rmfx` / `c4784b04c08d30f799b8b14b597aeb2124d2e6e1` | repository metadata: NOASSERTION; individual kernel files must be checked | Historical community legacy reference | Contains Fuji/Hikari board files for camera, touch, NFC, audio, charger, LEDs, GPIO and regulators. |
| [LineageOS Sony MSM8x60 kernel](https://github.com/LineageOS/android_kernel_sony_msm8x60) | `lineage-18.1` / `e52cfeafb72d86941552af50afeb21407fb96778` | repository metadata: NOASSERTION; individual files must be checked | Historical Android-derived reference | Legacy MSM8660 configuration and R63306 panel code; not upstream production code. |
| [postmarketOS pmaports](https://gitlab.postmarketos.org/postmarketOS/pmaports) | `8628ff6159f10b168535ce3b9ccbd7e70acf2e7f` (HEAD) | inspect repository/package licences before reuse | Current distribution packaging reference | No current `sony-hikari` port was established by this metadata pass; do not infer support from related ports. |

The following requested names were searched as Git remotes but did not yield a
usable authoritative Hikari tree at the checked guessed locations:
FreeXperia and nAOSP `android_kernel_sony_msm8x60`.  This is a negative lookup,
not evidence that no historical work exists.  It must be revisited with a
specific archived URL if one is found.

## Exact source paths used as legacy references

OpenSEMC’s `arch/arm/mach-msm/board-fuji-camera.c` names the two legacy camera
I2C devices and their power/reset sequencing.  `touch-fuji_hikari.c`,
`nfc-fuji.c`, `qdsp6v2/board-semc_fuji-audio.c`, `charger-fuji_hikari.c`, and
`leds-fuji_hikari.c` are the corresponding Hikari/Fuji reference paths.
They support the mappings in [BOARD_TO_DT.md](BOARD_TO_DT.md); they are not
proof of exact silicon beyond the physical evidence cited there.
