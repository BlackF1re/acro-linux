# One subsystem per patch — 2026-10-05

**17 active mail patches**, replacing 60 mail patches and four strict transforms.
One final patch per subsystem; no post-series application or active transforms.
Board DT is one separate subsystem patch. Original author trailers, messages,
exports and component reviews are preserved in the archive and mapping.

Two fresh materializations through the project script passed all source gates.
Complete source tree before and after:
`e3d73fd2f7bffefd6e42b0ec789d4e0af81fde45`.
All 87 changed source files are byte-identical. GPU hardware ordering, waits,
MMU state, CPU/charging safety and every other target-code byte are unchanged.
Six repository tests passed. Audit covers all 17 patches and retained component
anchors. Existing schema defects/physical verification limits are unchanged.

The materializer now rejects a different tree or dirty canonical preparation.
No rebuild/deployment/boot was needed to validate this packaging-only change.
Read-only phone check: same 7.3 SYSTEM, Phosh active, WLR_RENDERER=gles2.
BOOT, production kernel/bundle and runtime libraries were not modified.
No new physical acceptance is claimed. See verification.json and
kernel/patches/subsystems.json for provenance and integrity.
