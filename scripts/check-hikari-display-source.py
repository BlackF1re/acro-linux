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
    host_path = root / "drivers/gpu/drm/msm/dsi/dsi_host.c"
    panel_path = root / "drivers/gpu/drm/panel/panel-renesas-r63306-tmd-mdv22.c"
    host = host_path.read_text()
    panel = panel_path.read_text()

    require(host, "enum dsi_rgb_swap rgb_swap;", "DSI RGB-swap state")
    require(host, "DSI_VID_CFG1_RGB_SWAP(msm_host->rgb_swap)", "video RGB swap")
    require(host, "DSI_CMD_CFG0_RGB_SWAP(msm_host->rgb_swap)", "command RGB swap")
    require(host, '"sony,hikari-r63306-tmd-mdv22"', "Hikari panel quirk")
    require(host, "msm_host->rgb_swap = SWAP_BGR;", "Hikari BGR order")

    # The Hikari path must keep Sony's exact non-burst sync-event mode.  In
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

    # Patch 0014 resolves the DT backlight phandle.  Match C whitespace rather
    # than depending on the historical patch's formatting style.
    if not re.search(r"\bret\s*=\s*drm_panel_of_backlight\s*\(\s*&m->panel\s*\)\s*;", panel):
        raise SystemExit("missing MDV22 DRM backlight lookup")
    require(
        panel,
        '"failed to get backlight\\n"',
        "MDV22 deferred backlight probe diagnostic",
    )

    print("HIKARI_DISPLAY_SOURCE_GATE=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
