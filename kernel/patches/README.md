# Hikari subsystem patch stack

`../source.lock` pins the upstream base and expected complete prepared tree.
`series` now contains **21 maintained patches**, including all
previous strict-transform and integration results. `post-series` is empty.
The materializer applies only this series and checks the exact final tree.

| Patch | Subsystem |
|---|---|
| 0001 | Clocks, resets and clock power domains |
| 0002 | SCM protected register access |
| 0003 | Interconnect / RPM fabrics |
| 0004 | PMIC / MPP |
| 0005 | CPU frequency and SAW voltage coordination |
| 0006 | Battery and charging |
| 0007 | Thermal / TSENS calibration |
| 0008 | USB PHY |
| 0009 | MMC |
| 0010 | Watchdog |
| 0011 | Touch and navigation input |
| 0012 | IIO sensors |
| 0013 | Backlight, LEDs and ALS |
| 0014 | Display / MDP4 / DSI / PHY / panel |
| 0015 | A220 GPU lifecycle and MMU |
| 0016 | IOMMU binding |
| 0017 | Canonical board DTS and shared SoC DT prerequisites |
| 0018 | Power management |
| 0019 | A220 suspend IRQ diagnostic handling |
| 0020 | FM radio |
| 0021 | Hikari audio bring-up (Timpani power/control and QDSP6v3 remoteproc; PCM pending) |

`subsystems.json` maps every final source file and original patch to its new
subsystem. A mixed original patch may contribute to multiple new patches.
Original mail exports/messages/authors/trailers and the component audit are
preserved unchanged under `research/patches/pre-subsystem-series-20261005/`.
Consolidated messages include Original-author trailers; consolidation is not
an assertion of sole authorship or upstream acceptance.

`functional-expectations.json` retains the individual component reviews.
`functional-audit.tsv` is the current generated per-subsystem audit; it does
not imply that every branch was physically exercised.

The four old transform scripts remain diagnostic/provenance utilities. Neither
the materializer nor board preparation applies them now. The old history
exporter is for historical imports; do not use it to replace the final series.

Update the relevant subsystem patch when changing its code. Keep independent
subsystems separate. For DT updates, update both the board patch and canonical
`kernel/dts/` copies. After a deliberate source change, update the locked tree
only after source/build/device checks. Never bypass the equivalence guard just
to accept an unexplained difference. Binaries/firmware remain outside git.


Source preparation is read-only: all board/schema/source changes must be in
these patches. The default build source is `src/linux-hikari-current`, a fresh
materialization rather than the older dirty `src/linux` worktree. Historical
direct edits are preserved separately in the research archive, never applied
implicitly. Divergent canonical DTS or obsolete profiles cause an error.
