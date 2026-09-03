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

## Boot / fastboot / recovery sources (checked 2026-09-01)

| Source | Revision / authority | What it establishes | Use and confidence |
| --- | --- | --- | --- |
| [Sony useful key combinations](https://developer.sony.com/open-source/aosp-on-xperia-open-devices/get-started/flash-tool/useful-key-combinations) | Sony Developer World, current page checked 2026-09-01 | Volume Up while connecting USB enters fastboot; Volume Down enters Flashmode. | `VERIFIED_VENDOR_SOURCE` for key semantics; it does not replace physical enumeration. |
| [AOSP LT26 custombootimg.mk](https://android.googlesource.com/device/sony/lt26/%2B/8213cd2eabf386629f56cc1ac6b8102ffd0671eb/custombootimg.mk) | Android Open Source Project commit `8213cd2eabf386629f56cc1ac6b8102ffd0671eb`; historical LT26 reference | Sony ELF construction order: kernel, ramdisk marked `ramdisk`, RPM marked `rpm`; historical LT26 addresses. | `HISTORICAL_SOURCE`; current Hikari p3 addresses take precedence where they differ. |
| [AOSP LT26 recovery.fstab](https://android.googlesource.com/device/sony/lt26/%2B/8213cd2eabf386629f56cc1ac6b8102ffd0671eb/recovery.fstab) | Android Open Source Project commit `8213cd2eabf386629f56cc1ac6b8102ffd0671eb`; checked 2026-09-02 | Exact line `/boot emmc /dev/block/mmcblk0p3`. | `VERIFIED_VENDOR_SOURCE` for the historical LT26 boot-role mapping; direct handset fstab evidence remains the primary exact-device record. |
| [AOSP LT26 mkelf.py introduction](https://android.googlesource.com/device/sony/lt26/%2B/b644924c93b3c89e0e6f3aeeb85fb9a23147350f%5E!/) | AOSP commit `b644924c93b3c89e0e6f3aeeb85fb9a23147350f`, Sony Mobile copyright notice | SEMC ELF flags: RAMDISK `0x80000000`, CMDLINE `0x20000000`, Qualcomm MSM8x60 RPM `0x01000000`; segments are laid from `0x1000` in input order. | `HISTORICAL_SOURCE` used to interpret the exact flags in the offline p3 metadata. |
| [AOSP Android-building LT26 discussion](https://groups.google.com/g/android-building/c/zji_sQGN9Oo/m/MoaS0xidmRMJ) | Historical project discussion, checked 2026-09-01 | Reports LT26 recovery triggering from a boot image and legacy S1Boot family context. | `HISTORICAL_SOURCE` only; current handset recovery storage remains `UNKNOWN`. |
| Linus Linux ARM Qualcomm Kconfig / Makefile | Local upstream checkout `786262be6048deab760f68c8acc2c85607165894`, checked 2026-09-02: `arch/arm/mach-qcom/Kconfig:18-22`, `arch/arm/Makefile:162,169` | `CONFIG_ARCH_QCOM_RESERVE_SMEM` reserves the first 2 MiB System RAM and is required for MSM8x60; when selected, ARM `TEXT_OFFSET` is `0x00208000`. | `VERIFIED_UPSTREAM` for the second-attempt config and memory-gate requirement; it does not diagnose the first physical failure by itself. |
| OpenSEMC MSM8x60 board map | Local historical checkout `c4784b04c08d30f799b8b14b597aeb2124d2e6e1`, checked 2026-09-02: `arch/arm/mach-msm/board-msm8x60.c:110,7624-7627`; `include/mach/msm_iomap.h:104-109` | Historical MSM8x60 board code sets `msm_shared_ram_phys` to `0x40000000`; its shared-RAM mapping size for this family is 2 MiB. | `HISTORICAL_SOURCE` supporting, but not by itself proving, the physical-RAM/SMEM correction. |
| [intgr Hikari mainline dmesg](https://gist.github.com/intgr/cc5b4e606846e33d6415694084f4aba1) | GitHub gist revision `cc5b4e606846e33d6415694084f4aba1`, created 2019-11-07, retrieved 2026-09-02 | A historical Hikari mainline Linux 5.3 trace identifies the Hikari DT model, reaches `/init`, records `No ATAGs?`, uses ramoops at `0x7ffe0000`, and enables `ttyMSM0` after the `0x19c40000` MSM serial device probes. | `HISTORICAL_SOURCE`: a known-booting bootstrap trace, not a source-tree revision nor proof that its addresses/config can be copied unchanged. |
| intgr Hikari dmesg Git snapshot | Local external clone of the above gist, commit `bfe482df2546abdb1842ac69beb7734b7f98c209`, retrieved 2026-09-02 | Preserves the historical trace as an auditable external reference: Linux 5.3 reaches `Run /init as init process`; ramoops reports `0x20000@0x7ffe0000, ecc: 0`; `ttyMSM0` is later enabled at `0x19c40000`. | `HISTORICAL_SOURCE`; this is a runtime trace only, not the missing matching source tree. |
| OpenSEMC Fuji persistent console | Local historical checkout `c4784b04c08d30f799b8b14b597aeb2124d2e6e1`, checked 2026-09-02: `arch/arm/mach-msm/board-semc_fuji.c:3947-3965,4606-4628`; `drivers/staging/android/persistent_ram.c`; `drivers/staging/android/ram_console.c` | Legacy Fuji uses `0x7ffe0000+0x20000`, `DBGC`, an ARM32 12-byte ring header and zero ECC; it publishes valid old content through `/proc/last_kmsg`. | `HISTORICAL_SOURCE`, joined to physical TWRP header/dmesg evidence for the recovery reader format. |
| Linus Linux ramoops core and binding | Local upstream checkout `786262be6048deab760f68c8acc2c85607165894`, checked 2026-09-02: `fs/pstore/ram_core.c`, `fs/pstore/ram.c`, `Documentation/devicetree/bindings/reserved-memory/ramoops.yaml` | Current upstream uses the same `DBGC` persistent-RAM base header; console signature zero XORs to `DBGC`; `ecc-size` defaults to zero and a console-only zone is supported. | `VERIFIED_UPSTREAM` for boot #4 ramoops configuration and binary-layout comparison. |

No authoritative source or direct non-persistent test was found that proves
`fastboot boot` support for S1Boot `CRH1099189_R10C008`. Its status is therefore
`UNKNOWN`; the host client's command set is not evidence of bootloader support.

## Source archaeology inventory (2026-09-01)

All revisions below were retrieved as metadata only.  “Reference” means that
the tree can explain legacy wiring or history, not that its code is suitable
for production.  “Candidate” means maintained upstream-oriented material that
may be evaluated later; it is not yet selected or integrated.

| Source | Revision / branch checked | Licence | Authority and role | Hikari relevance |
| --- | --- | --- | --- | --- |
| [Linus Linux](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git) | `786262be6048deab760f68c8acc2c85607165894` (HEAD) | GPL-2.0-only (kernel) | Primary upstream; candidate code | `qcom-msm8660.dtsi`, PM8058 DT description, DRM/MSM A2xx and many generic drivers. |
| [BusyBox](https://git.busybox.net/busybox/) | `74ac096e895acd6b02976bb010e9b3511234e899` | GPL-2.0-only | Local first-boot initramfs userspace source | Static diagnostic shell only; not Android userspace and not a production userspace selection. |
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

An additional targeted 2026-09-02 lookup found no public `sony-hikari` project
through the postmarketOS GitLab project search and no public intgr
`linux-postmarketos` Hikari source tree. The `intgr` mainline dmesg above is a
usable historical runtime trace, but its matching kernel/DT source revision is
therefore `UNKNOWN`; no inferred source commit is recorded.

## Exact source paths used as legacy references

OpenSEMC’s `arch/arm/mach-msm/board-fuji-camera.c` names the two legacy camera
I2C devices and their power/reset sequencing.  `touch-fuji_hikari.c`,
`nfc-fuji.c`, `qdsp6v2/board-semc_fuji-audio.c`, `charger-fuji_hikari.c`, and
`leds-fuji_hikari.c` are the corresponding Hikari/Fuji reference paths.
They support the mappings in [BOARD_TO_DT.md](BOARD_TO_DT.md); they are not
proof of exact silicon beyond the physical evidence cited there.

## BOOT #5 USB and display references (checked 2026-09-02)

| Source | Revision / URL | Extracted information | Confidence and use |
| --- | --- | --- | --- |
| Linus Linux USB controller binding | [`ci-hdrc-usb2.yaml`](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/Documentation/devicetree/bindings/usb/ci-hdrc-usb2.yaml?id=786262be6048deab760f68c8acc2c85607165894), Linux `786262be6048deab760f68c8acc2c85607165894` | `qcom,ci-hdrc`, two controller register ranges, `iface`/`core` clocks, reset and peripheral `dr_mode`. | `VERIFIED_UPSTREAM`; used for the BOOT #5 HSUSB1 node. |
| Linus Linux Qualcomm HS PHY binding | [`qcom,usb-hs-phy.yaml`](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/Documentation/devicetree/bindings/phy/qcom,usb-hs-phy.yaml?id=786262be6048deab760f68c8acc2c85607165894), same revision | MSM8660 ULPI PHY compatible and regulator/clock/reset binding. | `VERIFIED_UPSTREAM`; used for the PHY node, not as physical proof of enumeration. |
| Herman van Hazendonk USB-HS PHY v3 | [v3 1/2 binding](https://lkml.iu.edu/2606.2/01062.html), Message-ID `<20260616-submit-phy-usb-hs-vendor-init-seq-v3-1-7d21fb1d1484@herrie.org>`; [v3 2/2 driver](https://lkml.iu.edu/2606.2/01073.html), Message-ID `<20260616-submit-phy-usb-hs-vendor-init-seq-v3-2-7d21fb1d1484@herrie.org>`; 2026-06-16 | Authoritative public v3 source for MSM8x60 vendor ULPI power-on writes and optional 4-bit HS driver slope. Applied as external-worktree commits `a2e1e55ae3b266d90dc7c7a0629f4398b4cc41f7` and `7d2353796ad5317c04c14465fcf3321f2f89c225`, retaining author metadata after a mechanical context rebase. | `VERIFIED_UPSTREAM`; BOOT #5 uses the vendor writes and deliberately omits an unsupported Hikari slope override. |
| OpenSEMC Fuji USB BSP | `board-semc_fuji.c` in [OpenSEMC MSM8x60](https://github.com/OpenSEMC/android_kernel_sony_msm8x60/tree/c4784b04c08d30f799b8b14b597aeb2124d2e6e1), branch `kk_chocolate_rmfx`, checked 2026-09-02 | HSUSB at `0x12500000`; PM8058 L6 3.05 V, L7 1.8 V; VBUS/ID callbacks. | `HISTORICAL_SOURCE`; board wiring evidence. Only the device-only rails are represented in BOOT #5. |
| OpenSEMC Fuji display BSP | `board-semc_fuji.c` and `mipi_tmd_video_wxga_mdv22.c` in the same tree/revision | R63306/TMD 720p panel family, four-lane video DSI, legacy timing/power/reset information. | `HISTORICAL_SOURCE`; records a future conversion input, not a current DTS implementation. |
| Linus Linux DRM/MSM tree | [`drivers/gpu/drm/msm`](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/drivers/gpu/drm/msm?id=786262be6048deab760f68c8acc2c85607165894), same revision | Generic DRM/MSM, MDP4, DSI and fbdev infrastructure exist; no exact MSM8x60 45 nm DSI PHY or R63306 panel driver was found. | `VERIFIED_UPSTREAM`; establishes the intended architecture and present gap. |

The June 2026 USB-ULPI v3 series is now recorded and applied exactly as noted
above.  No MSM8x60 MMCC or interconnect series is applied to BOOT #5: neither
is a static dependency of the minimal ChipIdea device-mode path.  Their merge
state and need for later display/high-bandwidth work remain separate research
items.

## Native charging references (checked 2026-09-03)

| Source | Revision / path | Extracted information | Use and confidence |
| --- | --- | --- | --- |
| OpenSEMC Fuji/Hikari charging BSP | Local `opensemc-msm8x60` checkout `c4784b04c08d30f799b8b14b597aeb2124d2e6e1`: `board-semc_fuji.c`, `charger-fuji_hikari.c`, `drivers/power/bq24160_charger.c`, `battery_chargalg.c` | GSBI8 addresses AS3676 `0x40`, BQ27520 `0x55`, BQ24160 `0x6b`; BQ24160 GPIO125 IRQ, BQ27520 GPIO123 SOC interrupt, cradle GPIO126; Hikari voltage/current/thermal/watchdog policy and revision-`0x05` hysteresis. | `HISTORICAL_SOURCE`, exact board-level wiring/policy reference only. |
| Linus Linux BQ27xxx | Local upstream checkout `786262be6048deab760f68c8acc2c85607165894`: `drivers/power/supply/bq27xxx_battery*.c`, `Documentation/devicetree/bindings/power/supply/bq27xxx.yaml` | Maintained BQ27520 power-supply driver and binding; NVM update handling is separately guarded by `CONFIG_BATTERY_BQ27XXX_DT_UPDATES_NVM`. | `VERIFIED_UPSTREAM`; used read-only for the existing programmed gauge. |
