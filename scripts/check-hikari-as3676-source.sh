#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
set -euo pipefail

kernel=${1:?usage: $0 KERNEL_TREE}
driver="$kernel/drivers/video/backlight/as3676-backlight.c"
kconfig="$kernel/drivers/video/backlight/Kconfig"

test -f "$driver" && test -f "$kconfig"
grep -q 'AS3676_RGB1.*0x0b' "$driver"
grep -q 'AS3676_RGB2.*0x0c' "$driver"
grep -q 'AS3676_RGB3.*0x0d' "$driver"
grep -q 'AS3676_CURR41.*0x13' "$driver"
grep -q 'AS3676_CURR42.*0x14' "$driver"
grep -q 'AS3676_CURR43.*0x15' "$driver"
grep -q '"button-backlight"' "$driver"
grep -q '"red"' "$driver"
grep -q '"green"' "$driver"
grep -q '"blue"' "$driver"
grep -q 'HIKARI_LED_MAX_UA.*20000' "$driver"
grep -q 'u8 current_code = as3676_led_current(brightness);' "$driver"
if grep -q 'u8 current = as3676_led_current(brightness);' "$driver"; then
	echo 'AS3676 source reintroduced collision with the kernel current macro' >&2
	exit 1
fi

# Exact Sony Ericsson Hikari AS3676 DC/DC startup.  Merely programming current
# sinks 1/2/6 is insufficient if the LCD step-up converter was never started.
grep -q 'HIKARI_AS3676_DCDC1.*0x62' "$driver"
grep -q 'HIKARI_AS3676_DCDC2_PRECHARGE.*0x0c' "$driver"
grep -q 'HIKARI_AS3676_CONTROL_ON.*0x0d' "$driver"
grep -q 'HIKARI_AS3676_DCDC2_ON.*0x8c' "$driver"
grep -q 'HIKARI_AS3676_STARTUP_US.*12000' "$driver"
python3 - "$driver" <<'PY'
from pathlib import Path
import sys

text = Path(sys.argv[1]).read_text()
sequence = [
    'regmap_write(as->regmap, AS3676_DCDC1, HIKARI_AS3676_DCDC1)',
    'regmap_write(as->regmap, AS3676_DCDC2,',
    'HIKARI_AS3676_DCDC2_PRECHARGE',
    'regmap_write(as->regmap, AS3676_CONTROL,',
    'HIKARI_AS3676_CONTROL_ON',
    'usleep_range(HIKARI_AS3676_STARTUP_US,',
    'regmap_write(as->regmap, AS3676_DCDC2, HIKARI_AS3676_DCDC2_ON)',
]
pos = -1
for needle in sequence:
    new = text.find(needle, pos + 1)
    if new < 0:
        raise SystemExit(f'AS3676 missing ordered Hikari startup step: {needle}')
    pos = new
PY

grep -A2 '^config BACKLIGHT_AS3676$' "$kconfig" | grep -q 'depends on I2C && LEDS_CLASS'

echo HIKARI_AS3676_SOURCE_GATE=PASS
