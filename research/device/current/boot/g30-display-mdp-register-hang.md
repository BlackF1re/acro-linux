# Hikari g30 MDP register-bus hang

Status: sanitized `VERIFIED_DEVICE` post-mortem evidence.  Display scanout,
panel pixels and fbcon remain `NOT_VERIFIED`.

The deployed artifact was:

```text
/home/paul/xperia/build/hikari-artifacts-g30-display/hikari-display-mdp-gdsc.elf
size:   12,515,732 bytes
SHA-256 2705e0c4cd7e0afd6b109ea84ec63dc476d116592518fe465876b449956929a3
```

TWRP exported the previous boot through `/proc/last_kmsg`.  The private raw
capture is 12,452 bytes with SHA-256
`e4c209adc3639d9976e6ab78cab3553653d62c7b8372f933d0868fa224e72be5`.
It remains outside Git because its bootloader command line contains a unique
device identifier.

## Physical timeline

The retained console identifies Linux `7.3.0-rc1-g2b964964f5fd`, the Hikari
DT, two CPUs, the corrected RAM/SMEM map, ramoops, RPM and all four MSM8660
interconnect providers.  The relevant terminal sequence is:

```text
0.977028  initrd memory freed
0.996788  g_serial gadget driver registered
1.006552  AS3676 detected at I2C address 0x40
1.153304  MMSS fabric master ports 0-13 unhalted through RPM
1.185962  MSM8x60 DSI V2 configuration selected
1.187623  one-shot DSI firmware state quiesced
1.198396  MDP4 bound the DSI component
1.201823  entering MDP4 revision read with its display domain enabled
```

There is no subsequent MDP4 version, panic, oops, `/init`, Hikari userspace
marker, or physical USB enumeration message.  The owner saw the AS3676-driven
backlight but no pixels, and the host saw unstable USB presence.  `g_serial
ready` is registration of the gadget driver, not proof that this boot reached
UDC enumeration.

`LAST_CONFIRMED_STAGE`: MDP4/DSI component binding and entry into
`read_mdp_hw_revision()`.

`FIRST_UNCONFIRMED_STAGE`: return from the first
`mdp4_read(REG_MDP4_VERSION)` at physical MDP base `0x05100000`.

This is an evidence-backed MMSS register-bus lock boundary, not a panel-command
or framebuffer diagnosis.  It also explains the apparent USB regression: the
whole kernel stopped before the proven gadget path could finish, rather than
the USB PHY/ULPI/ChipIdea implementation becoming invalid.

## Why the plain power-domain link was insufficient

The g30 DT attached MDP4 to MMCC `MDP_GDSC`, but the generic GDSC operation
does not reproduce the MSM8x60 `FS_MDP` enable recipe.  Exact Sony/C.A.F.
source in `footswitch-8x60.c` and `devices-msm8x60.c` requires all eight MDP
domain clocks, both MDP AXI ports unhalted, AXI/AHB/core-domain resets, rail
enable, a charge delay, clamp removal, reset release and core/pixel memory
retention.  Trusting only the bootloader-visible ENABLE/CLAMP state therefore
left the register bus inaccessible even though the generic power-domain attach
succeeded.

Signed kernel commit `678b7e106c20` adds the source-derived, one-shot
clock-assisted MDP footswitch initialization and keeps the legacy island on
until a complete runtime-collapse sequence exists.  Signed commit
`18f656abb9fb` makes MDP4 clock errors fail safely and uses the MSM8260 200 MHz
MDP limit.  If any prerequisite is unavailable, the display probe now returns
an error instead of deliberately reading the inaccessible register; the
physically verified USB console and PID 1 remain available for diagnosis.

The resulting g31 artifact is locally validated only.  It is not a physical
display acceptance result and was not sent to the phone during this analysis.
