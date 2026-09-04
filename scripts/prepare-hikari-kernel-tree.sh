#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
kernel_src=${1:-/home/paul/xperia/src/linux}
target_dir="$kernel_src/arch/arm/boot/dts/qcom"
source_dts="$repo_root/kernel/dts/qcom-msm8260-sony-hikari.dts"
hardware_dtsi="$repo_root/kernel/dts/qcom-msm8260-sony-hikari-hardware.dtsi"
hardware_name=$(basename -- "$hardware_dtsi")

test -f "$source_dts" || { echo "missing project DTS: $source_dts" >&2; exit 1; }
test -f "$hardware_dtsi" || { echo "missing project hardware DTSI: $hardware_dtsi" >&2; exit 1; }
test -f "$target_dir/qcom-msm8660.dtsi" || { echo "not an MSM8660-capable kernel tree: $kernel_src" >&2; exit 1; }

# These project-owned, idempotent source edits satisfy existing Qualcomm DT
# schemas; no third-party patch is being claimed or modified.
python3 - "$kernel_src" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])
edits = (
    (root / "Documentation/devicetree/bindings/arm/qcom.yaml",
     "              - qcom,msm8660-surf\n",
     "              - qcom,msm8660-surf\n              - sony,hikari\n"),
    (root / "arch/arm/boot/dts/qcom/qcom-msm8660.dtsi",
     "\tmemory {\n\t\tdevice_type = \"memory\";\n",
     "\tmemory@0 {\n\t\tdevice_type = \"memory\";\n"),
    (root / "arch/arm/boot/dts/qcom/qcom-msm8660.dtsi",
     "\t\tsleep-clk {\n",
     "\t\tsleep_clk: sleep-clk {\n"),
    (root / "arch/arm/boot/dts/qcom/qcom-msm8660.dtsi",
     "\t\t\treg = <0x02000000 0x100>;\n\t\t\tclock-frequency = <27000000>;\n",
     "\t\t\treg = <0x02000000 0x100>;\n\t\t\tclocks = <&sleep_clk>;\n\t\t\tclock-names = \"sleep\";\n\t\t\tclock-frequency = <27000000>;\n"),
    (root / "arch/arm/boot/dts/qcom/qcom-msm8660.dtsi",
     "\t\tamba {\n\t\t\tcompatible = \"simple-bus\";\n",
     "\t\tamba-bus {\n\t\t\tcompatible = \"simple-bus\";\n"),
)
for path, old, new in edits:
    text = path.read_text()
    if new in text:
        continue
    if old not in text:
        raise SystemExit(f"cannot find expected schema prerequisite in {path}")
    path.write_text(text.replace(old, new, 1))
PY

install -m 0644 "$source_dts" "$target_dir/qcom-msm8260-sony-hikari.dts"
install -m 0644 "$hardware_dtsi" "$target_dir/$hardware_name"
if ! rg -q "^#include \"${hardware_name//./\\.}\"$" "$target_dir/qcom-msm8260-sony-hikari.dts"; then
	printf '\n#include "%s"\n' "$hardware_name" >> "$target_dir/qcom-msm8260-sony-hikari.dts"
fi
if ! rg -q 'qcom-msm8260-sony-hikari\.dtb' "$target_dir/Makefile"; then
	printf '%s\n' 'dtb-$(CONFIG_ARCH_QCOM) += qcom-msm8260-sony-hikari.dtb' >> "$target_dir/Makefile"
fi
echo "prepared $kernel_src with qcom-msm8260-sony-hikari.dtb and $hardware_name"
