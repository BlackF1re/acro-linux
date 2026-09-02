# Hikari boot #4 post-mortem procedure

This is an owner-gated physical procedure.  It is not authorization to flash
or reboot by itself.

1. Check the validated boot #4 ELF hash, size, Sony-ELF validation, DTB gate,
   memory gate, persistent-RAM gate and the original p3 restore hash.
2. Enter S1Boot using phone-off **Volume Up + USB**, verify `0fce:0dde` and
   `fastboot devices`, then flash only logical `boot` with the approved boot
   #4 ELF and issue `fastboot reboot`.
3. If no observable target proof appears, force reset with **Power + Volume
   Up**.  At the first vibration release Power first; retain Volume Up for
   S1Boot entry.
4. In S1Boot restore only the verified original p3 ELF through logical `boot`.
   Do not erase or touch another partition.  Then use `fastboot reboot`.
5. Enter the verified TWRP branch using the separately documented original-p3
   bootrec key sequence.  Do **not** let Android userspace boot.
6. As soon as TWRP ADB is ready, save a valid old log in this order:

   ```sh
   adb exec-out cat /proc/last_kmsg > PRIVATE/proc-last_kmsg.raw
   # Also probe /dev/last_kmsg, /proc/ram_console and /sys/fs/pstore.
   ```

   The raw outputs remain private.  If `/proc/last_kmsg` is absent, record
   that fact rather than substituting TWRP's live `dmesg`.
7. Also run the read-only host helper:

   ```sh
   scripts/capture-hikari-ramconsole.sh
   ```

   It records the exact physical `0x7ffe0000+0x20000` range and uses the host
   parser.  It validates the surviving buffer/header but may already see a
   new TWRP console, which is why step 6 precedes it.
8. Only after all capture attempts can recovery leave for Android.

Abort before flashing if USB identity is unexpected, a hash/gate fails, the
artifact exceeds p3, the original restore artifact cannot be verified, or
S1Boot reports an unexpected response.
