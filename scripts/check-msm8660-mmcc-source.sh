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


def require(name: str, *patterns: str, forbid_critical: bool = False) -> None:
    body = branch(name)
    for pattern in patterns:
        if not re.search(pattern, body, re.S):
            raise SystemExit(f"{name}: missing expected source pattern: {pattern}")
    if forbid_critical and "CLK_IS_CRITICAL" in body:
        raise SystemExit(f"{name}: must not be CLK_IS_CRITICAL on MSM8x60")

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
