# Kernel patch maintenance

The reproducible kernel is a pinned upstream Linux source plus the maintained
series in [`../kernel/patches/`](../kernel/patches/). The series is applied by
the materializer and guarded by the expected prepared-tree hash. The current
subsystem ownership and per-patch map are in
[`kernel/patches/README.md`](../kernel/patches/README.md).

The maintained patches include functional Hikari support for clocks and power,
storage and connectivity, sensors and controls, native display, and the A220
DRM/MSM lifecycle. The A220 KGSL-derived shadow banks, CP-ordered MMU sync,
waits and context rearm are required parts of the physically working GPU path;
do not remove them as diagnostic residue. Temporary register experiments and
abandoned Mesa/KGSL candidates are not part of the production series.

The historical source omission audit found that removing an earlier active
change either alters the final tree or breaks a later dependency. This is a
source-equivalence result, not proof that every hardware branch has passed
physical acceptance. The consolidated patch inventory preserves original
authors and source provenance. `kernel/patches/functional-audit.tsv` records
current runtime and evidence limits.

Rebuild and validate source without changing the device:

```sh
scripts/materialize-hikari-kernel.sh /tmp/linux-hikari-audit
scripts/check-hikari-kernel-source.sh /tmp/linux-hikari-audit
scripts/check-hikari-debian.sh
```

Physical subsystem acceptance and outstanding limits are recorded in
[`HARDWARE.md`](HARDWARE.md), [`STATUS.md`](STATUS.md) and
[`TESTING.md`](TESTING.md). A source audit or successful build is not physical
hardware validation.
