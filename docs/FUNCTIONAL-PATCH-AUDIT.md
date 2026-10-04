# Current packaging — 2026-10-05

The maintained series is now **17 patches, one per subsystem**, with no active
strict transforms or post-series. The 60-patch/4-transform audit below is a
historical review preserved unchanged in the archive. Current component
reviews and generated coverage are in
[functional-expectations.json](../kernel/patches/functional-expectations.json)
and [functional-audit.tsv](../kernel/patches/functional-audit.tsv).
All 64 earlier component reviews are retained, plus a canonical-board review.
Both independently materialized source trees are identical:
`e3d73fd2f7bffefd6e42b0ec789d4e0af81fde45`.
Consolidation does not supply missing physical necessity tests.

---

# Functional patch audit — 2026-10-04

This supersedes the interpretation of the earlier omission audit: textual
patch dependency is not proof of runtime usefulness. Added-line survival is
also not sufficient: a deletion or interface change can matter without leaving
any attributable added line.

## Concrete retirements

| Intermediate patch | Actual fate | Maintained implementation |
|---|---|---|
| 0047 LUT alias | Entire temporary alias removed by 0048 | 0048b emits final distinct CCF wrapper directly |
| 0053 DSI pixel ops | Both ops/flags additions reversed by 0057 | 0057b emits final divider table without the experiment |
| 0011 Hikari DTS clock names | Intermediate file overwritten by canonical DTS | Unchanged `kernel/dts/` clock names |
| 0085 board-file integration | Duplicates canonical DTS installation | Unchanged four canonical board files |
| Board DTS part of 0009 | Intermediate file overwritten | 0009b keeps drivers/bindings; canonical DTS supplies board data |

These are not claims that the final LUT wrapper or DSI divider does nothing.
Live clocks confirm MDP_LUT is enabled at 200 MHz and DSI_PIXEL at 69.672960
MHz. The final implementations must stay. Only canceled/duplicate stages have
been retired. Original exports remain in the research archive with authorship.

## Strong equivalence check

The reduced series was reconstructed from the pinned base in a new external
kernel tree, including all four strict transforms and final canonical board
preparation. The complete prepared source tree, including every GPU file, is
exactly identical to the previously compiled maintenance source:

`647d27c053892b371aed58fd1c6e2f94866e031c`.

This checks the *prepared* tree, rather than only the pre-DTS commit tree.
It detects differences across all files, not merely across selected hunks.
Source gates and six repository tests passed. No new hardware semantics or
kernel image was installed. BOOT and the known-working SYSTEM are unchanged.

## Whole-stack inventory

[functional-audit-20261004.tsv](../research/patches/pre-subsystem-series-20261005/functional-audit-20261004.tsv)
lists **all 60 remaining active mail patches**, their affected files,
execution gates and retention assessment. Four additional strict transforms
are run by the materializer: MMCC corrections, display finalization, AS3676
LED/ALS support, and sensor integration. They remain required source-backed
port functionality and are not omitted from the total.

Runtime subsystem binding proves that a driver is in use; it does not prove
that every branch inside every patch executed. Accordingly the inventory does
not relabel untested paths as verified. Schema/ABI-only patches intentionally
have no GPU instructions and must not be removed as “no-op” patches.

Bound runtime subsystems observed: MMCC, SCM, DSI/PHY, four interconnect
fabrics, PM8901/PM8058 MPP, TSENS, RMI touch, BQ24160, BQ27xxx and AS3676.
CPU DVFS/SAW support is enabled in the latest source/build profile, but no live
cpufreq policy is exposed by the currently booted older image. That does not
make the source port useless. Suspend, reboot/watchdog, OTG, thermal protection,
HDMI/camera and cradle paths cannot be dismissed merely because ordinary
Phosh does not exercise them.

## Concrete next suspect, not yet removed

0044 changes a 69.673 MHz entry in the **MDP_PIXEL** frequency table. The live
MDP_PIXEL source is 27 MHz; the active panel uses the separate **DSI_PIXEL**
source. Thus 0044 is not selecting the active video pixel rate now.

However the MMCC footswitch initialization still enables MDP pixel clock
branches, and a cold/re-entry/rate-selection path could select that table entry.
Removal requires an isolated boot/rate-path regression with reproducible live
baseline provenance. Current steady-state non-use is insufficient proof.
This patch remains explicitly `NEEDS_PHYSICAL_OMISSION_TEST`.

## Device check

On the unchanged running SYSTEM, the actual S1c×24 → S1×32 standalone test
completed with **56 NEAR, 0 SEVERE**. Phosh remains on GLES2. Runtime and ordered
GPU results are saved in `research/device/current/source-audit-20261004/`.
This is a working-device control, not a physical A/B of a semantic removal.

The larger A220 KGSL-derived block remains protected. Its individual waits,
shadow banks, MMU ordering and rearm operations require a controlled omission
bracket to establish necessity. Prior negative isolated tests do not justify
removing them from a proven working combined lifecycle implementation.

## Further consolidation and physical clock API test

0023/0026/0027 now form one final boot-state quiesce patch (0027b).
The abandoned suspend-time quiesce implementation is absent from the replay.
0054/0055/0056 now form one final command-DMA patch (0056b), retaining
software-trigger semantics, memory barriers and the idle/error-free guard.
All six original exports retain their metadata in the research archive.
This removes four additional intermediate patch entries, without removing
final hardware functionality. Active mail patches: **61**, plus four strict
transforms. Compared with the original 69 mail entries, the net reduction is
**8**; this is not eight proven unnecessary hardware features.

A read-only module was compiled against the exact currently running kernel
(config, release and ELF notes matched) and loaded/unloaded successfully.
It called the real exported `qcom_find_freq` with the current and original
MDP_PIXEL tables. For request 69673000, current selects 69673000 whereas the
original selects 76800000. Thus 0044 has a demonstrated functional effect;
necessity for this panel remains unproven. No clock rate or enable state was
written. Phosh remained active, and the module was removed afterwards.
Source and log: `research/device/current/source-audit-20261004/`.

The 61-patch series was independently materialized again. The complete
prepared source tree hash is still
`647d27c053892b371aed58fd1c6e2f94866e031c` (exact match).
All materializer source gates and six repository unit tests passed.
No replacement kernel was needed or deployed for this identical-code change.


## Complete individual review and safe execution checks

Every current entry now has an individual semantic review, execution gate,
final source location/hash and limitation in the TSV: **60 mail patches + 4
strict transforms = 64 entries**. Coverage is checked mechanically, including
unique IDs and an anchor in the fully prepared source. No generic subsystem
label substitutes for explaining the actual change.

The [review inputs](../research/patches/pre-subsystem-series-20261005/functional-expectations-20261004.json)
are maintained separately from observed evidence. Reproduce the inventory:

```sh
scripts/audit-hikari-functional-paths.py /path/to/prepared-kernel \
  --evidence research/device/current/source-audit-20261004 \
  --output /tmp/functional-audit.tsv
```

All **26 archived exports** are also classified in
[retired-audit-20261004.tsv](../kernel/patches/retired-audit-20261004.tsv), with
replacement, retirement reason and original SHA. Previously retired IOMMU and
DSI regressions stay inactive. Superseded integration retains all subsystem
functionality and authorship.

Additional concrete cleanup: 0029 contains only an informational revision-read
message, despite its power-domain title. The final clock/error handling is now
0031b without this message; canonical DTS still supplies MDP power domains.
The prepared source hash is
`e3d73fd2f7bffefd6e42b0ec789d4e0af81fde45`. Compared with the previous prepared
tree `647d27c053892b371aed58fd1c6e2f94866e031c`, it differs **only by deletion
of that two-line informational log**. The updated MDP object compiled in a
fresh output directory. Mail-entry reduction: **69 → 60, net 9**. This counts
consolidated/duplicate stages, not nine deleted hardware features.

### Verification level for each kind of patch

| Evidence | What it establishes | What remains unproven |
|---|---|---|
| Source review, final anchor and SHA | Exact operation retained in final source; gate identified | Hardware necessity |
| All 33 changed mail-patch C units + 2 sensor units compiled | Target compiler accepts active driver code | Execution and correctness |
| Live entry probes | Function actually executed in this running image | Every hunk/branch inside it or isolated necessity |
| Selector module (0044) | Real exported selector changes returned rate | Need for this particular panel |
| ABI/schema-only changes | Used by build/DT contracts | No independent runtime call is expected |
| CPU SAW/DVFS | Enabled and compiled in latest target source | Older running image has no live policy; physical acceptance pending |
| Suspend/error/OTG/cradle/HDMI/wake paths | Conditional code and consumer traced | Requires appropriate stimulus or recovery-safe omission test |

Physical entry counting used isolated kprobe tracing instances, no register
writes or kernel replacement. Standalone S1c×24 → S1×32 exited 0 with
**56 NEAR / 0 SEVERE**. A two-second glmark2 build scene on Wayland reported
FD220 and exited 0. Examples of actual GUI-run counts:

- GPU submit 230; GPU map 28/unmap 23.
- Framebuffer prepare/cleanup and physical scanout pin/unpin: 98 each.
- MDP enable/disable: 99 each; commit IRQ: 98.
- MMCC/SCM read/write: 509/84.
- Charger get-property 67, sync 3, status work 1; gauge properties 28.
- Temperature reads 14; MMC PIO IRQ 832; backlight updates 3.

Brightness was restored to 7. All temporary probes, tracing instances and
selector modules were removed. ALS/proximity/magnetometer raw reads succeeded;
controlled lux/distance/orientation and actual touch gestures were not tested.
Touch/contact functions had zero hits, which does not make them dispensable.
The correct NoC callback is `msm8660_icc_set`; the generic `qcom_icc_set` probe
is not evidence of executing that callback. Its execution remains unmeasured.

### Findings and exact final state

Scoped DT schema validation **reported errors** (exit 0 is not a pass): TLMM
`input-enable` is forbidden by the common binding and GCC lacks the TSENS
`thermal-sensor` child declaration. The TLMM driver still implements the legacy
input-enable operation by clearing output-enable; these are not evidence that
the pin configuration is unused. The errors are retained in the evidence log,
not hidden or reported as passed. Board/config static gates and six repository
unit tests passed.

The unchanged running SYSTEM remains
`7.3.0-rc1-hikari-system-ga701a6f7854a-dirty`, Phosh active on GLES2. BOOT,
production bundle and working GPU lifecycle are untouched. During evidence
collection Wi-Fi failed with `brcmf_sdio_dpc: failed backplane access over SDIO,
halting operation`. USB SSH remains available. A software module reload did
not restore wlan0; no destructive SDIO/rootfs reset or reboot was attempted.
This network fault is explicitly separate from the clean GPU tests.

**Individual source review is complete; isolated physical necessity testing is
not complete.** Deleting more code based only on unexercised functions would
be unjustified. Safe omission tests of cold-start, suspend, CPU DVFS, error
rollback and individual GPU lifecycle blocks require a recovery-safe boot
bracket; none is claimed to have occurred in this session.
