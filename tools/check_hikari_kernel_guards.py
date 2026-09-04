#!/usr/bin/env python3
"""Reject regressions in source-critical Hikari display/charging fixes."""

from __future__ import annotations

import argparse
import re
from pathlib import Path


def fail(message: str) -> None:
    raise SystemExit(message)


def check_mmcc(kernel: Path) -> None:
    source = (kernel / "drivers/clk/qcom/mmcc-msm8660.c").read_text()
    match = re.search(
        r"static struct clk_branch dsi_s_ahb_clk = \{(?P<body>.*?)\n\};",
        source,
        re.S,
    )
    if not match:
        fail("cannot find dsi_s_ahb_clk")
    body = match.group("body")
    if ".halt_bit = 20," not in body:
        fail("MSM8x60 DSI slave AHB halt bit must be 20")
    if "CLK_IS_CRITICAL" in body:
        fail("MSM8x60 DSI slave AHB clock must follow runtime-PM ownership")

    mdp_gdsc = re.search(
        r"static struct gdsc mdp_gdsc = \{(?P<body>.*?)\n\};", source, re.S
    )
    if not mdp_gdsc or "RPM_ALWAYS_ON" not in mdp_gdsc.group("body"):
        fail("MSM8x60 MDP legacy footswitch must remain powered after init")
    for fragment in (
        "mmcc_msm8660_init_mdp_footswitch",
        "MDP_FS_AXI_RESET_MASK",
        "MDP_FS_AHB_RESET_MASK",
        "MDP_FS_CORE_RESET_MASK",
        "LEGACY_FS_ENABLE_BIT",
        "LEGACY_FS_CLAMP_BIT",
        "MDP footswitch: clock-assisted AXI/AHB/core reset completed",
    ):
        if fragment not in source:
            fail(f"MSM8x60 MDP footswitch sequence lacks: {fragment}")

    mdp4 = (
        kernel / "drivers/gpu/drm/msm/disp/mdp4/mdp4_kms.c"
    ).read_text()
    if 'of_machine_is_compatible("qcom,msm8260")' not in mdp4:
        fail("MSM8260 MDP4 must use its 200 MHz maximum core rate")
    if "failed to enable MDP clocks for revision read" not in mdp4:
        fail("MDP4 revision read must reject failed clock preparation")

    cfg = (kernel / "drivers/gpu/drm/msm/dsi/dsi_cfg.c").read_text()
    dsi = (kernel / "drivers/gpu/drm/msm/dsi/dsi.c").read_text()
    host = (kernel / "drivers/gpu/drm/msm/dsi/dsi_host.c").read_text()
    phy = (
        kernel / "drivers/gpu/drm/msm/dsi/phy/dsi_phy_45nm.c"
    ).read_text()
    if ".quiesce_msm8x60_boot_state = true," not in cfg:
        fail("MSM8x60 DSI must request complete boot-state quiesce")

    init_body = dsi[dsi.find("static struct msm_dsi *dsi_init(") :]
    init_body = init_body[: init_body.find("static void dsi_destroy(")]
    if "msm_dsi_host_quiesce_boot_state(msm_dsi->host," not in init_body:
        fail("MSM8x60 firmware state must be quiesced once during DSI init")

    quiesce_body = host[host.find("int msm_dsi_host_quiesce_boot_state(") :]
    quiesce_body = quiesce_body[: quiesce_body.find("int msm_dsi_runtime_suspend(")]
    required_quiesce = (
        "if (!msm_host->cfg_hnd->cfg->quiesce_msm8x60_boot_state)",
        "clk_bulk_prepare_enable(msm_host->num_bus_clks,",
        "dsi_write(msm_host, REG_DSI_CLK_CTRL, 0);",
        "dsi_write(msm_host, REG_DSI_CTRL, 0);",
        "msm_dsi_phy_quiesce_boot_state(phy);",
        "msm_host->keep_bus_clks_on = true;",
    )
    for fragment in required_quiesce:
        if fragment not in quiesce_body:
            fail(f"MSM8x60 one-shot quiesce lacks: {fragment}")

    suspend_body = host[host.find("int msm_dsi_runtime_suspend(") :]
    suspend_body = suspend_body[: suspend_body.find("int msm_dsi_runtime_resume(")]
    if "if (msm_host->keep_bus_clks_on)" not in suspend_body:
        fail("MSM8x60 DSI runtime suspend must retain its tracked AHB clocks")
    for forbidden in (
        "REG_DSI_CLK_CTRL",
        "REG_DSI_CTRL",
        "msm_dsi_phy_quiesce_boot_state",
    ):
        if forbidden in suspend_body:
            fail(f"destructive DSI quiesce leaked into runtime suspend: {forbidden}")

    resume_body = host[host.find("int msm_dsi_runtime_resume(") :]
    resume_body = resume_body[: resume_body.find("int dsi_link_clk_set_rate_6g(")]
    if "if (msm_host->keep_bus_clks_on)" not in resume_body:
        fail("MSM8x60 DSI runtime resume must preserve the retained-clock refcount")

    destroy_body = host[host.find("void msm_dsi_host_destroy(") :]
    destroy_body = destroy_body[: destroy_body.find("int msm_dsi_host_modeset_init(")]
    required_destroy = (
        "if (msm_host->keep_bus_clks_on)",
        "clk_bulk_disable_unprepare(msm_host->num_bus_clks,",
        "msm_host->keep_bus_clks_on = false;",
    )
    for fragment in required_destroy:
        if fragment not in destroy_body:
            fail(f"MSM8x60 retained DSI clock teardown lacks: {fragment}")
    if "writel(0, phy->pll_base);" not in phy:
        fail("MSM8x60 45nm PHY quiesce must clear PLL_CTRL_0")


def check_panel(kernel: Path) -> None:
    source = (
        kernel
        / "drivers/gpu/drm/panel/panel-renesas-r63306-tmd-mdv22.c"
    ).read_text()
    for table in ("mdv22_init", "mdv22_post_sleep"):
        match = re.search(
            rf"static const u8 {table}\[\]\[17\] = \{{(?P<body>.*?)\n\}};",
            source,
            re.S,
        )
        if not match:
            fail(f"cannot find {table}")
        rows = re.findall(r"\{([^{}]+)\}", match.group("body"))
        if not rows:
            fail(f"{table} is empty")
        for row in rows:
            values = [part.strip() for part in row.split(",") if part.strip()]
            try:
                payload_length = int(values[0], 0)
            except ValueError as error:
                fail(f"{table}: invalid length in {{{row}}}: {error}")
            actual_length = len(values) - 2  # Exclude length and command byte.
            if payload_length != actual_length:
                fail(
                    f"{table}: command {values[1]} declares {payload_length} "
                    f"parameter bytes but contains {actual_length}"
                )


def check_charger(kernel: Path) -> None:
    source = (kernel / "drivers/power/supply/bq24160_charger.c").read_text()
    required = (
        "#define BQ24160_STAT_FAULT",
        "if (stat == BQ24160_STAT_FAULT ||",
        "FIELD_GET(BQ24160_STATUS_STAT_MASK, status) ==",
    )
    for fragment in required:
        if fragment not in source:
            fail(f"BQ24160 current-state fault handling lacks: {fragment}")
    if re.search(r"if \(fault \|\|", source):
        fail("BQ24160 still disables charging solely on latched fault history")


def check_usb_phy(kernel: Path) -> None:
    source = (
        kernel / "drivers/phy/qualcomm/phy-qcom-usb-hs.c"
    ).read_text()
    required = (
        "state = regulator_get_voltage(uphy->v3p3);",
        "if (state < 3050000 || state > 3300000)",
        "regulator_set_voltage_triplet(uphy->v3p3, 3050000,",
    )
    for fragment in required:
        if fragment not in source:
            fail(f"Qualcomm HS PHY fixed-rail handling lacks: {fragment}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--kernel-src", type=Path, required=True)
    args = parser.parse_args()
    if not args.kernel_src.is_dir():
        fail(f"kernel source does not exist: {args.kernel_src}")
    check_mmcc(args.kernel_src)
    check_panel(args.kernel_src)
    check_charger(args.kernel_src)
    check_usb_phy(args.kernel_src)
    print("HIKARI_KERNEL_SOURCE_GUARDS=PASS")


if __name__ == "__main__":
    main()
