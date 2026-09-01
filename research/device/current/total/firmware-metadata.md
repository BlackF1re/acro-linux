# Module and firmware metadata

This inventory records names, sizes and hashes only; no proprietary blob was
copied into the repository.

| Object | Size | SHA-256 | Evidence |
| --- | ---: | --- | --- |
| /system/lib/modules/bcm4330.ko | 4,857,355 bytes | 9182c04368786bc0be1a12e898528f0964df0b54c1abaf4091b4b24cfe71b607 | loaded module; init references it |
| /system/etc/firmware/BCM4330.hcd | 51,526 bytes | 198816a65d1fe40d8910523683f22872ceb451b4aa385268c201f6e01f943db6 | legacy Bluetooth patchram input |

The only loaded module listed by /proc/modules was bcm4330, marked out of
tree by the legacy kernel. `init.semc.rc` supplies
`nvram_path=/system/etc/wifi/calibration`; it also supplies the BCM4330 HCD
path shown above. The calibration file's contents were not read and its hash
is intentionally omitted because it may be board-specific calibration. Safe
name/path evidence is in [bcm4330-legacy-paths.txt](bcm4330-legacy-paths.txt).
