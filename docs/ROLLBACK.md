# Hikari rollback research

## What is established

- Physical S1Boot fastboot entry is `VERIFIED_DEVICE` and independent of the
  running Android userspace once the physical key path is used.
- The private backup contains an exact p3 copy, SHA-256
  `c59be74873aa32a8422adf9b5402254b2acae619f7dc97bd50fc0e120984d0c1`.
- p3 is a legacy `/boot` role and contains the verified Sony ELF layout.

## What is not yet proven

No authoritative LT26w/S1Boot `CRH1099189_R10C008` source found in this pass
proves that `fastboot flash boot <Sony ELF>` maps precisely to p3, accepts this
format and size, and can restore it. Generic Android fastboot documentation is
not sufficient for this Sony generation.

`FASTBOOT_P3_RESTORE` is therefore **UNKNOWN**. `fastboot boot` is also
**UNKNOWN** and has not been tested. The present backup is recovery material,
not a demonstrated restore procedure.

## Gate

Until an exact authoritative source or a separately approved controlled test
proves the mapping, no p3 deployment route is selected. TWRP reachability does
not fill this gap because its storage and independence from p3 are unresolved.
