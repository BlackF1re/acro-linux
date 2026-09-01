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

The currently installed recovery is `VERIFIED_DEVICE` as TWRP 2.6.3.0. Its
storage/boot-path relationship to p3, and hence its independence as a rollback
route, remain `UNKNOWN`. The current p3 legacy `/boot` artifact is a verified
Sony ELF layout documented in [BOOT_FORMAT.md](BOOT_FORMAT.md); target Linux
has not been built or booted.

## Status domains

status/hardware.yaml deliberately separates physical hardware evidence, the
legacy Android baseline, and native target-Linux progress for every subsystem.
The baseline is BOOTS; target Linux has lifecycle NOT_STARTED and every
target subsystem is UNKNOWN. Legacy runtime observations are retained in their
own field, but are neither target-Linux progress nor functional verification.

VERIFIED is reserved for a defined acceptance test on the physical Xperia.
This pass was topology collection only; it performed no functional acceptance
tests.
