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
binding = kernel / "Documentation/devicetree/bindings/leds/ams,as3676-backlight.yaml"
override = repo / "kernel/overrides/as3676-backlight.c"
binding_override = repo / "kernel/bindings/ams,as3676-backlight.yaml"

text = driver.read_text()
if 'MODULE_DESCRIPTION("AS3676 backlight' not in text:
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
binding.write_text(binding_override.read_text())

kt = kconfig.read_text()
new = '''config BACKLIGHT_AS3676
\ttristate "AMS AS3676 Hikari backlight, LEDs and ALS"
\tdepends on I2C && LEDS_CLASS && IIO
'''
old_blocks = (
    '''config BACKLIGHT_AS3676
\ttristate "AMS AS3676 Hikari backlight"
\tdepends on I2C
''',
    '''config BACKLIGHT_AS3676
\ttristate "AMS AS3676 Hikari backlight and LEDs"
\tdepends on I2C && LEDS_CLASS
''',
    '''config BACKLIGHT_AS3676
\ttristate "AMS AS3676 Hikari backlight and LEDs"
\tdepends on I2C && LEDS_CLASS && IIO
''',
	'''config BACKLIGHT_AS3676
\ttristate "AMS AS3676 Hikari backlight, LEDs and ALS"
\tdepends on I2C && LEDS_CLASS && IIO
''',
)
if new not in kt:
    for old in old_blocks:
        if old in kt:
            kconfig.write_text(kt.replace(old, new, 1))
            break
    else:
        raise SystemExit("unexpected BACKLIGHT_AS3676 Kconfig block")
