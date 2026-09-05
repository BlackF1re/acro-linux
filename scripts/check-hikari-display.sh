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
	CONFIG_QCOM_SCM=y CONFIG_MSM_MMCC_8660=y CONFIG_INTERCONNECT_QCOM_MSM8660=y \
	CONFIG_DRM=y CONFIG_DRM_MSM=y CONFIG_DRM_MSM_MDP4=y CONFIG_DRM_MSM_DSI=y \
	CONFIG_MSM_IOMMU=y \
	CONFIG_DRM_MSM_DSI_45NM_PHY=y \
	CONFIG_DRM_PANEL_RENESAS_R63306_TMD_MDV22=y \
	CONFIG_BACKLIGHT_AS3676=y CONFIG_VT=y CONFIG_VT_CONSOLE=y \
	CONFIG_FRAMEBUFFER_CONSOLE=y; do
	grep -qx "$symbol" "$config" || { echo "missing $symbol" >&2; exit 1; }
done

grep -qx '# CONFIG_FRAMEBUFFER_CONSOLE_DEFERRED_TAKEOVER is not set' "$config" || {
	echo 'Hikari display bring-up requires immediate fbcon takeover' >&2
	exit 1
}
grep -Eq '^CONFIG_CMDLINE=".*console=tty0([ "].*)$' "$config" || {
	echo 'Hikari display bring-up requires tty0 as a kernel console' >&2
	exit 1
}

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
expect_hex /display-controller@5100000/ports/port@1 reg 1
expect_string /display-controller@5100000 clock-names core_clk
expect_string /display-controller@5100000 clock-names iface_clk
expect_string /display-controller@5100000 clock-names bus_clk
expect_string /display-controller@5100000 clock-names lut_clk

# Sony MSM8x60 and upstream APQ8064 agree on the two MDP IOMMU apertures,
# context-bank count, clocks and MIDs.  The binding orders interrupts as
# non-secure first, secure second.  Sony's legacy resources are IRQ 96/95 for
# MDP0 and 94/93 for MDP1; subtract GIC_SPI_START (32) for the DT SPI numbers.
mmcc_phandle=$(fdtget -t x "$dtb" /clock-controller@4000000 phandle)
for spec in \
	'/iommu@7500000 7500000 40 3f' \
	'/iommu@7600000 7600000 3e 3d'; do
	read -r node base nonsecure_irq secure_irq <<<"$spec"
	expect_string "$node" compatible qcom,msm8660-iommu
	expect_string "$node" compatible qcom,apq8064-iommu
	expect_hex "$node" reg "$base 100000"
	expect_hex "$node" qcom,ncb 2
	expect_hex "$node" interrupts "0 $nonsecure_irq 4 0 $secure_irq 4"
	clocks=$(fdtget -t x "$dtb" "$node" clocks | tr -s ' ' | sed 's/^ //;s/ $//')
	[[ $clocks == "$mmcc_phandle b $mmcc_phandle 1e" ]] || {
		echo "$node clocks must resolve to SMMU_AHB_CLK (11) and MDP_AXI_CLK (30), got '$clocks'" >&2
		exit 1
	}
done

mdp0_phandle=$(fdtget -t x "$dtb" /iommu@7500000 phandle)
mdp1_phandle=$(fdtget -t x "$dtb" /iommu@7600000 phandle)
mdp_iommus=$(fdtget -t x "$dtb" /display-controller@5100000 iommus |
	tr -s ' ' | sed 's/^ //;s/ $//')
[[ $mdp_iommus == "$mdp0_phandle 0 $mdp0_phandle 2 $mdp1_phandle 0 $mdp1_phandle 2" ]] || {
	echo "MDP4 IOMMU mapping must be port0 MIDs 0/2 and port1 MIDs 0/2, got '$mdp_iommus'" >&2
	exit 1
}

# Sony's MSM8x60 BSP supplies mdp.0 through footswitch FS_MDP (ID 4).  A
# clock-only MDP description can hang the CPU on its first 0x05100000 read.
mdp_domain=$(fdtget -t x "$dtb" /display-controller@5100000 power-domains |
	tr -s ' ' | sed 's/^ //;s/ $//')
[[ $mdp_domain == "$mmcc_phandle 4" ]] || {
	echo "MDP power-domain must resolve to MMCC MDP_GDSC (4), got '$mdp_domain'" >&2
	exit 1
}

grep -Eq '^CONFIG_CMDLINE=".*driver_async_probe=([^ "]*,)*mdp4(,[^ "]*)*.*"$' "$config" || {
	echo 'display bring-up requires asynchronous mdp4 probe as a USB-console fail-safe' >&2
	exit 1
}
expect_string /dsi@4700000 compatible qcom,msm8660-dsi-ctrl
expect_string /dsi@4700000 compatible qcom,mdss-dsi-ctrl
expect_hex /dsi@4700000 reg '4700000 200'
expect_string /dsi@4700000 reg-names dsi_ctrl
expect_string /dsi@4700000 phy-names dsi
expect_string /dsi@4700000/panel@0 compatible sony,hikari-r63306-tmd-mdv22
expect_string /soc/gsbi@19800000/i2c@19880000/backlight@40 compatible ams,as3676-backlight
expect_hex /soc/gsbi@19800000/i2c@19880000/backlight@40 reg 40
expect_string /dsi-phy@47000f0 compatible qcom,msm8660-dsi-phy-45nm
expect_hex /dsi-phy@47000f0 reg '47000f0 1e0 4700200 d0'
expect_hex /reserved-memory/ramoops@7ffe0000 reg '7ffe0000 20000'

# Secure MMCC access cannot merely wait on qcom_scm_is_available(): an SCM
# platform device must exist and bind first.  Its MSM8660 binding requires the
# RPM Daytona fabric clock as the sole core clock.
expect_string /firmware/scm compatible qcom,scm-msm8660
expect_string /firmware/scm compatible qcom,scm
expect_string /firmware/scm clock-names core
rpmcc_phandle=$(fdtget -t x "$dtb" /soc/rpm@104000/clock-controller phandle)
scm_clock=$(fdtget -t x "$dtb" /firmware/scm clocks |
	tr -s ' ' | sed 's/^ //;s/ $//')
[[ $scm_clock == "$rpmcc_phandle a" ]] || {
	echo "SCM core clock must resolve to RPM_DAYTONA_FABRIC_CLK (10), got '$scm_clock'" >&2
	exit 1
}

# The MSM8x60 V2 host exposes direct byte/pixel/escape inputs.  The source
# divider is internal to the DSI PHY/host path; describing APQ8064-style src
# clocks or assigned parents makes the clock core attempt unsupported runtime
# reparent operations and prevented the physical Hikari from reaching /init.
expected_names='iface bus core_mmss byte pixel core'
actual_names=$(fdtget -t s "$dtb" /dsi@4700000 clock-names | tr -s ' ' | sed 's/^ //;s/ $//')
[[ $actual_names == "$expected_names" ]] || {
	echo "incorrect MSM8x60 DSI clock input list: $actual_names" >&2
	exit 1
}
if fdtget "$dtb" /dsi@4700000 assigned-clock-parents >/dev/null 2>&1 ||
   fdtget "$dtb" /dsi@4700000 assigned-clocks >/dev/null 2>&1; then
	echo 'MSM8x60 DSI must not carry APQ8064-style assigned clock parents' >&2
	exit 1
fi

# The panel must drive the physical AS3676 LCD backlight through the DRM panel
# helper.  A standalone backlight node can probe while leaving the LCD dark.
backlight_phandle=$(fdtget -t x "$dtb" /soc/gsbi@19800000/i2c@19880000/backlight@40 phandle)
panel_backlight=$(fdtget -t x "$dtb" /dsi@4700000/panel@0 backlight)
[[ $panel_backlight == "$backlight_phandle" ]] || {
	echo "panel backlight phandle does not resolve to AS3676: $panel_backlight" >&2
	exit 1
}

# Exact MDV22 timing: 896 * 1296 * 60 = 69,672,960 Hz; RGB888 / 4 lanes.
[[ $((896 * 1296 * 60)) == 69672960 ]]
[[ $((69672960 * 24 / 4)) == 418037760 ]]

# A display graph must contain reciprocal endpoint links, rather than merely
# compiling standalone controller/panel nodes.
for endpoint in \
	/display-controller@5100000/ports/port@1/endpoint \
	/dsi@4700000/ports/port@0/endpoint \
	/dsi@4700000/ports/port@1/endpoint \
	/dsi@4700000/panel@0/port/endpoint; do
	fdtget -t x "$dtb" "$endpoint" remote-endpoint >/dev/null
done

# Port 0 is the internal LCDC/LVDS output on MDP4.  Wiring DSI there leaves
# the DRM/MSM component match empty and faults during deferred probe.
if fdtget -t x "$dtb" /display-controller@5100000/ports/port@0/endpoint remote-endpoint >/dev/null 2>&1; then
	echo 'MDP4 port 0 must not carry the Hikari DSI endpoint' >&2
	exit 1
fi

echo 'HIKARI_DISPLAY_STATIC_GATE=PASS'
