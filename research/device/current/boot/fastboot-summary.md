# Physical fastboot characterization

Date: 2026-09-01. This is a sanitized record of a read-only physical fastboot session. No image was downloaded and no `boot`, `flash`, `erase`, `format`, `update`, OEM, unlock, or other state-changing fastboot command was issued.

## Direct device observations

| Item | Result | Evidence state |
| --- | --- | --- |
| USB enumeration | `0fce:0dde`, Sony Ericsson Mobile Communications AB, `S1Boot Fastboot` | `VERIFIED_DEVICE` |
| Fastboot transport | Enumerated in WSL and answered standard `getvar` requests | `VERIFIED_DEVICE` |
| Protocol version | `0.5` | `VERIFIED_DEVICE` |
| Bootloader version | `Sony Ericsson S1Boot Fastboot emulation CRH1099189_R10C008` | `VERIFIED_DEVICE` |
| `secure` | `no` | `VERIFIED_DEVICE` |
| `product` | `Unknown: May 28 2013/15:08:31` | `VERIFIED_DEVICE`; Sony-specific legacy response, not a normal product ID |
| `unlocked` | empty response | `VERIFIED_DEVICE`; absence is not `false` |
| `max-download-size` | empty response | `VERIFIED_DEVICE`; no size limit inferred |
| `partition-type:boot` | empty response | `VERIFIED_DEVICE`; no partition type inferred |
| `partition-size:boot` | empty response | `VERIFIED_DEVICE`; no partition size inferred |

The unique fastboot serial was observed only to establish transport presence; it is intentionally omitted.

## Interpretation boundary

`secure: no` proves that this S1Boot implementation reported that value. It does not by itself define the semantics of every Sony lock state. Owner history independently states that the owner previously unlocked the bootloader, installed a custom ROM, and has root on the current system. That history is not a bootloader attestation, but it is consistent with the direct fastboot observation and the custom running kernel.

`fastboot boot` was not invoked. Support for a non-persistent temporary boot on this exact S1Boot revision remains `UNKNOWN`.
