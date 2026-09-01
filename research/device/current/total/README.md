# Current-device read-only inventory

Collected from the connected Sony Xperia acro S LT26w through ADB during two
read-only reconnaissance passes (2026-09-01). The phone was neither rebooted
nor flashed; no settings or filesystem state was changed.  A later
owner-authorized backup streamed the complete eMMC user area to private
recovery media outside the repository.  Sensitive partition bytes are present
only in that private raw stream and were not separately inspected, parsed,
interpreted, exposed, or committed.
No raw block-device contents are stored in this inventory.

The files contain non-secret metadata only. ADB and hardware serials, Android
ID, IMEI/IMSI/ICCID, MAC addresses, credentials, TA/radio/NV/calibration data,
and boot-command-line values that identify this particular handset are omitted.
User/private data and TA, radio/NV, calibration, and other protected-partition
contents were not separately inspected outside that owner-authorized raw
backup stream. Some non-secret system configuration, module, and generic
firmware files were read only to record narrow metadata, names, hashes or
provenance; no proprietary blob was copied. Presence of an interface or bound
legacy driver is not an acceptance test. This is evidence of a modified Android
legacy baseline, not progress of the target native-Linux port.

This `total` directory is intentionally a flat, unstructured copy set for
transport/review.  It preserves report text but not directory topology, so
relative Markdown links should be followed in the canonical `docs/` or
structured `research/device/current/` locations instead.
