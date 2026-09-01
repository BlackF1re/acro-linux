# Graphics and input metadata

- Framebuffers: `fb0` (`msmfb41_80000`) and `fb1` (`msmfb41_70001`); the
  Android `graphics/hdmi` node links to fb1.
- GPU nodes: `/dev/kgsl-3d0`, `/dev/kgsl-2d0`, `/dev/kgsl-2d1`; platform
  drivers `kgsl-3d` and `kgsl-2d` are bound.
- Display platform devices include MDP, MIPI DSI, `mipi_renesas_r63306`, and
  HDMI MSM. `/proc/iomem` also maps the corresponding engines.
- Input devices: `clearpad` touchscreen, `fuji-keypad`, `keypad-pmic-fuji`,
  `gpio-key`, PMIC power key, `simple_remote` headset controls, bma250,
  compass, and apds9702.
- LED/backlight paths expose red, green, blue, button backlight, LCD
  backlight, two camera-flash LEDs, and `timed_output/vibrator`.

Evidence: `VERIFIED_DEVICE` for nodes and registered input names;
implementation status `PROBES`. No display, touch, key, GPU, LED, flash, or
haptics acceptance test was performed.
