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
`g_serial` enumerated as non-unique `0525:a4a7` at High Speed, and the host
created a CDC ACM node. This does **not** verify an interactive console. The
actual BOOT #5 CPIO lacked `/dev/console`, had an empty `/dev`, and installed
only the BusyBox `sh` link; PID 1's first `mount` never ran and no userspace
marker reached ramoops. BOOT #5.1 corrected that archive with required device
nodes, command links, late `ttyGS0` kernel console, and explicit raw-TX/shell
diagnostics. It was then physically accepted by S1Boot: the host reached a
BusyBox root prompt through CDC ACM, proving bidirectional interactive console
I/O. The minimal BusyBox image does not yet contain the `uname` applet; that is
not a transport failure. The L6 voltage warning was non-blocking for observed
enumeration and remains unresolved.

## Status domains

status/hardware.yaml deliberately separates physical hardware evidence, the
legacy Android baseline, and native target-Linux progress for every subsystem.
The legacy baseline and target Linux both have a `BOOTS` lifecycle: BOOT #4
physically reached native `/init`. BOOT #5 work is locally `IMPLEMENTING` for
a stable PID 1 and USB device-mode diagnostics. BOOT #5 physically verified
the target USB PHY/UDC/gadget enumeration, while the console and stable PID 1
remain unverified pending the corrected BOOT #5.1 artifact. Legacy runtime
observations are retained in their own field, but are neither target-Linux
progress nor functional verification.

VERIFIED is reserved for a defined acceptance test on the physical Xperia.
This pass was topology collection only; it performed no functional acceptance
tests.
