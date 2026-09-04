#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Apply strict source-backed MSM8x60 MMCC corrections."""
from pathlib import Path
import re
import sys

if len(sys.argv) != 2:
    raise SystemExit(f"usage: {sys.argv[0]} KERNEL_SRC")

path = Path(sys.argv[1]) / "drivers/clk/qcom/mmcc-msm8660.c"
text = path.read_text()


def rewrite_branch(name: str, replacements: list[tuple[str, str]]) -> None:
    global text
    pattern = re.compile(rf"static struct clk_branch {re.escape(name)} = \{{.*?\n\}};", re.S)
    match = pattern.search(text)
    if not match:
        raise SystemExit(f"missing clk_branch {name}")
    body = match.group(0)
    for old, new in replacements:
        count = body.count(old)
        if count != 1:
            raise SystemExit(f"{name}: expected one historical pattern {old!r}, found {count}")
        body = body.replace(old, new, 1)
    text = text[:match.start()] + body + text[match.end():]


rewrite_branch("vpe_axi_clk", [
    ("\t\t.enable_reg = 0x0018,", "\t\t.enable_reg = 0x0020,"),
    ("\t\t\t.flags = CLK_IS_CRITICAL,\n", ""),
])
rewrite_branch("rot_axi_clk", [
    ("\t\t.enable_mask = BIT(22),", "\t\t.enable_mask = BIT(24),"),
])
rewrite_branch("mmss_imem_ahb_clk", [
    ("\t.halt_bit = 12,", "\t.halt_bit = 10,"),
    ("\t\t\t.flags = CLK_IS_CRITICAL,\n", ""),
])
rewrite_branch("vcodec_ahb_clk", [
    ("\t.halt_bit = 10,", "\t.halt_bit = 12,"),
    ("The halt bit at 0x01dc[10] does not settle", "The halt bit at 0x01dc[12] does not settle"),
])

path.write_text(text)
print("MSM8660_MMCC_CORRECTION=APPLIED")
