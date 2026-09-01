# Multimedia, radio, and sensors metadata

- ALSA reports one card, `msm-audio`, with two playback and two capture PCM
  devices. Legacy MSM audio, I2S, voice, codec, and HDMI-audio platform paths
  are registered.
- Camera/media nodes: `/dev/video0`–`/dev/video3`, `/dev/video100`,
  `/dev/media0`–`/dev/media2`, `/dev/gemini0`, `msm_camera/config0`, and
  MSM VFE/CSIC/camera-server/Gemini/VIDC/VPE platform devices.
- MSM video codec encode/decode, rotator, Gemini/JPEG and standalone VPE nodes
  are present.
- Modem-related paths: `pil_modem`, `msm_smd`, SMD control/packet nodes,
  rmnet interfaces, `/dev/diag`, and serial nodes. No modem command, SIM
  identity, radio state, or telephony action was issued.
- NFC is indicated by PM8058-side `pm8xxx-nfc` support and the separate I2C
  `pn544` controller. The former is not evidence of a second NFC controller.
  FM is indicated by the `APPS_FM` driver and `/dev/msm_fm`. GPSNMEA is a
  registered platform driver. These do not prove usability or a GNSS receiver.
- Sensor identities visible through input/I²C paths: BMA250 accelerometer,
  compass, and APDS9702 proximity/ambient-light family device.

Evidence: `VERIFIED_DEVICE` for exposed legacy interface registration;
implementation status `PROBES` or `UNKNOWN`. Audio, camera, modem, GNSS,
NFC, FM/RDS and every sensor still need function-specific tests.
