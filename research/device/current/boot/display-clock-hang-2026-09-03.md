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
