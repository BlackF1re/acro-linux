# First native-Linux boot: proposal gate, not execution authorization

No kernel, DTS, image, `fastboot boot`, or flash operation has occurred.

| Candidate | Status | Reason |
| --- | --- | --- |
| Temporary `fastboot boot` Sony ELF | Not selected: `UNKNOWN` | Exact S1Boot support/non-persistent semantics are unproven. |
| Independent recovery/FOTA route | Not selected: `UNKNOWN` | TWRP exists but its p3 independence is unproven. |
| Temporary chainload | Not selected: `UNKNOWN` | No evidence-backed mechanism. |
| Controlled p3 replacement | Conditional future candidate | Needs independent rollback and explicit owner approval. |

The safest present action is further offline recovery-path research. Any future
artifact must use a validated Sony ELF32 ARM contract, establish firmware
provenance, include early console and planned ramoops/pstore, and be recorded
with exact SHA-256/size/program headers. The private p3 reference is
`c59be74873aa32a8422adf9b5402254b2acae619f7dc97bd50fc0e120984d0c1`, offset
4,194,304 bytes, size 20,971,520 bytes. A separate approval must identify the
artifact, target, rollback method, and abort conditions.
