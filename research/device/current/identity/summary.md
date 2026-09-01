# Identity

- USB enumeration: Sony Ericsson Mobile Communications AB, product `LT26W`
  (USB ID `0fce:5176`).
- ADB product/model: `LT26w_1266-2038` / `LT26W`.
- Android properties: brand `SEMC`; manufacturer `Sony`; device `LT26w`;
  product board `fuji`; legacy BSP platform string `msm8660`; hardware
  `semc`. The platform string alone is not silicon identification.
- Root-readable socinfo reports normalized ID 70, version 2.1, raw ID 1057 and
  raw version 2. The current upstream Qualcomm ID table maps 70 to **MSM8260**.
  The Qualcomm build metadata is `M8660A-AABQNLYM-3.1.4003T`; its `M8660A`
  prefix is not a silicon-SKU field. See
  [socinfo.txt](../kernel/socinfo.txt).
- Installed baseline: ScrubbModRom KK4.4.2 v1.4.1, Android 4.4.2 (API 19),
  build ID `KOT49H`, userdebug/test-keys, custom kernel 3.4.0-Elite-1.5+.
- Build fingerprint: `SEMC/LT26w_1266-2038/LT26w:4.4.2/6.4.B.1.00/n7v_zg:user/release-keys`.
- Existing `su -c id` returned root. No privilege escalation was attempted.

Evidence: `VERIFIED_DEVICE` for the identity and exposed physical soc0
metadata. The booted image is a legacy baseline, not target Linux.
