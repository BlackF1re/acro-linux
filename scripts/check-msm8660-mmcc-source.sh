#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Static source gate for MSM8x60 MMCC facts cross-checked against Sony/CAF
# clock-8x60.c.  This prevents known v1 transcription errors from returning.
set -euo pipefail

kernel_src=${1:-${KERNEL_SRC:-/home/paul/xperia/src/linux}}
source_file="$kernel_src/drivers/clk/qcom/mmcc-msm8660.c"
[[ -r $source_file ]] || {
  echo "missing MSM8660 MMCC source: $source_file" >&2
  exit 1
}

python3 - "$source_file" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
text = path.read_text()


def branch(name: str) -> str:
    pat = re.compile(
        rf"static\s+struct\s+clk_branch\s+{re.escape(name)}\s*=\s*\{{(.*?)\n\}};",
        re.S,
    )
    m = pat.search(text)
    if not m:
        raise SystemExit(f"missing clk_branch {name}")
    return m.group(1)


def rcg(name: str) -> str:
    pat = re.compile(
        rf"static\s+struct\s+clk_rcg\s+{re.escape(name)}\s*=\s*\{{(.*?)\n\}};",
        re.S,
    )
    m = pat.search(text)
    if not m:
        raise SystemExit(f"missing clk_rcg {name}")
    return m.group(1)


def require(name: str, *patterns: str, forbid_critical: bool = False) -> None:
    body = branch(name)
    for pattern in patterns:
        if not re.search(pattern, body, re.S):
            raise SystemExit(f"{name}: missing expected source pattern: {pattern}")
    if forbid_critical and "CLK_IS_CRITICAL" in body:
        raise SystemExit(f"{name}: must not be CLK_IS_CRITICAL on MSM8x60")


# DRM stores the exact 69,672,960 Hz MDV22 mode as 69,673 kHz and therefore
# asks the clock framework for 69,673,000 Hz. qcom_find_freq() selects the
# first table rate greater than or equal to the request. The table label must
# use the rounded request while retaining Sony's exact 567/3125 M/N values;
# otherwise live hardware selects the next 76.8 MHz entry and produces no
# DSI-video VSYNC.
if not re.search(
    r"\{\s*69673000\s*,\s*P_PLL8\s*,\s*1\s*,\s*567\s*,\s*3125\s*\}",
    text,
):
    raise SystemExit("missing rounded Hikari 69,673,000 Hz MDP pixel-clock entry")
if re.search(r"\{\s*69672960\s*,\s*P_PLL8\s*,\s*1\s*,\s*567\s*,\s*3125\s*\}", text):
    raise SystemExit("unselectable exact-Hz Hikari MDP pixel-clock label returned")

# The MSM8x60 DSI core clock is a bypass mux.  The public MMCC v1 carried an
# empty frequency table and clk_rcg_bypass_ops, which silently forced parent
# enum zero (PXO).  The Hikari runtime then showed DSI_NS=0 even though Sony's
# downstream code selects source value 3 (DSI1 PLL).  The bypass2 operations
# preserve the parent selected through assigned-clock-parents.
dsi_src = rcg("dsi1_src")
if "clk_rcg_bypass2_ops" not in dsi_src:
    raise SystemExit("dsi1_src must use parent-aware clk_rcg_bypass2_ops")
if ".freq_tbl" in dsi_src:
    raise SystemExit("dsi1_src must not use an empty/fixed frequency table")
if re.search(r"static\s+const\s+struct\s+freq_tbl\s+clk_tbl_dsi", text):
    raise SystemExit("obsolete empty DSI frequency table returned")

# MDP4 asks for both MDP_CLK and MDP_LUT_CLK.  MSM8x60 has no separate LUT
# gate, but two provider IDs must still point at two distinct clk_hw objects:
# qcom_cc_really_probe() registers every populated array entry.  Registering
# &mdp_clk.clkr twice caused a physical-device NULL dereference in
# __clk_register() before DRM could probe.
if re.search(r"\[MDP_LUT_CLK\]\s*=\s*&mdp_clk\.clkr", text):
    raise SystemExit("MDP_LUT_CLK must not register the MDP core clk_hw twice")
for pattern, message in (
    (r"static\s+struct\s+clk_regmap\s+mdp_lut_clk\s*=", "missing distinct MDP LUT CCF object"),
    (r"\[MDP_LUT_CLK\]\s*=\s*&mdp_lut_clk\b", "MDP_LUT_CLK does not use its distinct CCF object"),
    (r"\.name\s*=\s*\"mdp_lut_clk\".*?&mdp_clk\.clkr\.hw.*?CLK_SET_RATE_PARENT", "MDP LUT clock does not propagate to the real MDP core clock"),
):
    if not re.search(pattern, text, re.S):
        raise SystemExit(message)

# Exact Sony MSM8x60 clock-8x60.c:
#   vpe_axi: MAXI_EN2 (0x0020), bit 26, normal consumer-owned branch.
require(
    "vpe_axi_clk",
    r"\.enable_reg\s*=\s*0x0*020\b",
    r"\.enable_mask\s*=\s*BIT\(26\)",
    r"\.halt_bit\s*=\s*1\b",
    forbid_critical=True,
)

# ROT AXI is MAXI_EN2 bit 24, not bit 22 from the public v1 transcription.
require(
    "rot_axi_clk",
    r"\.enable_reg\s*=\s*0x0*020\b",
    r"\.enable_mask\s*=\s*BIT\(24\)",
    r"\.halt_bit\s*=\s*2\b",
)

# Exact DBG_BUS_VEC_F halt positions from Sony clock-8x60.c.
require(
    "dsi_s_ahb_clk",
    r"\.enable_reg\s*=\s*0x0*008\b",
    r"\.enable_mask\s*=\s*BIT\(18\)",
    r"\.halt_bit\s*=\s*20\b",
    forbid_critical=True,
)
require(
    "mmss_imem_ahb_clk",
    r"\.enable_reg\s*=\s*0x0*008\b",
    r"\.enable_mask\s*=\s*BIT\(6\)",
    r"\.halt_bit\s*=\s*10\b",
    forbid_critical=True,
)
require(
    "vcodec_ahb_clk",
    r"\.enable_reg\s*=\s*0x0*008\b",
    r"\.enable_mask\s*=\s*BIT\(11\)",
    r"\.halt_bit\s*=\s*12\b",
)

# DSI master and AMP are part of the same known-good AHB halt triplet.
require(
    "dsi_m_ahb_clk",
    r"\.enable_mask\s*=\s*BIT\(9\)",
    r"\.halt_bit\s*=\s*19\b",
    forbid_critical=True,
)
require(
    "amp_ahb_clk",
    r"\.enable_mask\s*=\s*BIT\(24\)",
    r"\.halt_bit\s*=\s*18\b",
    forbid_critical=True,
)

# Exact DBG_BUS_VEC_D map.  A prior transcription shifted/reordered these
# bits, causing physical Hikari to reject mdp_tv_clk with -EBUSY even though
# its enable bit had been asserted.  Keep strict halt polling; validate the
# status source instead of using BRANCH_HALT_SKIP.
for name, enable_bit, halt_bit in (
    ("tv_enc_clk", 8, 8),
    ("tv_dac_clk", 10, 9),
    ("mdp_tv_clk", 0, 11),
    ("hdmi_tv_clk", 12, 10),
):
    require(
        name,
        r"\.halt_reg\s*=\s*0x0*1d4\b",
        rf"\.enable_reg\s*=\s*0x0*0ec\b",
        rf"\.enable_mask\s*=\s*BIT\({enable_bit}\)",
        rf"\.halt_bit\s*=\s*{halt_bit}\b",
    )
    if "BRANCH_HALT_SKIP" in branch(name):
        raise SystemExit(f"{name}: TV halt polling must remain enabled")

print("MSM8660_MMCC_SOURCE_GATE=PASS")
PY
