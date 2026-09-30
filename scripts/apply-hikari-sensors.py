#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Apply small source-backed Hikari sensor support to a Linux tree."""

from pathlib import Path
import sys

if len(sys.argv) != 2:
    raise SystemExit(f"usage: {sys.argv[0]} KERNEL_TREE")

kernel = Path(sys.argv[1])
repo = Path(__file__).resolve().parent.parent

def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text()
    if new in text:
        return
    if old not in text:
        raise SystemExit(f"unexpected source in {path}; missing {old!r}")
    path.write_text(text.replace(old, new, 1))

# AKM8972 has the AK8975 WIA value, register map, modes, fuse calibration and
# sensitivity. Keep its truthful DT name while sharing the existing definition.
ak = kernel / "drivers/iio/magnetometer/ak8975.c"
replace_once(
    ak,
    '\t{ .name = "ak8975", .driver_data = (kernel_ulong_t)&ak_def_array[AK8975] },\n',
    '\t{ .name = "ak8972", .driver_data = (kernel_ulong_t)&ak_def_array[AK8975] },\n'
    '\t{ .name = "ak8975", .driver_data = (kernel_ulong_t)&ak_def_array[AK8975] },\n',
)
replace_once(
    ak,
    '\t{ .compatible = "asahi-kasei,ak8975", .data = &ak_def_array[AK8975] },\n',
    '\t{ .compatible = "asahi-kasei,ak8972", .data = &ak_def_array[AK8975] },\n'
    '\t{ .compatible = "asahi-kasei,ak8975", .data = &ak_def_array[AK8975] },\n',
)

binding = kernel / "Documentation/devicetree/bindings/iio/magnetometer/asahi-kasei,ak8975.yaml"
replace_once(
    binding,
    "          - asahi-kasei,ak8975\n",
    "          - asahi-kasei,ak8972\n          - asahi-kasei,ak8975\n",
)

(kernel / "drivers/iio/proximity/apds9702.c").write_text(
    (repo / "kernel/overrides/apds9702.c").read_text()
)
(kernel / "Documentation/devicetree/bindings/iio/proximity/avago,apds9702.yaml").write_text(
    (repo / "kernel/bindings/avago,apds9702.yaml").read_text()
)

replace_once(
    kernel / "drivers/iio/proximity/Kconfig",
    'menu "Proximity and distance sensors"\n',
    'menu "Proximity and distance sensors"\n\n'
    'config APDS9702\n'
    '\ttristate "Avago APDS9702 proximity sensor"\n'
    '\tdepends on I2C && GPIOLIB\n'
    '\thelp\n'
    '\t  Enable IIO support for the APDS9702 digital proximity sensor.\n'
    '\t  To compile this driver as a module, choose M here.\n',
)
replace_once(
    kernel / "drivers/iio/proximity/Makefile",
    "# When adding new entries keep the list in alphabetical order\n",
    "# When adding new entries keep the list in alphabetical order\n"
    "obj-$(CONFIG_APDS9702)\t\t+= apds9702.o\n",
)
