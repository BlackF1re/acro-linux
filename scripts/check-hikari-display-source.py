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
    cfg_path = root / "drivers/gpu/drm/msm/dsi/dsi_cfg.c"
    phy_path = root / "drivers/gpu/drm/msm/dsi/phy/dsi_phy_45nm.c"
    panel_path = root / "drivers/gpu/drm/panel/panel-renesas-r63306-tmd-mdv22.c"
    crtc_path = root / "drivers/gpu/drm/msm/disp/mdp4/mdp4_crtc.c"
    mdp4_kms_path = root / "drivers/gpu/drm/msm/disp/mdp4/mdp4_kms.c"
    dts_path = repo_root / "kernel/dts/qcom-msm8260-sony-hikari.dts"
    host = host_path.read_text()
    cfg = cfg_path.read_text()
    phy = phy_path.read_text()
    panel = panel_path.read_text()
    crtc = crtc_path.read_text()
    mdp4_kms = mdp4_kms_path.read_text()
    dts = dts_path.read_text()

    # Physical Hikari readback proves that every attempted MDP IOMMU context
    # write remains zero, while its working Sony/TWRP kernel has MSM_IOMMU
    # disabled.  MDP must therefore receive contiguous physical addresses.
    if re.search(r"\biommus\s*=", dts):
        raise SystemExit("Hikari MDP must remain detached from the MSM IOMMU")
    require(
        mdp4_kms,
        "using contiguous physical scanout without an IOMMU",
        "MDP4 no-IOMMU fallback",
    )
    gem_path = root / "drivers/gpu/drm/msm/msm_gem.c"
    gem = gem_path.read_text()
    require(gem, "dma_alloc_contiguous", "contiguous scanout allocation")
    require(gem, "msm_gem_get_and_pin_phys", "physical scanout address helper")
    require(gem, "if (!priv->kms || !priv->kms->vm)", "no-IOMMU VMA cleanup guard")
    for node in ("mdp_port0", "mdp_port1"):
        match = re.search(rf"\n\s*{node}:\s+iommu@.*?\n\s*}};", dts, re.S)
        if not match:
            raise SystemExit(f"missing documented {node} hardware node")
        require(match.group(0), 'status = "disabled";', f"disabled {node}")

    # The physical device reports PRIMARY_INTF_UNDERRUN on every frame when
    # the MSM8x60 fabric remains at a zero vote.  Preserve Sony's exact
    # framebuffer path and conservative default EBI bandwidth request.
    require(
        dts,
        "interconnects = <&mmfab MMFAB_MAS_MDP_PORT0\n"
        "\t\t\t\t &afab AFAB_SLV_EBI_CH0>;",
        "Hikari MDP-to-EBI interconnect path",
    )
    require(dts, 'interconnect-names = "mdp0-mem";', "Hikari MDP ICC name")
    require(mdp4_kms, 'devm_of_icc_get(dev, "mdp0-mem")', "MDP4 memory path lookup")
    require(
        mdp4_kms,
        "icc_set_bw(path, Bps_to_icc(407808000),\n"
        "\t\t\t Bps_to_icc(1019520000))",
        "Sony MSM8x60 framebuffer bandwidth vote",
    )

    # The MSM8x60 DSI core branch writes MMCC 0x004c bit 0 correctly, but its
    # 0x01d0/bit-2 halt readback is false on physical Hikari.  The historical
    # Sony clock path enables this gate without polling a status register.
    # Preserve the common-clock equivalent: retain the gate but skip its
    # unreliable transition poll rather than failing host power-on with -EBUSY.
    mmcc_path = root / "drivers/clk/qcom/mmcc-msm8660.c"
    mmcc = mmcc_path.read_text()

    # The board has only DSI1.  Supplying its PHY output under both DSI1 and
    # DSI2 clock names makes the two MMCC parent entries share one clk_hw;
    # assigned-clock-parents then resolves the first entry and writes mux
    # value 1 (DSI2), while Sony and the physical Hikari require value 3.
    require(dts, '"dsi1pll", "dsi1pllbyte";', "unique Hikari DSI1 MMCC parents")
    if '"dsi2pll"' in dts or '"dsi2pllbyte"' in dts:
        raise SystemExit("Hikari must not alias absent DSI2 MMCC inputs to DSI1")
    dsi_branch = re.search(
        r"static\s+struct\s+clk_branch\s+dsi1_clk\s*=\s*\{(.*?)\n\};",
        mmcc,
        re.S,
    )
    if not dsi_branch:
        raise SystemExit("missing MSM8x60 dsi1_clk branch")
    require(dsi_branch.group(1), ".halt_check = BRANCH_HALT_SKIP,", "MSM8x60 DSI halt-poll workaround")

    require(host, "enum dsi_rgb_swap rgb_swap;", "DSI RGB-swap state")
    # Hikari's V2 command engine cannot fetch the high CMA address returned by
    # a permanently coherent allocation.  Sony maps the actual padded command
    # buffer for each transfer, which also gives the DMA API ownership of the
    # cache transition and a reachable bus address.
    require(host, "msm_host->tx_buf = kmalloc(size, GFP_KERNEL);", "MSM8x60 command buffer")
    require(
        host,
        "dma_map_single(&msm_host->pdev->dev, msm_host->tx_buf, len,",
        "MSM8x60 per-transfer command DMA mapping",
    )
    require(host, "dma_unmap_single(&msm_host->pdev->dev", "MSM8x60 command DMA unmap")
    require(host, "DSI_VID_CFG1_RGB_SWAP(msm_host->rgb_swap)", "video RGB swap")
    require(host, "DSI_CMD_CFG0_RGB_SWAP(msm_host->rgb_swap)", "command RGB swap")
    require(host, '"sony,hikari-r63306-tmd-mdv22"', "Hikari panel quirk")
    require(host, "msm_host->rgb_swap = SWAP_BGR;", "Hikari BGR order")

    # Sony's MSM8x60 downstream path programs and enables MMCC DSI_CLK.  The
    # V2 clock initializer obtains that DT input as src_clk; omitting it left
    # the panel lit but the DSI engine unable to transmit video.
    require(
        cfg,
        ".clk_init_ver = dsi_clk_init_v2,",
        "MSM8x60 V2 DSI source-clock acquisition",
    )
    require(
        host,
        "cfg_hnd->cfg->quiesce_msm8x60_boot_state ?\n"
        "\t\tTRIGGER_SW : TRIGGER_NONE",
        "Hikari software MDP trigger",
    )
    require(
        phy,
        "phy->timing.shared_timings.clk_post = 0x04;",
        "Hikari MDV22 T_CLK_POST",
    )
    require(
        phy,
        "phy->timing.shared_timings.clk_pre = 0x1b;",
        "Hikari MDV22 T_CLK_PRE",
    )
    pll_table = phy.index(
        "write_table(base, PHY_REG(0x204), &hikari_pll[1]",
    )
    pll_ctrl_5 = phy.index("writel(hikari_pll[5], base + PHY_REG(0x214));")
    if pll_ctrl_5 < pll_table:
        raise SystemExit("Hikari operational PLL_CTRL_5 value precedes the PLL table")
    require(
        cfg,
        ".cmd_dma_irq_timeout_nonfatal = true,",
        "MSM8x60 nonfatal command-DMA completion timeout",
    )
    require(
        host,
        "cfg_hnd->cfg->cmd_dma_irq_timeout_nonfatal && idle &&",
        "MSM8x60-scoped command-DMA timeout handling",
    )
    require(
        host,
        "!(fifo & 0x44444489) && !ack",
        "Sony DSI FIFO and ACK error gate",
    )
    if "hardware clears TRIG_DMA" in host or "if (!(trigger & 1))" in host:
        raise SystemExit("command-DMA completion still depends on sticky TRIG_DMA")
    rate_start = host.index("int dsi_link_clk_set_rate_msm8x60(")
    enable_start = host.index("int dsi_link_clk_enable_msm8x60(", rate_start)
    disable_start = host.index("void dsi_link_clk_disable_6g(", enable_start)
    msm_disable_start = host.index("void dsi_link_clk_disable_msm8x60(", disable_start)
    rate = host[rate_start:enable_start]
    enable = host[enable_start:disable_start]
    disable = host[msm_disable_start:]
    require(rate, "clk_set_rate(msm_host->src_clk, msm_host->src_clk_rate)", "MSM8x60 DSI source rate")
    require(enable, "clk_prepare_enable(msm_host->src_clk)", "MSM8x60 DSI source enable")
    require(enable, "clk_disable_unprepare(msm_host->src_clk)", "MSM8x60 DSI source unwind")
    require(disable, "clk_disable_unprepare(msm_host->src_clk)", "MSM8x60 DSI source disable")

    # The Hikari path must keep Sony's exact non-burst sync-event mode. In
    # DRM/MSM this is VIDEO without VIDEO_SYNC_PULSE, plus HSE for HSA/HE.
    require(
        panel,
        "dsi->mode_flags = MIPI_DSI_MODE_VIDEO | MIPI_DSI_MODE_VIDEO_HSE |\n"
        "\t\t\t  MIPI_DSI_CLOCK_NON_CONTINUOUS;",
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

    # Sony sends Sleep Out and Display On while the DSI link is in its command
    # phase, before enabling video scanout.  The panel must also request the
    # DRM bridge ordering which powers the MSM8x60 host/PHY before prepare.
    require(
        panel,
        "m->panel.prepare_prev_first = true;",
        "MDV22 host-before-panel prepare order",
    )
    prepare_start = panel.index("static int mdv22_prepare(")
    unprepare_start = panel.index("static int mdv22_unprepare(", prepare_start)
    enable_start = panel.index("static int mdv22_enable(", unprepare_start)
    disable_start = panel.index("static int mdv22_disable(", enable_start)
    prepare = panel[prepare_start:unprepare_start]
    enable = panel[enable_start:disable_start]
    require(
        prepare,
        "mipi_dsi_dcs_set_display_on(m->dsi)",
        "MDV22 pre-scanout Display On command",
    )
    display_on = prepare.index("mipi_dsi_dcs_set_display_on(m->dsi)")
    if "msleep(" in prepare[display_on:]:
        raise SystemExit("MDV22 has a non-Sony delay after Display On")
    if "mipi_dsi_dcs_set_display_on" in enable:
        raise SystemExit("MDV22 Display On regressed to the post-scanout enable callback")
    if "mipi_dsi_dcs_set_display_off" in panel:
        raise SystemExit("MDV22 added a Display Off command absent from Sony's exact off table")

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
