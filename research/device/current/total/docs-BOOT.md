# Boot observations and diagnostics

The handset was already booted into the custom Android legacy baseline when
collection began. No reboot, recovery, fastboot, flashing, mount change, or
block-device read/write was performed.

The legacy kernel is board-file based: it exposes neither
/sys/firmware/devicetree nor /proc/config.gz. That is evidence about this
baseline only, not a requirement for target native-Linux boot.

## Persistent diagnostics

Dmesg reserves 0x7ffe0000-0x7fffffff (128 KiB) as ram_console, and
/proc/iomem also lists ramdumpinfo at 0x7ff00000-0x7ff00fff and amsslog at
0x7ff01000-0x7ff04fff. The registered platform devices are ram_console and
ramdumplog.

At sampling time /proc/last_kmsg, /proc/ram_console, /proc/apanic_console,
/proc/apanic_threads, /sys/fs/pstore, and the checked debugfs ram_console path
were absent. The confirmed mechanism is therefore a reserved legacy
ram-console region with no exposed readout endpoint in the running ROM, not a
tested recovery mechanism.

For the first experimental native-kernel boot, reserve a documented ramoops
region and expose it through pstore; retain serial/USB logging separately.
That is a design recommendation, not a change made in this pass.
