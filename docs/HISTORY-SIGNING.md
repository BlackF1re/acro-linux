# Signed and consolidated history — 2026-10-05

The owner explicitly requested re-signing the complete published history,
including older unsigned commits. At the initial audit, 192 commits were reachable
from main: 128 carried signatures and 64 did not. Recent maintenance commits
were already signed.

A verified local Git bundle preserves the original history before rewriting.
Every rewritten commit retains its exact source tree, original author and
original author timestamp. Merge-parent topology is preserved through the
old-to-new commit mapping. Original commit messages are preserved.
The documentation commit adds another signed commit before the rewrite.

The project maintainer becomes the committer and cryptographic signer of the
rewritten history. This does not claim the original authors signed the rewritten
objects. Original committer metadata, signatures/status and the old-to-new mapping
are retained in the host-side signing audit. Existing signed commits must also be
re-created wherever changed parent IDs invalidate their old signatures.

Published commit IDs change. Existing clones should fetch and preserve any local
work before reconciling with the rewritten main; old commit links may no longer
represent current ancestry. The rewrite changes history/provenance, not kernel,
userspace or device behaviour. Force push uses an explicit lease on the previous
remote tip. Only main is published.

## Verified result

All **193 rewritten commits** passed cryptographic verification. Each original
tree, message, author/timestamp and merge-parent topology matched exactly.
The [public mapping](history-signing-map.tsv) records old/new IDs and original
committer metadata. The publication-audit commit following the rewrite is also
signed. This section describes the earlier signing pass, before the consolidation below.

Verified pre-rewrite bundle (kept locally, outside git):
`/home/paul/xperia/build/history-signing-20261005/before-rewrite.bundle`

Bundle SHA256:
`2407f06d1a69695f49521bc2000bcfe560b14df11ba13d8230e6ee749b4b234b`

Existing clones: preserve local changes/commits, then fetch origin and compare
against rewritten main. Do not blindly hard-reset local work. Original kernel
source commit IDs in imported patches belong to separate kernel repositories
and were not rewritten. Device code and boot/runtime were not changed.

## Logical checkpoint consolidation

At the owner's request, the subsequent **196-commit** published history was
consolidated into **61 signed commits**: 60 logical development checkpoints
and one metadata/documentation cleanup commit.

- Adjacent fixes, build corrections and their test records are grouped by purpose.
- Individual feature milestones remain separate; this is not a single source dump.
- Merge results are retained as checkpoints in one linear `main` history.
- The original author and timestamp of each group's final checkpoint are retained.
  All grouped repository commits belong to the same project maintainer.
- Human authorship, copyright and licences of imported source patches are retained.
- Patch metadata was cleaned up and affected checksums refreshed; **every patch's
  actual source diff is byte-identical**. Kernel, Mesa and device behaviour are unchanged.
- The complete original history and group-to-original commit mapping are retained
  locally, outside the published repository.
- Every new commit is signed and cryptographically verified before publication.

The earlier [signing map](history-signing-map.tsv) remains a dated provenance
record; its destination IDs belong to the history **before consolidation**.
It is not a map to the new `main` ancestry.

Verified consolidation backup:
`/home/paul/xperia/build/history-cleanup-20261005/before-cleanup.bundle`.

Backup SHA256:
`788c831b183187ac192d7234a2054d2a5e9c1a1695152ab0d26692e206e37be5`.

Publication uses `--force-with-lease` against the recorded previous remote tip.
Existing clones must preserve local changes and branches before reconciling
with the rewritten `main`. Do not blindly reset or discard local work.
