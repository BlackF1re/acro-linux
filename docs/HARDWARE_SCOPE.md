# Hardware scope

Nothing populated on the Hikari board is excluded by default. The acceptance
state for each item belongs in [status/hardware.yaml](../status/hardware.yaml).

| Domain | Required end state |
| --- | --- |
| Core | SMP, clocks, regulators, interconnect, thermal, cpufreq/cpuidle |
| Storage/boot | eMMC, microSD, safe BOOT/update/recovery |
| User interface | display, backlight, touch, buttons, LEDs, haptics |
| Graphics/video | Adreno acceleration, display composition, video codecs |
| Connectivity | USB device/OTG/charging, Wi-Fi, Bluetooth, NFC, FM, HDMI |
| Phone | modem, data, SMS, calls, GNSS, audio routing |
| Media/audio | speakers, microphones, headset, cameras, AF, flash |
| Sensors/power | all IIO/input sensors, battery, charging, RTC, watchdog, dock |
| System | suspend/resume and every valid wake source |

`VERIFIED` requires the corresponding physical function—traffic, input,
capture, playback, fix, charging behavior or repeated power transition—not
merely a successful probe.
