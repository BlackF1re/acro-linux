#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Fail if the materialized Hikari display path loses exact Sony details."""

from pathlib import Path
import re
import sys


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise SystemExit(f"missing {label}: {needle!r}")


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit(f"usage: {sys.argv[0]} KERNEL_TREE")

    root = Path(sys.argv[1])
    repo_root = Path(__file__).resolve().parents[1]
    host_path = root / "drivers/gpu/drm/msm/dsi/dsi_host.c"
    panel_path = root / "drivers/gpu/drm/panel/panel-renesas-r63306-tmd-mdv22.c"
    iommu_path = root / "drivers/iommu/msm_iommu.c"
    iommu_header_path = root / "drivers/iommu/msm_iommu.h"
    crtc_path = root / "drivers/gpu/drm/msm/disp/mdp4/mdp4_crtc.c"
    dts_path = repo_root / "kernel/dts/qcom-msm8260-sony-hikari.dts"
    host = host_path.read_text()
    panel = panel_path.read_text()
    iommu = iommu_path.read_text()
    iommu_header = iommu_header_path.read_text()
    crtc = crtc_path.read_text()
    dts = dts_path.read_text()

    require(host, "enum dsi_rgb_swap rgb_swap;", "DSI RGB-swap state")
    require(host, "DSI_VID_CFG1_RGB_SWAP(msm_host->rgb_swap)", "video RGB swap")
    require(host, "DSI_CMD_CFG0_RGB_SWAP(msm_host->rgb_swap)", "command RGB swap")
    require(host, '"sony,hikari-r63306-tmd-mdv22"', "Hikari panel quirk")
    require(host, "msm_host->rgb_swap = SWAP_BGR;", "Hikari BGR order")

    # The Hikari path must keep Sony's exact non-burst sync-event mode. In
    # DRM/MSM this is VIDEO without VIDEO_SYNC_PULSE, plus HSE for HSA/HE.
    require(
        panel,
        "dsi->mode_flags = MIPI_DSI_MODE_VIDEO | MIPI_DSI_MODE_VIDEO_HSE;",
        "MDV22 DSI traffic mode",
    )
    if "dsi->mode_flags = MIPI_DSI_MODE_VIDEO | MIPI_DSI_MODE_VIDEO_SYNC_PULSE" in panel:
        raise SystemExit("MDV22 regressed to non-burst sync-pulse mode")

    on_sequence = (
        "gpiod_set_value_cansleep(m->reset, 0);\n"
        "\tmsleep(10);\n"
        "\tgpiod_set_value_cansleep(m->reset, 1);\n"
        "\tmsleep(10);\n"
        "\tgpiod_set_value_cansleep(m->power, 1);\n"
        "\tmsleep(50);"
    )
    require(panel, on_sequence, "Sony MDV22 reset/power-on order")

    off_sequence = (
        "mipi_dsi_dcs_enter_sleep_mode(m->dsi);\n"
        "\tmsleep(80);\n"
        "\tgpiod_set_value_cansleep(m->power, 0);\n"
        "\tmsleep(50);\n"
        "\tgpiod_set_value_cansleep(m->reset, 0);\n"
        "\tmsleep(10);\n"
        "\tregulator_bulk_disable(2, m->supplies);"
    )
    require(panel, off_sequence, "Sony MDV22 power-off order")

    # Patch 0014 resolves the DT backlight phandle. Match C whitespace rather
    # than depending on the historical patch's formatting style.
    if not re.search(r"\bret\s*=\s*drm_panel_of_backlight\s*\(\s*&m->panel\s*\)\s*;", panel):
        raise SystemExit("missing MDV22 DRM backlight lookup")
    require(
        panel,
        '"failed to get backlight\\n"',
        "MDV22 deferred backlight probe diagnostic",
    )

    # A live Hikari proves that probe-time V2P/PAR detection rejects both MDP
    # IOMMUs even with their gates enabled. Preserve the working MSM8x60 model:
    # generic probing remains identity-mapped, while the destructive reset is
    # deferred until DRM/MSM creates its paging domain and attaches.
    require(iommu_header, "bool reset_done;", "deferred IOMMU reset state")
    require(iommu, ".def_domain_type = msm_iommu_def_domain_type,", "IOMMU identity default")
    require(iommu, "return IOMMU_DOMAIN_IDENTITY;", "IOMMU identity policy")
    require(
        iommu,
        "find_master_for_dev(struct msm_iommu_dev *iommu, struct device *dev)",
        "provider-local IOMMU master lookup",
    )
    require(
        iommu,
        "priv->iommu_dev = get_device(iommu->dev);",
        "IOMMU provider lifetime for page-table DMA",
    )
    require(
        iommu,
        ".iommu_dev = priv->iommu_dev,",
        "provider-owned io-pgtable DMA mapping",
    )
    if ".iommu_dev = priv->client," in iommu or ".iommu_dev = priv->dev," in iommu:
        raise SystemExit("io-pgtable DMA ownership regressed to the translated client")
    require(iommu_header, "struct msm_iommu_dev *iommu;", "master provider pointer")
    require(iommu_header, "struct list_head domain_node;", "per-master domain link")

    attach_start = iommu.index("static int msm_iommu_attach_dev(")
    identity_start = iommu.index("static int msm_iommu_identity_attach(", attach_start)
    map_start = iommu.index("static int msm_iommu_map(", identity_start)
    attach = iommu[attach_start:identity_start]
    identity_attach = iommu[identity_start:map_start]
    enabled = attach.index("ret = __enable_clocks(iommu);")
    deferred = attach.index("if (!iommu->reset_done)")
    reset = attach.index("msm_iommu_reset(iommu->base, iommu->ncb);", deferred)
    marked = attach.index("iommu->reset_done = true;", reset)
    contexts = attach.index("config_mids(iommu, master);", marked)
    if not enabled < deferred < reset < marked < contexts:
        raise SystemExit("MSM8x60 IOMMU reset is not deferred until paging attach")
    require(
        attach,
        "master = find_master_for_dev(iommu, dev);",
        "provider-local IOMMU attach",
    )
    if "list_first_entry(&iommu->ctx_list" in attach:
        raise SystemExit("MSM8x60 IOMMU attach still assumes the first provider master")
    require(
        identity_attach,
        "list_del_init(&master->domain_node);",
        "detached master domain-list removal",
    )
    if "free_io_pgtable_ops" in identity_attach:
        raise SystemExit("identity attach still frees io-pgtable before DMA detach")

    domain_free_start = iommu.index("static void msm_iommu_domain_free(")
    domain_config_start = iommu.index("static int msm_iommu_domain_config(", domain_free_start)
    domain_free = iommu[domain_free_start:domain_config_start]
    require(domain_free, "free_io_pgtable_ops(priv->iop);", "domain-owned io-pgtable free")

    insert_start = iommu.index("static int insert_iommu_master(")
    xlate_start = iommu.index("static int qcom_iommu_of_xlate(", insert_start)
    insert = iommu[insert_start:xlate_start]
    require(
        insert,
        "master = find_master_for_dev(*iommu, dev);",
        "one IOMMU master per provider",
    )
    for forbidden in ("dev_iommu_priv_get(dev)", "dev_iommu_priv_set(dev"):
        if forbidden in insert:
            raise SystemExit(
                f"multi-provider IOMMU xlate still uses single device private state: {forbidden!r}"
            )

    probe_start = iommu.index("static int msm_iommu_probe(struct platform_device *pdev)")
    probe = iommu[probe_start:]
    for forbidden in (
        "msm_iommu_reset(iommu->base, iommu->ncb);",
        "SET_V2PPR(iommu->base, 0, 0);",
        "GET_PAR(iommu->base, 0)",
        "Invalid PAR value detected",
    ):
        if forbidden in probe:
            raise SystemExit(f"destructive IOMMU probe-time test returned: {forbidden!r}")

    # qcom,apq8064-iommu.yaml defines non-secure IRQ first, secure second.
    # Sony devices-iommu.c gives Hikari/MSM8x60 exactly 96/95 and 94/93,
    # which become GIC SPIs 64/63 and 62/61 after subtracting GIC_SPI_START.
    require(
        dts,
        "interrupts = <GIC_SPI 64 IRQ_TYPE_LEVEL_HIGH>,\n\t\t\t     <GIC_SPI 63 IRQ_TYPE_LEVEL_HIGH>;",
        "MDP0 non-secure/secure IRQ order",
    )
    require(
        dts,
        "interrupts = <GIC_SPI 62 IRQ_TYPE_LEVEL_HIGH>,\n\t\t\t     <GIC_SPI 61 IRQ_TYPE_LEVEL_HIGH>;",
        "MDP1 non-secure/secure IRQ order",
    )

    # Sony's DSI-video path uses DMA_P_DONE for commit completion and
    # PRIMARY_VSYNC for scanout vblank.  Keeping those as one mdp_irq made
    # drm_fb_helper wait forever even after the framebuffer commit completed.
    require(crtc, "struct mdp_irq commit;", "MDP4 commit IRQ")
    require(crtc, "u32 vblank_irqmask;", "MDP4 scanout vblank mask")
    require(
        crtc,
        "mdp4_crtc->vblank_irqmask = MDP4_IRQ_PRIMARY_VSYNC;",
        "DSI-video primary VSYNC selection",
    )

    print("HIKARI_DISPLAY_SOURCE_GATE=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
