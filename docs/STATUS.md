# Status

The physical reconnaissance baseline is ScrubbModRom KK4.4.2 v1.4.1, Android
4.4.2 userdebug/test-keys, with custom 3.4.0-Elite-1.5+. It is not a clean
Sony stock baseline. Its board files, driver registrations and logs are useful
evidence, but its policy and parameters are not factory facts.

In particular, a 1890 MHz CPU setting observed in this custom kernel is not a
Sony-approved OPP and must not be carried into a target kernel without
independent evidence and validation.

## Boot and recovery characterization

Physical fastboot is `VERIFIED_DEVICE`: Sony S1Boot Fastboot appears as
`0fce:0dde`, protocol `0.5`, version `CRH1099189_R10C008`, with `secure: no`.
The old S1Boot returns empty `unlocked` and boot-partition metadata variables;
this is unsupported/absent metadata, not evidence of a locked bootloader.
Owner history independently records an earlier unlock, custom ROM installation,
and root; it is retained as owner-provided history rather than an attestation.
Following the first failed native-Linux attempt, **Power + Volume Up** was
observed to force reset/shutdown; this is distinct from phone-off Volume-Up USB
entry to S1Boot.

The currently installed recovery is `VERIFIED_DEVICE` as a reachable TWRP
2.6.3.0 runtime: `adb reboot recovery` reached it and the owner returned to
Android normally. Offline p3 analysis shows that its bootrec controller refers
to p11 as an external FOTA/recovery payload, but p11 has not been read. Thus
its physical storage, relationship to p3, and independence as a rollback route
remain `UNKNOWN`. The current p3 legacy `/boot` artifact is a verified Sony ELF
layout documented in [BOOT_FORMAT.md](BOOT_FORMAT.md). The first local-only
upstream Hikari kernel/DTB/initramfs/ELF prototype was physically written once:
S1Boot accepted it, but no target-Linux proof of life appeared during the
120-second observation window. `FIRST_MAINLINE_BOOT` is therefore
`NOT_VERIFIED`, not a kernel-panic diagnosis.

The rollback model is now `VERIFIED_DEVICE`: after the failed attempt, hardware
S1Boot entry remained available; the exact original p3 ELF was flashed through
logical `boot`; and the ScrubbModRom baseline returned normally. This proves
the p3 rollback route for this device and artifact, without generalizing it to
other partitions. `fastboot boot` remains `UNKNOWN`. See [ROLLBACK.md](ROLLBACK.md).

The second candidate was physically written once and S1Boot accepted the
expected logical `boot`/p3 mapping. After reboot, the 120-second observation
had no target-Linux marker, ADB, fastboot, or new USB target; the owner
observed a black, unresponsive handset and used the verified **Power + Volume
Up** forced reset. The original p3 was restored and Android returned. Thus
`SECOND_MAINLINE_BOOT` is `NOT_VERIFIED` and `BOOT_PROOF` is `NOT_OBSERVED`.
The only captured TWRP previous-boot log belongs to a later legacy Android
reboot, so it does not locate the target failure stage; see
[secondboot post-mortem](../research/device/current/boot/secondboot-postmortem.md).

Post-attempt review identified a double application of the MSM8x60 SMEM offset
in the second DTS/layout model. TWRP's later read-only `/proc/iomem` capture
now physically confirms that Linux-visible low System RAM begins at
`0x40200000`, while its own code is at `0x40208000`; this supports the
corrected physical-base/SMEM model without making a target-boot claim. Boot #4
uses `0x40208000` again and reserves a distinct legacy-compatible persistent
console at `0x7ffe0000-0x7fffffff`. See
[FIRST_BOOT_MEMORY.md](FIRST_BOOT_MEMORY.md) and
[PERSISTENT_LOGGING.md](PERSISTENT_LOGGING.md).

Boot #4 then provided the first direct target-kernel execution evidence. Its
recovered `/proc/last_kmsg`, exported by TWRP from the compatible persistent
console before recovery reset the physical ring, identifies the Hikari FDT,
corrected RAM layout, two CPU bring-up, ramoops, RPM, initramfs unpacking, and
`Run /init as init process`. The diagnostic PID 1 then exited with status zero,
causing `Attempted to kill init`; this is a controlled initramfs-liveness bug,
not an early-kernel hang. Thus `FIRST_MAINLINE_EXECUTION=VERIFIED_DEVICE` and
target lifecycle is `BOOTS` at the native initramfs boundary. No peripheral
acceptance claim follows. See [boot #4 post-mortem](../research/device/current/boot/boot4-postmortem.md).

BOOT #5 then physically verified the target USB device-mode hardware path:
the Qualcomm HS PHY, vendor ULPI initialization, ChipIdea UDC, and built-in
`g_serial` enumerated as non-unique `0525:a4a7` at High Speed (480 Mbps), and
the host created `/dev/ttyACM0`. BOOT #5.1 corrected BOOT #5's missing device
nodes and BusyBox applet links, then physically exposed `/dev/ttyGS0` and an
interactive root shell. The first shell exited with status zero and the
independent supervisor spawned another one. `HIKARI ALIVE` markers from 2.18
through 1082.67 seconds prove a stable PID 1 and supervisor for at least
18 minutes. The initial `uname: not found` was caused by missing initramfs
symlinks, not a missing compiled BusyBox applet. The L6 voltage warning was
non-blocking for this acceptance test and remains a power-management blocker.

BOOT #6 is a **local-only**, untested display artifact.  It adds source-derived
MSM8x60 MMCC/GDSC/NoC infrastructure, MDP4, the DRM/MSM DSI v2 host, a fixed
rate 45 nm DSI PHY, the exact R63306/TMD MDV22 panel profile, AS3676
backlight, fbdev emulation and fbcon while preserving the verified USB and
ramoops paths.  These are implementation/static-validation states, not
display acceptance claims.  See [DISPLAY_BOOT6.md](DISPLAY_BOOT6.md).

BOOT #7 supplied the first display-path post-mortem: deferred DRM/MSM probing
faulted before `/init` because the Hikari DTS connected DSI to MDP4 port 0,
which current DRM/MSM deliberately excludes from component matching.  DSI1 is
MDP4 port 1.  The corrected DT graph is built into the canonical locally
validated artifact, and its static gate rejects the old port-0 topology. This
is a precise software boot-blocker diagnosis, not a target-Linux display
acceptance claim. See
[the sanitized BOOT #7 evidence](../research/device/current/boot/boot7-display-component-crash.md).

The next live run passed component matching and DSI variant selection, then
hard-stalled CPU0 before `/init` in DSI runtime suspend while waiting for an
incorrectly described MMSS clock branch. Exact MSM8x60 source assigns DSI
slave AHB halt bit 20, while the bootstrap MMCC driver used bit 21 and marked
the branch critical. The current local kernel corrects that ownership/bit and
also fixes truncated MDV22 command-table payloads. These corrections are built
and validated but not deployed; display/fbcon remain `NOT_VERIFIED`.

## Status domains

status/hardware.yaml deliberately separates physical hardware evidence, the
legacy Android baseline, and native target-Linux progress for every subsystem.
The legacy baseline and target Linux both have a `BOOTS` lifecycle. BOOT #5.1
physically verified native initramfs execution, stable PID 1, persistent
diagnostics, and the USB peripheral/root-console path. Legacy runtime
observations are retained in their own field, but are neither target-Linux
progress nor functional verification.

VERIFIED is reserved for a defined acceptance test on the physical Xperia.
This pass was topology collection only; it performed no functional acceptance
tests.
## Native charging (local implementation)

The first native BQ24160/BQ27520 charging stack is `IMPLEMENTING`. Both chips
physically probed and USB input was online, but the observed state was `Not
charging` with negative battery current. Raw status `0x27` identifies a
current USB-ready state plus a latched/read-to-clear fault-history value; the
driver previously misclassified that history as a current fatal fault. The
current local kernel fixes this without weakening the 500 mA cap,
temperature/voltage policy, read-only BQ27520 use, or NVM prohibition. Native
charging remains unverified pending positive-current/SOC testing. Raw
STAT/FAULT transition logging remains diagnostic; it does not force charging.
Cradle/IN and suspend charging remain blocked pending dedicated physical
evidence. See
[CHARGING.md](CHARGING.md).
