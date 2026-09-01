# Phase D plan: non-destructive bootloader and recovery characterization

This plan began as a non-destructive characterization proposal. D1 fastboot
and the first owner-approved recovery observation are now complete; they remain
strictly read-only/no-write results. Unlock, flashing, building a kernel, and
any write to the phone remain excluded. The C2 private backup must remain
verified and available before any later owner-approved experiment.

## Completed D1 evidence

- Sony S1Boot fastboot: `0fce:0dde`, protocol `0.5`,
  `CRH1099189_R10C008`, `secure: no`.
- Fastboot reached Android again through ordinary `fastboot reboot`.
- Current recovery was directly identified as TWRP 2.6.3.0. Its read-only
  characterization completed. `adb reboot` did not complete the transition and
  no safe recovery CLI reboot command was identified; the owner then selected
  the ordinary `Reboot System` UI action. Android returned to the same observed
  LT26w/fuji ScrubbModRom legacy baseline.
- Current p3 was inspected offline only and is a three-segment Sony ELF.

The unresolved gate is recovery-path independence from p3 and the exact
semantics/support of a non-persistent `fastboot boot` command.

## Questions to resolve

1. Establish the actual Sony bootloader lock state and the device's advertised
   unlock capability without treating `ro.bootloader=unknown` as evidence.
2. Determine whether fastboot is available and, if it is, whether this exact
   bootloader supports a non-persistent temporary boot command.  Do not infer
   support from another Xperia.
3. Establish the recovery architecture: separate recovery partition,
   FOTAKernel-style path, another Sony-specific route, or recovery code in a
   boot path.  Determine whether there is any evidence of a custom recovery or
   TWRP; absence at Android filesystem paths is not conclusive.
4. Recover the exact Hikari Sony ELF container/load/payload expectations,
   including kernel, ramdisk, RPM-related payload if present, and cmdline
   treatment, from a permitted source artifact or authoritative source code.
5. Select a persistent-log route that can retrieve evidence after a failed
   experimental boot, and document the safest independent rollback route.

## Ordered, owner-gated procedure

1. Review the verified private backup, offline partition-table evidence, known
   p3 legacy boot role, and the current no-write boundary.  Confirm that no
   action in the next step implicitly changes the device.
2. Gather only normal-mode, read-only Android properties/configuration and
   source-artifact evidence that can refine bootloader and recovery hypotheses.
   Record confidence separately from proof.
3. If normal mode cannot answer the lock/fastboot questions, prepare a narrow
   owner-approved physical-mode observation plan.  It must say exactly how the
   handset enters and leaves the mode, what host commands are read-only, what
   success/failure evidence will be collected, and why no flash or unlock
   command can be issued accidentally.
4. Only after the owner separately approves that plan, observe fastboot or
   recovery availability and collect version/help/capability information.  Do
   not use a `boot`, `flash`, `erase`, `oem unlock`, Sony unlock, or equivalent
   state-changing command.
5. Correlate the results with authoritative Sony/source archaeology and
   permitted offline inspection of ordinary boot/recovery artifacts.  Do not
   inspect TA, radio/NV, calibration, or unknown-partition payloads.
6. Choose and document the smallest later experimental-boot proposal: one
   artifact hash, one explicit target or a proven temporary path, a log route,
   a rollback decision point, and an owner-approved abort procedure.

## Required exit criteria before any experimental boot proposal

- Evidence-backed lock state and unlock capability, or an explicit blocker.
- Fastboot availability and temporary-boot capability established or UNKNOWN,
  without inference from related hardware.
- Recovery/FOTAKernel/custom-recovery status classified with evidence.
- Exact or explicitly UNKNOWN Sony ELF load/payload requirements.
- A tested-or-explicitly-limited persistent diagnostic retrieval route.
- A rollback path independent of the target being changed.
- Fresh owner approval for the specific boot experiment.
