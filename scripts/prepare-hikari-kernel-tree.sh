#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
kernel_src=${1:-/home/paul/xperia/src/linux}
target_dir="$kernel_src/arch/arm/boot/dts/qcom"
source_dts="$repo_root/kernel/dts/qcom-msm8260-sony-hikari.dts"
hardware_dtsi="$repo_root/kernel/dts/qcom-msm8260-sony-hikari-hardware.dtsi"
wireless_dtsi="$repo_root/kernel/dts/qcom-msm8260-sony-hikari-wireless.dtsi"
safe_dtsi="$repo_root/kernel/dts/qcom-msm8260-sony-hikari-safe.dtsi"
hardware_name=$(basename -- "$hardware_dtsi")
wireless_name=$(basename -- "$wireless_dtsi")
safe_name=$(basename -- "$safe_dtsi")
main_target="$target_dir/qcom-msm8260-sony-hikari.dts"
safe_target="$target_dir/qcom-msm8260-sony-hikari-safe.dts"

test -f "$source_dts" || { echo "missing project DTS: $source_dts" >&2; exit 1; }
test -f "$hardware_dtsi" || { echo "missing project hardware DTSI: $hardware_dtsi" >&2; exit 1; }
test -f "$wireless_dtsi" || { echo "missing project wireless DTSI: $wireless_dtsi" >&2; exit 1; }
test -f "$safe_dtsi" || { echo "missing project safe-profile DTSI: $safe_dtsi" >&2; exit 1; }
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

install -m 0644 "$source_dts" "$main_target"
install -m 0644 "$hardware_dtsi" "$target_dir/$hardware_name"
install -m 0644 "$wireless_dtsi" "$target_dir/$wireless_name"
install -m 0644 "$safe_dtsi" "$target_dir/$safe_name"
for include_name in "$hardware_name" "$wireless_name"; do
	if ! rg -q "^#include \"${include_name//./\\.}\"$" "$main_target"; then
		printf '\n#include "%s"\n' "$include_name" >> "$main_target"
	fi
done

# Build the USB-safe profile from the exact final normal DTS, then append only
# the small disablement overlay.  This prevents the fallback from silently
# drifting away from storage, input, charging, radio or USB wiring fixes.
cp -- "$main_target" "$safe_target"
printf '\n#include "%s"\n' "$safe_name" >> "$safe_target"

for dtb in qcom-msm8260-sony-hikari.dtb qcom-msm8260-sony-hikari-safe.dtb; do
	if ! rg -q "${dtb//./\\.}" "$target_dir/Makefile"; then
		printf 'dtb-$(CONFIG_ARCH_QCOM) += %s\n' "$dtb" >> "$target_dir/Makefile"
	fi
done

echo "prepared $kernel_src with Hikari display and USB-safe DTBs"
