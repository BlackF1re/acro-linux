#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
# Compatibility entry point: validate patch-provided sources; never edit them.
set -euo pipefail
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
kernel_src=${1:-/home/paul/xperia/src/linux-hikari-current}
python3 - "$repo_root" "$kernel_src" <<'PY'
from pathlib import Path
import sys

repo, root = map(Path, sys.argv[1:])
target = root / 'arch/arm/boot/dts/qcom'
for source in sorted((repo / 'kernel/dts').glob('qcom-msm8260-sony-hikari.*')):
    destination = target / source.name
    if not destination.is_file() or destination.read_bytes() != source.read_bytes():
        raise SystemExit(f'{destination}: differs from canonical DTS; update/apply board patch, not build-time edits')
# .dtsi names have suffixes, so include all canonical board fragments explicitly.
for name in ('hardware', 'wireless', 'gpu-base'):
    source = repo / f'kernel/dts/qcom-msm8260-sony-hikari-{name}.dtsi'
    destination = target / source.name
    if not destination.is_file() or destination.read_bytes() != source.read_bytes():
        raise SystemExit(f'{destination}: missing or different; apply the board subsystem patch')
requirements = {
    'Documentation/devicetree/bindings/arm/qcom.yaml': ['- sony,hikari'],
    'arch/arm/boot/dts/qcom/qcom-msm8660.dtsi': [
        'memory@0 {', 'sleep_clk: sleep-clk {', 'clocks = <&sleep_clk>;',
        'clock-names = "sleep";', 'amba-bus {',
    ],
    'arch/arm/boot/dts/qcom/Makefile': ['qcom-msm8260-sony-hikari.dtb'],
}
for name, markers in requirements.items():
    path = root / name
    if not path.is_file():
        raise SystemExit(f'missing patch-provided file: {path}')
    text = path.read_text()
    if any(marker not in text for marker in markers):
        raise SystemExit(f'{path}: board patch prerequisites missing; materialize the pinned series')
for name in ('gpu', 'safe'):
    if (target / f'qcom-msm8260-sony-hikari-{name}.dts').exists():
        raise SystemExit('obsolete multi-profile DTS found; refusing to delete source files during build')
    if f'qcom-msm8260-sony-hikari-{name}.dtb' in (target / 'Makefile').read_text():
        raise SystemExit('obsolete multi-profile DTB target found; update its source patch')
print(f'HIKARI_PATCH_PROVIDED_BOARD=PASS source={root}')
PY
