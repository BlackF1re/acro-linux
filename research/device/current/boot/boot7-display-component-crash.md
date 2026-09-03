# Hikari BOOT #7 display component-graph failure

Status: `VERIFIED_DEVICE` diagnostic evidence; display remains `IMPLEMENTING`.

The BOOT #7 charging/display artifact reached native Linux, registered the
verified USB gadget, and started deferred probing.  The persistent console
captured by TWRP contains the following sanitized terminal failure:

```text
mdp4 5100000.display-controller: dummy supplies not allowed for exclusive requests (id=vdd)
Unable to handle kernel NULL pointer dereference at virtual address 00000004
PC is at component_master_add_with_match+0x10/0xf4
... component_master_add_with_match from msm_drv_probe
... deferred_probe_work_func
```

The MDP4 `vdd` message is non-fatal: current DRM/MSM treats an unavailable
exclusive `vdd` supply as optional for MDP4.  The fault is instead explained
by the DT component graph.  Current `add_mdp_components()` deliberately skips
MDP4 port 0 because it is the LCDC/LVDS output.  The original Hikari DTS wired
DSI to that port, so the component match stayed empty and `msm_drv_probe()`
called `component_master_add_with_match()` with a null match.

The correction wires Hikari DSI1 to MDP4 port 1, matching the current MSM DRM
component convention.  The static display gate now requires port 1 and fails
if an endpoint is present on port 0.  This is a narrowly scoped boot-blocker
fix; it does not claim electrical display acceptance and it does not alter the
verified USB, memory, RPM, ramoops, or Sony ELF hand-off.

Private raw evidence is retained outside Git at
`/home/paul/xperia/research/private/hikari-boot7-postmortem/`. The primary
capture is `last_kmsg-adb-shell.raw`, 54,587 bytes, SHA-256
`740c8f87da23ca023b04bd3e0ff2c92cea811e9299fbfe6831f5c78c5d6cc921`.
The committed excerpt above contains no device serial or other unique
identifier.
