# Current status

Implementation state is tracked in [status/hardware.yaml](../status/hardware.yaml);
this page is only the operator summary.

## Verified on the physical Hikari

- p3 Sony ELF boot and original-image recovery through fastboot;
- native display, backlight and framebuffer console;
- local framebuffer terminal and USB ACM terminal;
- USB device→host→device role cycling; powered OTG keyboard and Wi-Fi adapter;
- microSD Debian root and manual UP BOOT→SMP SYSTEM kexec;
- both CPUs online in SYSTEM;
- Sony's full 939 MiB Linux RAM map, yielding 928996 kB `MemTotal`, including
  a two-pattern 640 MiB physical stress test followed by clean FD220 scanout;
- Adreno 220 hardware GLES2 through DRM/MSM and Mesa Freedreno, including
  shader compilation, drawing and pixel readback;
- Synaptics TM1964-001 touch input, including multitouch tracking and clean
  event delivery;
- BCM4330 station association and real network traffic, including about
  355 MiB of sustained RX, ten pre-stress and three post-stress reconnects
  after matching Qualcomm's cyclic MMCI PIO FIFO-window reads;
- BCM4330B1 Bluetooth discovery through BlueZ with the board firmware patch
  and per-device address (pairing and data-link acceptance remain open);
- writable PM8058 RTC plus native systemd-timesyncd network synchronization
  (powered-off retention still needs testing);
- USB sink charging with stable current;
- MSM8660 on-die TSENS through thermal/hwmon, with stable 42--43 C physical
  readings (protective trips and throttling remain open);
- PM8058 XOADC board inputs and the MSM board NTC through a standard thermal
  zone; the NTC physically tracked CPU heating in the expected direction;
- AS3676 red, green and blue notification LEDs plus button backlight, with
  the complete ordered brightness test confirmed visually by the owner;
- BMA250 accelerometer, MPU3050 gyroscope, AKM8972 magnetometer and APDS9702
  proximity sensor with physical axis/state changes; AS3676 ambient light is
  readable on demand (continuous-mode stability remains open);
- headset insertion/removal as a standard wake-capable
  `SW_HEADPHONE_INSERT` input switch, verified through repeated physical
  cycles (audio routing, mic-bias classification and remote buttons remain
  part of the deferred audio work).

## Implementing in this change

- BOOT stops permanently until `hikari-system` is entered;
- distinct BOOT/SYSTEM banners and prompts;
- SYSTEM→BOOT through a normal reboot;
- composite ACM+NCM USB with verified archives for kernel/modules and rootfs;
- persistent Wi-Fi autoconnect configured on-device;
- bring-up SSH over USB/Wi-Fi, including deliberate empty-password root login;
- compact bring-up toolset;
- removal of obsolete first-boot diagnostics, the polling USB watcher, the
  custom Wi-Fi helper and redundant charger patches;
- standard BNEP, RFCOMM and HIDP Bluetooth kernel profiles in the single
  SYSTEM configuration.

These remain `IMPLEMENTING`, not `VERIFIED`, until the rebuilt images pass
the physical sequence in [TESTING.md](TESTING.md).

## Major remaining work

Graphical compositor integration, audio, Bluetooth data links, modem/telephony/GNSS,
NFC/FM, cameras, HDMI, full sensor acceptance, thermal/cpufreq/cpuidle,
suspend/resume and cradle charging are not complete. See
[HARDWARE_SCOPE.md](HARDWARE_SCOPE.md); a probe alone is never success.
