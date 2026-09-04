# Hikari kernel patch stack

This directory makes the project independent of a developer-specific external
kernel worktree.

`../source.lock` pins the Linus base revision. `series` lists mail patches in
application order. `scripts/materialize-hikari-kernel.sh` clones the pinned
base and applies the series with `git am --3way`, preserving patch authorship,
commit messages and Signed-off-by trailers.

The current historical worktree can be imported once with
`scripts/export-hikari-kernel-patches.sh`. The exporter refuses a dirty source
tree and records a SHA-to-patch manifest so the imported history remains
auditable.

Rules:

- third-party commits stay author-preserved and retain their original trailers;
- project-owned fixes remain separate, small and bisectable;
- generated kernels, DTBs, initramfs archives and firmware do not belong here;
- a patch must not be silently edited after hardware evidence has been recorded;
  supersede it with a later patch instead;
- `series` is the canonical application order.

Until `series` contains the exported current worktree, the materializer will
fail rather than silently construct an incomplete Hikari kernel.
