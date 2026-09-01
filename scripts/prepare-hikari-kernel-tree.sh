#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
kernel_src=${1:-/home/paul/xperia/src/linux}
target_dir="$kernel_src/arch/arm/boot/dts/qcom"
source_dts="$repo_root/kernel/dts/qcom-msm8260-sony-hikari.dts"

test -f "$source_dts" || { echo "missing project DTS: $source_dts" >&2; exit 1; }
test -f "$target_dir/qcom-msm8660.dtsi" || { echo "not an MSM8660-capable kernel tree: $kernel_src" >&2; exit 1; }

install -m 0644 "$source_dts" "$target_dir/qcom-msm8260-sony-hikari.dts"
if ! rg -q 'qcom-msm8260-sony-hikari\.dtb' "$target_dir/Makefile"; then
	printf '%s\n' 'dtb-$(CONFIG_ARCH_QCOM) += qcom-msm8260-sony-hikari.dtb' >> "$target_dir/Makefile"
fi
echo "prepared $kernel_src with qcom-msm8260-sony-hikari.dtb"
