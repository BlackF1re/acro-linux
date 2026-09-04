# Hikari g31 MMCC cleanup Oops

Status: sanitized `VERIFIED_DEVICE` post-mortem evidence. Display scanout and
fbcon remain `NOT_VERIFIED`.

## Physical attempt

The deployed artifact was:

```text
/home/paul/xperia/build/hikari-artifacts-g31-display/hikari-display-footswitch.elf
size: 12,516,268 bytes
SHA-256: 7fbe6eeced9be6848b700e7e02b6f1646ea4f87c7a391f439d708a28b4d009e3
kernel: 7.3.0-rc1-g18f656abb9fb
```

The owner observed stable USB presence without the earlier reconnect loop, but
no image. Recovery exported the previous persistent console before its own
diagnostics. The private raw log is 49,736 bytes with SHA-256
`330250df1b4379177de0bd7881b3da2ca5ca3a669bd48d207c6a7fb7406c34cb`.
It contains ring/ECC damage after the mainline crash, so only the coherent
mainline portion through the Oops is used below. No raw command line or unique
identifier is committed.

## Boot timeline

```text
0.914  g_serial registered and reported ready
0.922  AS3676 backlight controller detected at 0x40
1.119  MMSS fabric master ports unhalted
1.432  MDP clock-assisted footswitch sequence completed
1.755  mdp_lcdc_clk disable reported status stuck on
2.080  mdp_pixel_clk disable reported status stuck on
2.407  mdp_tv_clk disable reported status stuck on
2.410  NULL dereference in clk_hw_round_rate
```

The reliable trace is:

```text
clk_hw_round_rate
  -> clk_rcg_bypass_determine_rate
  -> clk_core_round_rate_nolock
  -> clk_core_set_rate_nolock
  -> clk_set_rate
  -> mmcc_msm8660_init_mdp_footswitch
  -> mmcc_msm8660_probe
```

`scripts/faddr2line` maps the preceding cleanup warnings to
`clk_disable_unprepare()` in the footswitch cleanup. The fatal operation is the
subsequent restoration of a bootloader rate on a bypass RCG. Its incomplete
parent model reaches `clk_hw_round_rate()` with a null parent.

The footswitch sequence itself succeeded. The failure is therefore not a
panel, DSI packet, framebuffer, or USB-PHY result: the kernel Oops occurred
during MMCC probe cleanup, before DRM could probe and before `/init`. This also
explains why the host saw a stable physical USB connection but received no
userspace console bytes.

## Narrow correction

Kernel commit `054686144ee3469b34cb3a72991ae0f5964f20a7` keeps the eight MDP
reset-clock references prepared while the temporary `RPM_ALWAYS_ON` MDP domain
is alive. It no longer disables branches which hardware still reports active
or restores unsafe bootloader rates. Device-managed cleanup releases the
references on probe failure or driver removal.

This is deliberately a bring-up lifetime policy, not final runtime power
management. It removes the observed crash boundary without claiming that the
next DRM, DSI, panel, or backlight stage will pass on hardware.

## Next locally validated artifact

```text
/home/paul/xperia/build/hikari-artifacts-g32-display/hikari-display-mdp-clocks-held.elf
size: 12,515,916 bytes
SHA-256: 046841539bc018cb98767521e820a6cbdcdc55fa27054e23f32574b18db79bf4
kernel commit: 054686144ee3469b34cb3a72991ae0f5964f20a7
```

Its Sony ELF, appended DTB, SMEM reservation, persistent console and memory
layout checks pass. It has not been sent to the phone.
