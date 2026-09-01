# Legacy memory-map raw evidence

Collected read-only from the running rooted legacy kernel on 2026-09-01.
No raw partition or protected-memory content was read.

## /proc/iomem RAM and persistent ranges

    40200000-42dfffff : System RAM
    48000000-6e5fffff : System RAM
    7ff00000-7ff00fff : ramdumpinfo
    7ff01000-7ff04fff : amsslog
    7ffe0000-7fffffff : ram_console

## Dmesg allocation records

    allocating 15482880 bytes at c7e00000 (48000000 physical) for fb
    Memory: 44MB 614MB = 658MB total
    Memory: 631168k/631168k available, 330368k reserved, 0K highmem
    ION heap mm created at 38200000 with size 3e00000
    ION heap mm_fw created at 38000000 with size 200000
    ION heap mfc created at 3c000000 with size 2000
    ION heap sf created at 6e600000 with size 9000000
    ION heap camera_preview created at 77600000 with size 7000000
    ION heap wb created at 7e600000 with size c00000
    ION heap audio created at 7f200000 with size 4cf000
    allocating 4194304 bytes at 7f6cf000 physical for pmem_tzcom
    rmt_storage_get_ramfs: RAMFS entry: addr = 0x46100000, size = 0x00300000
    rmt_storage_get_ramfs: RAMFS entry: addr = 0x42e00000, size = 0x00002000

The complete sanitized boot log is ../kernel/dmesg-sanitized.txt.
