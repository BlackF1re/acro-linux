# Signed history — 2026-10-05

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
signed. Current reachable main contains no unsigned commit.

Verified pre-rewrite bundle (kept locally, outside git):
`/home/paul/xperia/build/history-signing-20261005/before-rewrite.bundle`

Bundle SHA256:
`2407f06d1a69695f49521bc2000bcfe560b14df11ba13d8230e6ee749b4b234b`

Existing clones: preserve local changes/commits, then fetch origin and compare
against rewritten main. Do not blindly hard-reset local work. Original kernel
source commit IDs in imported patches belong to separate kernel repositories
and were not rewritten. Device code and boot/runtime were not changed.
