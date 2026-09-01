# Current-device read-only inventory

Collected from the connected Sony Xperia acro S LT26w through read-only ADB,
fastboot and offline evidence work (2026-09-01). No flash, unlock, image
download, partition write, settings change, or filesystem modification was
performed by the project. Owner-approved C2 work sequentially read the
accessible eMMC user area into private backup media; later offline analysis was
limited to confirmed p3 (`/boot`).

The files contain non-secret metadata only. ADB and hardware serials, Android
ID, IMEI/IMSI/ICCID, MAC addresses, credentials, TA/radio/NV/calibration data,
and boot-command-line values that identify this particular handset are omitted.
Sensitive partition bytes are physically present only in the private backup;
they were not separately inspected, parsed, interpreted, extracted, exposed,
or committed. Some non-secret system configuration, module, and generic
firmware files were read only to record narrow metadata, names, hashes or
provenance; no proprietary blob was copied. Presence of an interface or bound
legacy driver is not an acceptance test. This is evidence of a modified Android
legacy baseline, not progress of the target native-Linux port.

This `total` directory is intentionally a flat, unstructured copy set for
transport/review.  It preserves report text but not directory topology, so
relative Markdown links should be followed in the canonical `docs/` or
structured `research/device/current/` locations instead.
