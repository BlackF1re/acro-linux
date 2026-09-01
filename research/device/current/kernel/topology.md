# Kernel and topology

- Running legacy baseline kernel: `3.4.0-Elite-1.5+`, ARMv7, SMP, PREEMPT;
  build timestamp 2014-02-18. This is custom, not evidence of Sony stock
  configuration or target-Linux status.
- `/proc/cpuinfo`: ARMv7 processor, Qualcomm implementer `0x51`, part `0x02d`,
  revision 4; hardware string `fuji`; processors 0 and 1 are enumerated.
- `/sys/devices/system/cpu/{present,possible}`: `0-1`; `online` was `0` at the
  sampling instant. CPU1 is nevertheless enumerated and had received IPI work.
- Memory reported by `/proc/meminfo`: 635876 KiB total; zram0 is 128 MiB.
  The detailed legacy carveout evidence is in
  [memory-map-raw.md](../memory/memory-map-raw.md).
- No `/sys/firmware/devicetree` and no `/proc/config.gz` were exposed. This
  legacy boot uses Android/board-file-era interfaces; the safe public portion
  of `/proc/cmdline` reports `androidboot.hardware=semc` and
  `androidboot.baseband=msm`.
- Important reserved/probed ranges in `/proc/iomem`: KGSL 2D/3D, VIDC, VFE,
  Gemini, MIPI DSI, HDMI, MDP, SEMC VPE, SDCC, OTG, RPM, QDSP6 and modem PIL.

Evidence: `VERIFIED_DEVICE` for exposed running-kernel metadata. It does not
establish that any individual peripheral works or that target Linux has booted.
