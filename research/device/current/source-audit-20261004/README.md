# Individual patch audit evidence — 2026-10-04

See `docs/FUNCTIONAL-PATCH-AUDIT.md` and the 64-row active / 26-row archived
inventories under `kernel/patches/`. No replacement kernel was deployed.

- `hikari-patch-audit/`: accepted 56-draw GPU transition, maps and function hits.
- `hikari-display-audit/`: successful glmark2 Wayland scene, maps and hits.
- `device-selector.log`: read-only actual qcom_find_freq comparison for 0044.
- `compiled-objects.txt`: 33 active mail-patch C units built; additionally
  ak8975.o and apds9702.o built for the sensor transform.
- `sensors-and-config.txt`: actual raw IIO reads, without controlled stimuli.
- `dt-schema-errors.log`: existing schema defects; validator exit 0 is not PASS.
- `SHA256SUMS`: evidence integrity.

Function entry counts do not prove every changed branch or isolated necessity.
Raw dmesg and full host build outputs stay outside git to avoid committing
unrelated identifiers. No GPU faults observed in the captured runs. Wi-Fi
subsequently failed SDIO access; final access is USB, Phosh remains GLES2.
All temporary tracing/module probes were cleaned up; brightness restored.

Exported text maps/logs have trailing spaces removed; original raw outputs
remain in the host build directory. No measured values were changed.
