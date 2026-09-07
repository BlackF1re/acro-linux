# Hikari display: false MDP LUT clock gate blocked DRM startup

## Physical boundary

The physical run of the DSI-PLL successor remained alive with a stable USB
console, but did not create `card0` or `fb0`.  The first fatal display error
was before the MDP revision read:

```text
mdp4 ... reading MDP4 revision with display power domain enabled
mdp_lut_clk status stuck at 'off'
error -EBUSY: failed to enable MDP clocks for revision read
failed to load kms
```

DSI V2 had already bound as an MDP component, the MDP power domain was on,
and AS3676 had probed.  Consequently this run did not exercise the panel or
the corrected DSI PLL.  The later clock-disable warnings are unwind noise,
not a second root cause.

## Source comparison and correction

The exact Sony MSM8x60 clock implementation (`clock-8x60.c`) exposes
`mdp_clk` as `mdp.0`'s `core_clk` and `mdp_vsync_clk`; it has no independently
gateable MDP LUT clock.  The project MMCC description instead used the
MSM8960 LUT gate registers (`0x016c`, halt status `0x01e8` bit 13).  Physical
polling showed that this supposed gate cannot be controlled on MSM8260.

Signed kernel commit `b776ddafcde9eba1f5c81b34f54c533605c880ca`
removes that false branch clock and aliases the binding's `MDP_LUT_CLK` ID to
the real MDP core clock.  This keeps the common MDP4 DT clock ABI intact while
matching the Sony hardware model.  The common-clock framework refcounts the
duplicate core-clock handle, so the MDP4 enable/disable sequence remains
balanced.

Visible scanout remains `NOT_VERIFIED` until this successor is physically
tested.

