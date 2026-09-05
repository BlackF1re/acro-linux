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
    dts_path = repo_root / "kernel/dts/qcom-msm8260-sony-hikari.dts"
    host = host_path.read_text()
    panel = panel_path.read_text()
    iommu = iommu_path.read_text()
    iommu_header = iommu_header_path.read_text()
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

    attach_start = iommu.index("static int msm_iommu_attach_dev(")
    identity_start = iommu.index("static int msm_iommu_identity_attach(", attach_start)
    attach = iommu[attach_start:identity_start]
    enabled = attach.index("ret = __enable_clocks(iommu);")
    deferred = attach.index("if (!iommu->reset_done)")
    reset = attach.index("msm_iommu_reset(iommu->base, iommu->ncb);", deferred)
    marked = attach.index("iommu->reset_done = true;", reset)
    contexts = attach.index("list_for_each_entry(master, &iommu->ctx_list, list)", marked)
    if not enabled < deferred < reset < marked < contexts:
        raise SystemExit("MSM8x60 IOMMU reset is not deferred until paging attach")

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

    print("HIKARI_DISPLAY_SOURCE_GATE=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
