#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Static gate for the dedicated Hikari Adreno A220 DT profile.
set -euo pipefail

usage() {
  echo "usage: $0 --config PATH --dtb PATH" >&2
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
[[ -f $config && -f $dtb ]] || usage
command -v fdtget >/dev/null || { echo 'fdtget is required' >&2; exit 1; }

for required in CONFIG_DRM=y CONFIG_DRM_MSM=y CONFIG_MSM_MMCC_8660=y \
                CONFIG_PM_OPP=y CONFIG_FW_LOADER=y; do
  grep -qx "$required" "$config" || {
    echo "HIKARI_GPU_PROFILE=FAIL missing $required" >&2
    exit 1
  }
done

node=/gpu@4300000
[[ $(fdtget "$dtb" "$node" status) == okay ]] || {
  echo 'HIKARI_GPU_PROFILE=FAIL gpu node is not enabled' >&2
  exit 1
}
compat=$(fdtget "$dtb" "$node" compatible)
[[ $compat == *qcom,adreno-220.0* && $compat == *qcom,adreno* ]] || {
  echo "HIKARI_GPU_PROFILE=FAIL unexpected compatible: $compat" >&2
  exit 1
}
reg=$(fdtget -t x "$dtb" "$node" reg)
[[ $reg == "4300000 20000" ]] || {
  echo "HIKARI_GPU_PROFILE=FAIL unexpected reg: $reg" >&2
  exit 1
}
irq=$(fdtget -t x "$dtb" "$node" interrupts)
[[ $irq == "0 50 4" ]] || {
  echo "HIKARI_GPU_PROFILE=FAIL unexpected interrupt tuple: $irq" >&2
  exit 1
}

names=$(fdtget "$dtb" "$node" clock-names)
for name in core iface mem_iface bus; do
  case " $names " in *" $name "*) ;; *)
    echo "HIKARI_GPU_PROFILE=FAIL clock name $name missing: $names" >&2
    exit 1
  esac
done

# Keep the display and verified USB diagnostics present in the GPU profile;
# this profile is an extension of the normal Hikari DTS, not a replacement.
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
"$repo_root/scripts/check-hikari-boot5-interactive.sh" --config "$config" --dtb "$dtb"
"$repo_root/scripts/check-hikari-persistent-ram.sh" --config "$config" --dtb "$dtb"

echo 'HIKARI_GPU_PROFILE=PASS'
echo 'gpu=Adreno-A220; mmio=0x04300000/0x20000; irq=SPI80; usb=retained; ramoops=retained'
