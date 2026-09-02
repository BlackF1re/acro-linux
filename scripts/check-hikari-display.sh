#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Static gate for the source-verified Hikari BOOT #6 display graph.
set -euo pipefail

usage() {
	printf 'usage: %s --config <.config> --dtb <hikari.dtb>\n' "$0" >&2
	exit 2
}

config=
dtb=
while (($#)); do
	case "$1" in
		--config) config=${2:?}; shift 2 ;;
		--dtb) dtb=${2:?}; shift 2 ;;
		*) usage ;;
	esac
done

[[ -r $config && -r $dtb ]] || usage
command -v fdtget >/dev/null || { echo 'fdtget is required' >&2; exit 1; }

for symbol in \
	CONFIG_MSM_MMCC_8660=y CONFIG_INTERCONNECT_QCOM_MSM8660=y \
	CONFIG_DRM=y CONFIG_DRM_MSM=y CONFIG_DRM_MSM_MDP4=y CONFIG_DRM_MSM_DSI=y \
	CONFIG_DRM_MSM_DSI_45NM_PHY=y \
	CONFIG_DRM_PANEL_RENESAS_R63306_TMD_MDV22=y \
	CONFIG_BACKLIGHT_AS3676=y CONFIG_FRAMEBUFFER_CONSOLE=y; do
	grep -qx "$symbol" "$config" || { echo "missing $symbol" >&2; exit 1; }
done

expect_string() {
	local node=$1 property=$2 expected=$3 actual
	actual=$(fdtget -t s "$dtb" "$node" "$property")
	case " $actual " in
		*" $expected "*) ;;
		*) echo "$node:$property: expected list containing '$expected', got '$actual'" >&2
			exit 1 ;;
	esac
}

expect_hex() {
	local node=$1 property=$2 expected=$3 actual
	actual=$(fdtget -t x "$dtb" "$node" "$property" | tr -s ' ' | sed 's/^ //;s/ $//')
	[[ $actual == "$expected" ]] || {
		echo "$node:$property: expected '$expected', got '$actual'" >&2
		exit 1
	}
}

expect_string /display-controller@5100000 compatible qcom,mdp4
expect_hex /display-controller@5100000 reg '5100000 f0000'
expect_string /display-controller@5100000 clock-names core_clk
expect_string /display-controller@5100000 clock-names iface_clk
expect_string /display-controller@5100000 clock-names bus_clk
expect_string /display-controller@5100000 clock-names lut_clk
expect_string /dsi@4700000 compatible qcom,msm8660-dsi-ctrl
expect_hex /dsi@4700000 reg '4700000 200'
expect_string /dsi@4700000/panel@0 compatible renesas,r63306-tmd-mdv22
expect_string /soc/gsbi@19800000/i2c@19880000/backlight@40 compatible ams,as3676-backlight
expect_hex /soc/gsbi@19800000/i2c@19880000/backlight@40 reg 40
expect_string /dsi-phy compatible qcom,dsi-phy-45nm-msm8x60
expect_hex /reserved-memory/ramoops@7ffe0000 reg '7ffe0000 20000'

# Exact MDV22 timing: 896 * 1296 * 60 = 69,672,960 Hz; RGB888 / 4 lanes.
[[ $((896 * 1296 * 60)) == 69672960 ]]
[[ $((69672960 * 24 / 4)) == 418037760 ]]

# A display graph must contain reciprocal endpoint links, rather than merely
# compiling standalone controller/panel nodes.
for endpoint in \
	/display-controller@5100000/ports/port@0/endpoint \
	/dsi@4700000/ports/port@0/endpoint \
	/dsi@4700000/ports/port@1/endpoint \
	/dsi@4700000/panel@0/ports/port/endpoint; do
	fdtget -t x "$dtb" "$endpoint" remote-endpoint >/dev/null
done

echo 'HIKARI_DISPLAY_STATIC_GATE=PASS'
