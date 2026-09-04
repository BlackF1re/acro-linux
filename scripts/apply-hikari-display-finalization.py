#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Apply strict, source-backed Hikari display finalization corrections."""

from pathlib import Path
import sys


def replace_once(path: Path, old: str, new: str, label: str) -> None:
    text = path.read_text()
    if new in text:
        raise SystemExit(f"{label}: corrected form already present in {path}")
    count = text.count(old)
    if count != 1:
        raise SystemExit(
            f"{label}: expected exactly one historical form in {path}, found {count}"
        )
    path.write_text(text.replace(old, new, 1))


def main() -> int:
    if len(sys.argv) != 2:
        raise SystemExit(f"usage: {sys.argv[0]} KERNEL_TREE")

    root = Path(sys.argv[1])
    host = root / "drivers/gpu/drm/msm/dsi/dsi_host.c"
    panel = root / "drivers/gpu/drm/panel/panel-renesas-r63306-tmd-mdv22.c"
    for path in (host, panel):
        if not path.is_file():
            raise SystemExit(f"missing expected source file: {path}")

    # Sony's MDV22 profile explicitly selects DSI_RGB_SWAP_BGR.  Mainline's
    # MSM DSI host otherwise hard-codes SWAP_RGB for every attached panel.
    replace_once(
        host,
        "\tenum mipi_dsi_pixel_format format;\n\tunsigned long mode_flags;\n",
        "\tenum mipi_dsi_pixel_format format;\n\tunsigned long mode_flags;\n\tenum dsi_rgb_swap rgb_swap;\n",
        "DSI RGB-swap state",
    )
    replace_once(
        host,
        "\t\t/* Do not swap RGB colors */\n"
        "\t\tdata = DSI_VID_CFG1_RGB_SWAP(SWAP_RGB);\n"
        "\t\tdsi_write(msm_host, REG_DSI_VID_CFG1, 0);\n",
        "\t\tdata = DSI_VID_CFG1_RGB_SWAP(msm_host->rgb_swap);\n"
        "\t\tdsi_write(msm_host, REG_DSI_VID_CFG1, data);\n",
        "DSI video RGB-swap programming",
    )
    replace_once(
        host,
        "\t\t/* Do not swap RGB colors */\n"
        "\t\tdata = DSI_CMD_CFG0_RGB_SWAP(SWAP_RGB);\n",
        "\t\tdata = DSI_CMD_CFG0_RGB_SWAP(msm_host->rgb_swap);\n",
        "DSI command RGB-swap programming",
    )
    replace_once(
        host,
        "\tmsm_host->format = dsi->format;\n"
        "\tmsm_host->mode_flags = dsi->mode_flags;\n",
        "\tmsm_host->format = dsi->format;\n"
        "\tmsm_host->mode_flags = dsi->mode_flags;\n"
        "\tmsm_host->rgb_swap = SWAP_RGB;\n"
        "\tif (of_device_is_compatible(dsi->dev.of_node,\n"
        "\t\t\t\t    \"sony,hikari-r63306-tmd-mdv22\"))\n"
        "\t\tmsm_host->rgb_swap = SWAP_BGR;\n",
        "Hikari MDV22 BGR quirk",
    )

    # Reproduce the Fuji board power sequence rather than merely preserving
    # the same delays in a different order.  The downstream code enables
    # VCI/VDDIO, toggles reset low/high with 10 ms legs, then asserts GPIO18
    # and waits 50 ms before sending the panel initialization commands.
    replace_once(
        panel,
        "\tgpiod_set_value_cansleep(m->power,1); msleep(50); "
        "gpiod_set_value_cansleep(m->reset,0); msleep(10); "
        "gpiod_set_value_cansleep(m->reset,1); msleep(10);\n",
        "\tgpiod_set_value_cansleep(m->reset, 0);\n"
        "\tmsleep(10);\n"
        "\tgpiod_set_value_cansleep(m->reset, 1);\n"
        "\tmsleep(10);\n"
        "\tgpiod_set_value_cansleep(m->power, 1);\n"
        "\tmsleep(50);\n",
        "MDV22 power-on order",
    )

    # Sony's panel-off table contains ENTER_SLEEP with an 80 ms delay; GPIO18
    # then stays low for 50 ms before reset is asserted and the rails go away.
    replace_once(
        panel,
        "static int mdv22_unprepare(struct drm_panel *panel)\n"
        "{ struct mdv22 *m=to_mdv22(panel); mipi_dsi_dcs_enter_sleep_mode(m->dsi); "
        "msleep(80); gpiod_set_value_cansleep(m->reset,0); "
        "gpiod_set_value_cansleep(m->power,0); regulator_bulk_disable(2,m->supplies); "
        "return 0; }\n",
        "static int mdv22_unprepare(struct drm_panel *panel)\n"
        "{\n"
        "\tstruct mdv22 *m = to_mdv22(panel);\n\n"
        "\tmipi_dsi_dcs_enter_sleep_mode(m->dsi);\n"
        "\tmsleep(80);\n"
        "\tgpiod_set_value_cansleep(m->power, 0);\n"
        "\tmsleep(50);\n"
        "\tgpiod_set_value_cansleep(m->reset, 0);\n"
        "\tmsleep(10);\n"
        "\tregulator_bulk_disable(2, m->supplies);\n"
        "\treturn 0;\n"
        "}\n",
        "MDV22 power-off order",
    )

    # Patch 0014 already resolves the DT backlight phandle with
    # drm_panel_of_backlight().  Do not duplicate that historical correction
    # here; check-hikari-display-source.py verifies that it remains present in
    # the fully materialized panel source.

    print("HIKARI_DISPLAY_FINALIZATION_TRANSFORM=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
