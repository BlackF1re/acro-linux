#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
kernel_src=${1:-/home/paul/xperia/src/linux}
target_dir="$kernel_src/arch/arm/boot/dts/qcom"
source_dts="$repo_root/kernel/dts/qcom-msm8260-sony-hikari.dts"
hardware_dtsi="$repo_root/kernel/dts/qcom-msm8260-sony-hikari-hardware.dtsi"
wireless_dtsi="$repo_root/kernel/dts/qcom-msm8260-sony-hikari-wireless.dtsi"
gpu_base_dtsi="$repo_root/kernel/dts/qcom-msm8260-sony-hikari-gpu-base.dtsi"
hardware_name=$(basename -- "$hardware_dtsi")
wireless_name=$(basename -- "$wireless_dtsi")
gpu_base_name=$(basename -- "$gpu_base_dtsi")
main_target="$target_dir/qcom-msm8260-sony-hikari.dts"

test -f "$source_dts" || { echo "missing project DTS: $source_dts" >&2; exit 1; }
for input in "$hardware_dtsi" "$wireless_dtsi" "$gpu_base_dtsi"; do
  test -f "$input" || { echo "missing project DTSI: $input" >&2; exit 1; }
done
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

# Source-backed additions not yet available in upstream: truthful AK8972
# matching and an IIO conversion of Sony's GPL APDS9702 driver.
python3 "$repo_root/scripts/apply-hikari-sensors.py" "$kernel_src"
python3 "$repo_root/scripts/apply-hikari-as3676-leds.py" "$kernel_src"

install -m 0644 "$source_dts" "$main_target"
for input in "$hardware_dtsi" "$wireless_dtsi" "$gpu_base_dtsi"; do
  install -m 0644 "$input" "$target_dir/$(basename -- "$input")"
done
for include_name in "$hardware_name" "$wireless_name" "$gpu_base_name"; do
	if ! rg -q "^#include \"${include_name//./\\.}\"$" "$main_target"; then
		printf '\n#include "%s"\n' "$include_name" >> "$main_target"
	fi
done

for obsolete in "$target_dir/qcom-msm8260-sony-hikari-gpu.dts" \
	"$target_dir/qcom-msm8260-sony-hikari-safe.dts"; do
	rm -f -- "$obsolete"
done

# Converge kernel trees previously prepared by the old three-profile build.
# Leaving these Makefile entries behind makes a plain `make dtbs` reference
# source files which no longer exist.
sed -i \
	-e '/qcom-msm8260-sony-hikari-gpu\.dtb/d' \
	-e '/qcom-msm8260-sony-hikari-safe\.dtb/d' \
	"$target_dir/Makefile"

for dtb in qcom-msm8260-sony-hikari.dtb; do
	if ! rg -q "${dtb//./\\.}" "$target_dir/Makefile"; then
		printf 'dtb-$(CONFIG_ARCH_QCOM) += %s\n' "$dtb" >> "$target_dir/Makefile"
	fi
done

echo "prepared $kernel_src with the single Hikari SYSTEM DTB"
