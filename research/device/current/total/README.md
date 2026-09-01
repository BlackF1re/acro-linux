# Current-device read-only inventory

Collected from the connected Sony Xperia acro S LT26w through ADB during two
read-only reconnaissance passes (2026-09-01). The phone was neither rebooted
nor flashed; no settings or filesystem state was changed. Raw block-device
contents were not read.

The files contain non-secret metadata only. ADB and hardware serials, Android
ID, IMEI/IMSI/ICCID, MAC addresses, credentials, TA/radio/NV/calibration data,
and boot-command-line values that identify this particular handset are omitted.
User/private data and TA, radio/NV, calibration, and other protected-partition
contents were not read. Some non-secret system configuration, module, and
generic firmware files were read only to record narrow metadata, names, hashes
or provenance; no proprietary blob was copied. Presence of an interface or
bound legacy driver is not an acceptance test. This is evidence of a modified
Android legacy baseline, not progress of the target native-Linux port.
