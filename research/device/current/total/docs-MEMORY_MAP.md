# Legacy memory map

This is an evidence record of the running Android-derived 3.4 BSP. It must
not be copied mechanically into Device Tree or a mainline kernel.

## What the legacy kernel reports

The early kernel reports Memory: 44MB 614MB = 658MB total and
631168k/631168k available; /proc/meminfo later reports 635876 KiB. The gap
from nominal 1 GiB is not one reservation and is **not byte-completely
accounted for** by the available legacy interfaces. The custom 3.4 kernel
reports 330368 KiB reserved early, and has multiple fixed multimedia,
firmware, and persistent allocations, but it does not expose a complete
memblock/secure-world ledger.

The approximately 636 MiB figure is memory available to this legacy Linux
configuration. It neither changes the nominal physical-RAM inventory nor
defines a mainline layout.

| Category | Observed ranges / fact | Confidence | Interpretation |
| --- | --- | --- | --- |
| System RAM as named by `/proc/iomem` | 0x40200000–0x42dfffff; 0x48000000–0x6e5fffff | VERIFIED_DEVICE | Legacy kernel's RAM resource view, not a full physical-RAM census. |
| Legacy kernel accounting | 658 MiB total, 631168 KiB available, 330368 KiB reserved | VERIFIED_DEVICE | Direct dmesg counters; their relationship to every physical address is not exposed. |
| Fixed allocations below/above named System RAM | ION, framebuffer, pmem_tzcom, remote-storage RAMFS, persistent log areas below | VERIFIED_DEVICE | Explicit records only; they explain portions, not the full nominal-RAM difference. |
| Secure/firmware/reserved holes not named individually | present as an accounting gap | UNKNOWN | Likely classes of reservation, but no byte-level attribution is asserted. |
| MMIO | KGSL, VIDC, VFE, DSI, HDMI, MDP, SDCC, USB, RPM, QDSP6, PIL resources | VERIFIED_DEVICE | Device address-space resources, explicitly **not** RAM carveouts. |

## Explicit legacy allocations

| Region / purpose | Start | Size | Source / confidence |
| --- | ---: | ---: | --- |
| framebuffer allocation | 0x48000000 | 15,482,880 bytes | early dmesg; VERIFIED_DEVICE |
| ION mm_fw | 0x38000000 | 0x00200000 | dmesg; VERIFIED_DEVICE |
| ION mm | 0x38200000 | 0x03e00000 | dmesg; VERIFIED_DEVICE |
| ION mfc | 0x3c000000 | 0x00002000 | dmesg; VERIFIED_DEVICE |
| ION sf | 0x6e600000 | 0x09000000 | dmesg; VERIFIED_DEVICE |
| ION camera_preview | 0x77600000 | 0x07000000 | dmesg; VERIFIED_DEVICE |
| ION wb | 0x7e600000 | 0x00c00000 | dmesg; VERIFIED_DEVICE |
| ION audio | 0x7f200000 | 0x004cf000 | dmesg; VERIFIED_DEVICE |
| pmem_tzcom | 0x7f6cf000 | 0x00400000 | dmesg; VERIFIED_DEVICE |
| ramdumpinfo | 0x7ff00000 | 0x00001000 | /proc/iomem; VERIFIED_DEVICE |
| amsslog | 0x7ff01000 | 0x00004000 | /proc/iomem; VERIFIED_DEVICE |
| ram_console | 0x7ffe0000 | 0x00020000 | /proc/iomem; VERIFIED_DEVICE |
| remote-storage RAMFS | 0x46100000 | 0x00300000 | dmesg after modem bring-up; VERIFIED_DEVICE |
| remote-storage RAMFS | 0x42e00000 | 0x00002000 | dmesg after modem bring-up; VERIFIED_DEVICE |

GPU, VIDC, VFE, Gemini, DSI, HDMI, MDP/VPE, SDCC, USB, QDSP6 and modem PIL
This is a legacy-BSP record only. The modern kernel must derive its own valid
memory/reservation model from upstream bindings and new evidence; it must not
copy this map mechanically. Full sanitized evidence:
[memory-map-raw.md](../research/device/current/memory/memory-map-raw.md).
