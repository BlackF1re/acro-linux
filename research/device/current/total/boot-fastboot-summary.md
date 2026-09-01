# Physical fastboot characterization

Date: 2026-09-01. Sanitized record of a read-only physical fastboot session.
No image was downloaded and no `boot`, `flash`, `erase`, `format`, `update`,
OEM, unlock, or other state-changing fastboot command was issued.

| Item | Result | Evidence state |
| --- | --- | --- |
| USB enumeration | `0fce:0dde`, Sony Ericsson Mobile Communications AB, `S1Boot Fastboot` | `VERIFIED_DEVICE` |
| Fastboot transport | Enumerated in WSL and answered standard `getvar` requests | `VERIFIED_DEVICE` |
| Protocol version | `0.5` | `VERIFIED_DEVICE` |
| Bootloader version | `Sony Ericsson S1Boot Fastboot emulation CRH1099189_R10C008` | `VERIFIED_DEVICE` |
| `secure` | `no` | `VERIFIED_DEVICE` |
| `product` | `Unknown: May 28 2013/15:08:31` | Sony-specific legacy response, not a normal product ID |
| `unlocked` | empty response | absence is not `false` |
| `max-download-size` | empty response | no size limit inferred |
| `partition-type:boot` | empty response | no partition type inferred |
| `partition-size:boot` | empty response | no partition size inferred |

The unique fastboot serial was intentionally omitted. `secure: no` proves only
that this S1Boot reported that value. Owner-provided history of a prior unlock,
custom ROM and current root is consistent evidence, not a bootloader
attestation. `fastboot boot` was not invoked; support remains `UNKNOWN`.
