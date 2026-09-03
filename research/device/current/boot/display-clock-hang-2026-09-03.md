# Hikari display clock-hang diagnosis

Status: sanitized `VERIFIED_DEVICE` diagnostic evidence. Raw persistent logs
remain private. Display function is not yet verified.

The physical run reached the MSM8x60 DSI runtime-PM path but did not reach
`/init`. The persistent console captured the terminal sequence:

```text
dsi_m_ahb_clk status stuck at 'on'
clk_branch_toggle
clk_core_disable
clk_bulk_disable
msm_dsi_runtime_suspend
```

A later trace also named `amp_ahb_clk`. CPU0 was stuck in the clock-disable
poll before initramfs userspace, so loss of the USB terminal in this run does
not indicate regression of the already verified PHY/UDC/g_serial hardware.

Exact Sony/OpenSEMC `clock-8x60.c` assigns MMSS debug/status bits as follows:

| Branch | Halt bit |
| --- | ---: |
| AMP AHB | 18 |
| DSI master AHB | 19 |
| DSI slave AHB | 20 |

The project bootstrap MMCC definition used bit 21 for DSI slave AHB and marked
it `CLK_IS_CRITICAL`. Kernel commit `200115087c00` changes it to bit 20 and
removes the critical override so DRM/MSM runtime PM owns the three DSI branch
clocks consistently.

A separate byte-for-byte comparison with exact Hikari downstream file
`mipi_tmd_video_wxga_mdv22.c` showed that several modern panel-table entries
declared one byte fewer than their initializer contained. Kernel commit
`6b09d9bff5cf` corrects the C0 and C8--CE counts. The build now rejects either
clock regression or a mismatched command count.

The corrected local artifact is documented in `docs/BUILD.md`. Only a
physical run can establish DRM registration, visible panel output, backlight,
fbcon, reliable USB enumeration during display probing, or charging.

## Subsequent physical attempt: controller clock force-on

The next physical artifact passed component matching and selected the
MSM8x60 DSI V2 configuration. MDP4 bound successfully, but before `/init` the
persistent log recorded three consecutive branch-disable stalls:

```text
dsi_s_ahb_clk status stuck at 'on'
dsi_m_ahb_clk status stuck at 'on'
amp_ahb_clk status stuck at 'on'
```

The stack is `clk_bulk_disable()` from `msm_dsi_runtime_suspend()`. There are
no initramfs markers after it. The individual halt poll is bounded to about
200 microseconds; the warning path continues, and persistent-console stack
output explains most of the gaps between messages. Thus this is a proven
incomplete DSI teardown before userspace, but not a proven infinite loop or
the exact final instruction. It is not evidence that the already verified USB
PHY or UDC regressed.

The halt-bit assignments are correct in the current MMCC. The missing step is
hardware quiescence: exact Sony MSM8x60 `mipi_dsi.c` writes zero to DSI
`CLK_CTRL` (`+0x118`) and `CTRL`, disables its PLL, and then gates DSI master,
DSI slave, and AMP AHB in that order. The generic DRM/MSM V2 runtime-suspend
path only disabled the bulk clocks. Kernel commit `f88018605bf7` tested a
`CLK_CTRL`-only correction; physical g27 evidence showed that it was
insufficient. Kernel commit `b44a7cd030f7` implements the complete
MSM8x60-only sequence while retaining clock halt checking.

The same local correction cycle avoids the redundant forbidden voltage-change
request on the already fixed 3.05 V PM8058 L6 USB PHY rail and adds a one-time
BQ24160 `charging enabled` transition message. Neither positive-current
charging nor visible display output is claimed until the new artifact is run
on the phone.

## g27 physical result

Artifact SHA-256
`77df1b315303e746ff9292cc2b19f309e76ef6c64c91a6f18474c8f09562008b`
physically reached DSI configuration and MDP4 binding. The `CLK_CTRL`-only
quiesce still produced slave, master, and AMP AHB stuck-on warnings. The log
then became corrupt/truncated and contains no `/init` markers; the phone also
had no stable ACM interface or visible pixels. This narrows the required
change to the remaining source-derived quiesce operations but does not prove
where execution ultimately stopped.
