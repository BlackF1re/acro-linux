# Hikari g32 secure-MMCC diagnosis

Status: sanitized `VERIFIED_DEVICE` post-mortem evidence. Display scanout,
panel pixels and fbcon remain `NOT_VERIFIED` until the corrected artifact is
run on the phone.

## Physical attempt

The deployed artifact was:

```text
/home/paul/xperia/build/hikari-artifacts-g32-display/hikari-display-mdp-clocks-held.elf
size: 12,515,916 bytes
SHA-256: 046841539bc018cb98767521e820a6cbdcdc55fa27054e23f32574b18db79bf4
kernel: 7.3.0-rc1-g054686144ee3
```

TWRP exported the previous boot through `/proc/last_kmsg`. The private raw
capture is 12,576 bytes with SHA-256
`e929affdd5c68eaca922eb1a65c017c3c1231f9211d984ffa30ff42d0b7ba994`.
It contains ring/ECC damage after the coherent mainline portion, so no bytes
after the corruption boundary are used as evidence. Raw command-line and
device-unique data remain outside Git.

## Boot timeline

```text
0.661  g_serial registered and reported ready
0.670  AS3676 backlight controller detected at 0x40
0.880  MMSS fabric master ports unhalted through RPM
0.908  MDP clock-assisted footswitch sequence reported complete, GFS=0x0
0.912  MSM8x60 DSI V2 configuration selected
0.913  one-shot DSI firmware state quiesced with DSI AHB retained
0.924  MDP4 bound the DSI component
0.928  entering MDP4 revision read with display power domain enabled
```

There is no later MDP revision, `/init`, USB enumeration, Oops or panic in the
coherent log. The owner observed neither usable display output nor usable USB.

`LAST_CONFIRMED_STAGE`: entry into `read_mdp_hw_revision()`.

`FIRST_UNCONFIRMED_STAGE`: completion of the first read from MDP4 physical
base `0x05100000`.

This reproduces the g30 register-bus stall after removing the unrelated g31
cleanup Oops. USB failure in this attempt is a consequence of the global
early display/MMSS stall, not evidence that the already verified HS PHY,
ChipIdea UDC or `g_serial` path regressed.

## Root cause and correction

The critical runtime clue is the footswitch readback `GFS=0x0`: the enable bit
did not latch even though the software sequence continued. Exact Sony/C.A.F.
MSM8x60 sources select `MSM_SECURE_IO` and route the complete multimedia clock
controller access path—including clock, PLL and footswitch registers—through
SCM IO read/write calls. The earlier mainline port accessed the MMCC resource
as ordinary MMIO, so its footswitch writes were not effective.

Kernel commit `067c4e54fde9b7d909b5f2220e5d9b3df8a2f75e` maps the complete
MSM8660 MMCC regmap through `qcom_scm_io_readl()` and
`qcom_scm_io_writel()`, defers until SCM is available, programs the exact
legacy footswitch delay/retention fields, and refuses MDP MMIO unless final
`ENABLE|CLAMP` readback is exactly `ENABLE`. Thus failure is bounded and must
leave the verified USB/PID1 diagnostics alive rather than reading an
inaccessible MDP register.

The corresponding locally validated artifact is:

```text
/home/paul/xperia/build/hikari-artifacts-g33-display/hikari-display-secure-mmcc.elf
size: 12,516,700 bytes
SHA-256: 8f0dbccff8f06dbdadb21f1837d83a9b36d2ed718e2fdaac654aabe8d232d7cd
kernel commit: 067c4e54fde9b7d909b5f2220e5d9b3df8a2f75e
```

It has not been sent to the phone. Its build, final Hikari DT schema, Sony ELF,
appended-DTB, SMEM, ramoops and memory-layout gates pass. This is a targeted
boot-blocker correction, not a physical display acceptance claim.
