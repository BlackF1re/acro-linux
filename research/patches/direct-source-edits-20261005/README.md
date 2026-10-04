# Historical direct source edits — 2026-10-05

This is a lossless snapshot of uncommitted changes in the older
`/home/paul/xperia/src/linux` worktree at commit
`33452d3bca12bae8ee3bd82ab5675278f7a25837`. It is **not the current SYSTEM
source** and these patches are **not active build input**.

All 46 changed/untracked source files were exported into 11 subsystem deltas.
A separate temporary Git index replayed every delta from the exact base:
resulting tree `7b7704e63e3e3b71eb53485a68907bef73c58803` matches the snapshot
exactly. The original worktree and real Git index were not changed.
Uncommitted authorship is UNKNOWN; no author is invented by the exporter.

`coverage.tsv` compares each complete file to the current patched SYSTEM:
32 are identical; 11 differ; 3 exist only in this historical tree. In particular,
old alternate GPU/safe DTS fragments and an older cpufreq binding are not
silently promoted into production. Source paths are recorded for provenance,
not as an instruction to build this old branch.

The current SYSTEM changes relative to the pinned upstream base are already
represented by the 17 active patches in `kernel/patches/series`. Their complete
source tree is `e3d73fd2f7bffefd6e42b0ec789d4e0af81fde45`.

To reproduce this historical snapshot, create a **separate detached worktree**
at the base commit, then apply the raw diffs in `series` order using `git apply`.
Never apply them to the current subsystem series or reset the working kernel
tree merely to clean up its historical edits. No kernel/runtime was deployed.
