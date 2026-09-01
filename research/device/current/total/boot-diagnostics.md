# Read-only boot-diagnostic discovery

Legacy dmesg declares persistent memory 0x7ffe0000-0x7fffffff and registers
platform devices ram_console and ramdumplog. /proc/iomem names this region
ram_console, with nearby ramdumpinfo and amsslog ranges.

Checked paths absent at collection time:

- /proc/last_kmsg
- /proc/ram_console
- /proc/apanic_console and /proc/apanic_threads
- /sys/fs/pstore
- /sys/kernel/debug/ram_console

No stored crash log was read. The reserved region is evidence of a legacy
persistent-log design, but no accessible reader was demonstrated.
