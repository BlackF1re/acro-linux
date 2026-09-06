# Hikari live display pixel-clock mismatch

Status: sanitized `VERIFIED_DEVICE` diagnosis. The AS3676 backlight emitted
visible light, but the panel showed no pixels. The correction below is locally
implemented and still requires a physical display acceptance test.

## Physical result

The kernel containing the separate DSI-video `PRIMARY_VSYNC` correction booted
with stable USB ACM diagnostics. Runtime DRM state reported a connected and
enabled `DSI-1`, active CRTC, `720x1280@60`, XR24 framebuffer, `msmdrmfb`, and a
bound fbcon. A standard backlight-class unblank made the LCD backlight visibly
light, proving the AS3676 output path. No image was visible.

Neither the MDP nor DSI interrupt counter advanced. The kernel repeatedly
reported `vblank wait timed out on crtc 0`. The live clock tree exposed the
decisive mismatch:

```text
requested DRM mode: 69,673,000 Hz (69,673 kHz)
active mdp pixel:   76,800,000 Hz
exact panel rate:   69,672,960 Hz
```

## Cause and correction

DRM modes store the pixel clock in integer kHz, so the exact MDV22 result
`896 * 1296 * 60 = 69,672,960 Hz` is represented as `69,673 kHz`. The DSI host
therefore asks CCF for `69,673,000 Hz`. `qcom_find_freq()` selects the first
frequency-table row whose label is greater than or equal to the request. The
MMCC row was labelled `69,672,960`, only 40 Hz below the rounded request, so it
was skipped and the next row, `76,800,000`, was programmed.

Kernel commit `7da01ebc48fea5db687cb64dedbe5e2f7a4df312` labels the existing
Hikari row with the rounded DRM request `69,673,000` while retaining the exact
Sony-derived PLL8 M/N values `567/3125`. Hardware will therefore generate the
same approximately `69,672,960 Hz` panel clock, but the CCF selector can now
choose the row. A build-time source gate rejects both removal of this row and
reintroduction of the unselectable exact-Hz label.

This is the strongest evidence-backed current blocker. It does not yet prove
visible scanout: the next physical run must show the pixel clock near
69.673 MHz, advancing MDP/DSI interrupts, no repeating vblank timeouts, and a
visible native-resolution image.
