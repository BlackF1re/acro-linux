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
6. As soon as TWRP ADB is ready, run the capture helper.  Its first operation
   after `adb wait-for-device` is to save a valid old log, before it requests
   recovery `dmesg`, `/proc/iomem`, or `/dev/mem`:

   ```sh
   scripts/capture-hikari-ramconsole.sh
   ```

   `/proc/last_kmsg` is the primary prior-mainline source; `/dev/last_kmsg`
   is a secondary probe. The helper only later saves TWRP `dmesg`, including
   the `found existing buffer` / `persistent_ram` / `ram_console` status, and
   captures the physical range as `CURRENT_RECOVERY_PERSISTENT_BUFFER`.
   If neither endpoint exists, record that fact rather than substituting
   TWRP's live `dmesg`.
7. Only after all capture attempts can recovery leave for Android.

Abort before flashing if USB identity is unexpected, a hash/gate fails, the
artifact exceeds p3, the original restore artifact cannot be verified, or
S1Boot reports an unexpected response.
