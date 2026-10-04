> Packaging update, 2026-10-05: the active series now has 17 final subsystem
> patches, including all former transforms. The numbered split below is
> historical. See [kernel/patches/README.md](../kernel/patches/README.md) and
> [FUNCTIONAL-PATCH-AUDIT.md](FUNCTIONAL-PATCH-AUDIT.md).

# Hikari source and patch audit — 2026-10-04

## Protected baseline

Signed source integration: `f7a6e62ff206edff9cee8c04226e85f1102a9a85`.
Exact original tree: `0f8c54cd473ea22c13407fd3ec5fb6d91347a0c2`.
The complete repository materializer reproduced that tree, including canonical
DTS, without relying on dirty files from the development worktree.

The connected SYSTEM remains unchanged and Phosh remains active on GLES2.
BOOT, production SD bundles, root SSH/USB access and diagnostic tools are
untouched. The historical full resolved config remains a provenance artifact.

## Initial subsystem export of the owner's port (before functional retirement)

| Active patch | Scope | Assessment |
|---|---|---|
| 0080 | A220 KGSL-derived lifecycle/shadow/MMU/context state | Preserve all hardware semantics |
| 0081 | Battery gauge, charger and adaptive input/cradle support | Preserve safety/watchdog policy; cradle needs working external hardware |
| 0082 | Per-core SAW regulators | Functional voltage sequencing, not diagnostic code |
| 0083 | Scorpion CPU/L2 DVFS | Functional but guarded for known fuse/boot state; not a general SoC driver yet |
| 0084 | RMI navigation strip/touch overlays | Functional input support |
| 0085 | Complete current Hikari board DTS | Canonical hardware configuration |
| 0086 | Startup log cleanup | Only informational logs/comments; no hardware sequencing changes |

0080–0085 preserve original authorship and identify the original integration
commit. Their combined tree is exactly the original signed tree. The original
monolithic 0079 export remains under `research/patches/superseded-integration/`.
Applying the split plus 0086 reproduces the compiled maintenance source tree.

## All-patch omission check

[audit-20261004.tsv](../kernel/patches/audit-20261004.tsv) records every one
of the 67 commits in the original materialized stack: 62 imported patches,
four strict corrections, and the original integration. For each commit,
replay all subsequent commits with that commit omitted, using an isolated
Git index over every touched file. No source worktree is changed.

- `CHANGES_FINAL_TREE`: omission changes final source content.
- `DEPENDENCY`: omission prevents a later patch from applying; not safely
  removable as-is, even if some early details were superseded later.
- `NO_FINAL_EFFECT`: omission applies and produces the exact same final tree.

No original active commit qualified as `NO_FINAL_EFFECT`. This check measures
source equivalence, not whether a hardware-specific branch executes in every
boot. It does not prove that every individual hunk remains essential. Removing
or folding dependencies needs a new equivalent reconstruction and acceptance.

Three inactive DTS-only copies (0034/0037/0059), already absent from `series`,
were moved to `research/patches/canonical-dts/`. SCM wiring, BQ27520 G1 matching
and DSI clock parents remain in canonical DTS. Their relocation has no build
effect. No working driver patch was removed on the basis of keywords such as
“legacy”, “debug register”, or “diagnostic”.

Reproduce an audit on any materialized stack:

```sh
scripts/audit-hikari-kernel-patches.py /path/to/materialized-kernel \
  --output-prefix /tmp/hikari-patch-audit
```

## Safe cleanup and retained code

Six C files were checked after stripping comments and informational log calls:
all remaining code is identical. Register writes, command packets, waits,
barriers, mapping, interrupt handling and regulator/clock transitions remain.
Detailed CPU/SAW/MMCC/SCM/DSI/A220 startup information now uses `dev_dbg`.
Error messages and safety checks remain.

The SYSTEM fragment selects `DEBUG_INFO_NONE` and disables KALLSYMS_ALL,
FW_LOADER_DEBUG, USB_GADGET_DEBUG_FILES and RCU_TRACE. Generated olddefconfig
confirmed these reductions. Dynamic debug, debugfs, pstore/ramoops, watchdog,
root login and diagnostic packages remain. DWARF removal primarily reduces
build artifacts; it is not claimed to improve runtime frame rate.

The per-submit GPU scratch/shadow markers are retained: removing GPU packets
would alter the already working command sequence and needs a separate physical
regression bracket. Global single-ring shadowing and hard-coded CPU boot/fuse
validation are functional implementation limits, not safe blind deletions.
DSI timeout/halt quirks and regulator-always-on declarations also remain.

## Verification and limits

- Six changed driver objects and Hikari DTB cross-built successfully.
- MMCC, display and AS3676 source gates passed.
- Six repository unit tests passed; whitespace checks passed.
- Split patch application exactly matches compiled maintenance source.
- No candidate was installed or booted. Physical cleanup acceptance is pending;
  the known-working SYSTEM was left running.
- Live CPU policies are absent. The latest saved build/source integration must
  not be confused with the currently running older image.

Hardware wiring, original authorship, source provenance and acceptance evidence
remain intact. Obsolete operational summaries are preserved in the document
archive and replaced in `docs/` by current instructions and explicit limits.

## Follow-up: functional rather than textual audit

See [FUNCTIONAL-PATCH-AUDIT.md](FUNCTIONAL-PATCH-AUDIT.md). The subsequent
review retired canceled LUT/DSI experiments and canonical-DTS duplicates while
preserving the entire prepared kernel tree exactly. The earlier 67-commit
omission table remains historical evidence; it is not the current patch count
or a proof that every intermediate experiment must remain active.
