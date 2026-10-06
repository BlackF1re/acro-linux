# Functional patch review

Each maintained kernel patch has an owning subsystem and a source anchor in
[`../kernel/patches/`](../kernel/patches/). Component expectations and current
coverage are tracked in `kernel/patches/functional-expectations.json` and
`kernel/patches/functional-audit.tsv`.

The review distinguished temporary experiment stages from the final hardware
implementation. Superseded clock/display intermediate changes and duplicate
board-DTS copies were consolidated. The final clock selection, DSI timing,
charging safety, and A220 command/MMU lifecycle remain because they affect the
current port. No active subsystem was removed solely because a path is not
exercised by an ordinary Phosh session.

## Physical evidence

- A220 varying transition: `S1c×24 → S1×32` completed with 56 NEAR and no
  SEVERE frames in the accepted device check. The combined KGSL-derived
  lifecycle stays intact; one-variable removals need a fresh physical bracket.
- Display: native MDP4/DSI scanout and touch-driven Phosh work. Resume and some
  handoff paths remain separate acceptance items.
- Power: CPU DVFS source is present, but the audited running kernel exposed no
  cpufreq policy. Suspend/resume is not reliable and must not be enabled
  automatically.
- Other capability status is maintained per device in
  [`HARDWARE.md`](HARDWARE.md) and [`../status/hardware.yaml`](../status/hardware.yaml).

These results replace the chronological test logs. They do not imply that
every code path has passed physical testing.
