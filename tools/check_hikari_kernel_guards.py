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

    cfg = (kernel / "drivers/gpu/drm/msm/dsi/dsi_cfg.c").read_text()
    host = (kernel / "drivers/gpu/drm/msm/dsi/dsi_host.c").read_text()
    if ".clear_clk_ctrl_on_suspend = true," not in cfg:
        fail("MSM8x60 DSI must request clock-control cleanup on suspend")
    required_suspend = (
        "if (msm_host->cfg_hnd->cfg->clear_clk_ctrl_on_suspend)",
        "dsi_write(msm_host, REG_DSI_CLK_CTRL, 0);",
        "wmb();",
    )
    for fragment in required_suspend:
        if fragment not in host:
            fail(f"MSM8x60 DSI suspend cleanup lacks: {fragment}")


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
