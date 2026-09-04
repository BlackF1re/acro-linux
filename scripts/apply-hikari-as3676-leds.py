#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Install the source-verified Hikari AS3676 LED/backlight implementation."""

from pathlib import Path
import sys

if len(sys.argv) != 2:
    raise SystemExit(f"usage: {sys.argv[0]} KERNEL_TREE")

kernel = Path(sys.argv[1])
repo = Path(__file__).resolve().parent.parent
driver = kernel / "drivers/video/backlight/as3676-backlight.c"
kconfig = kernel / "drivers/video/backlight/Kconfig"
override = repo / "kernel/overrides/as3676-backlight.c"

text = driver.read_text()
markers = (
    "#define AS3676_CURR6\t\t0x2f",
    "#define AS3676_ID1_VALUE\t0xae",
    "devm_backlight_device_register",
    'MODULE_DESCRIPTION("AS3676 Hikari LCD backlight")',
)
for marker in markers:
    if marker not in text:
        raise SystemExit(f"unexpected pre-LED AS3676 source; missing: {marker}")

driver.write_text(override.read_text())

kt = kconfig.read_text()
old = '''config BACKLIGHT_AS3676
\ttristate "AMS AS3676 Hikari backlight"
\tdepends on I2C
'''
new = '''config BACKLIGHT_AS3676
\ttristate "AMS AS3676 Hikari backlight and LEDs"
\tdepends on I2C && LEDS_CLASS
'''
if old not in kt:
    raise SystemExit("unexpected BACKLIGHT_AS3676 Kconfig block")
kconfig.write_text(kt.replace(old, new, 1))
