# Connectivity metadata

- Wi-Fi: `wlan0`; bound platform device `bcm4330_wlan`; loaded out-of-tree
  module `bcm4330`; two SDIO functions at `mmc2:0001:1` and `mmc2:0001:2`.
- Bluetooth: bound `bcm_bt_lpm` and `bt_power` platform devices; `rfkill0` is
  exposed. No pairing, traffic, address, or keys were queried.
- USB: Android gadget (`android_usb` / `msm_hsusb`), `msm_otg`, and
  `msm_hsusb_host` are bound. No USB mode was changed.
- Display output: two `hdmi_msm` devices and HDMI audio devices are bound.
- Networking interfaces include rmnet0–rmnet7 as well as wlan0; their
  addresses and state were intentionally not read.

Evidence: `VERIFIED_DEVICE` for registered interfaces; implementation status
`PROBES`. Wi-Fi, Bluetooth, USB device/host, HDMI, and mobile data require
separate real-device acceptance tests.
