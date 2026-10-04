# Historical DTS-only patches

These three patches were already excluded from `kernel/patches/series`.
Their SCM node, BQ27520 G1 identity and unique DSI clock parents are carried
by `kernel/dts/`. Moving these unused copies does not change the build.
Retained for source provenance; do not apply them in addition to canonical DTS.
