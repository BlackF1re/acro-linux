# Hikari g29 display power-domain stall

Status: sanitized `VERIFIED_DEVICE` diagnostic evidence. Display pixels and
fbcon remain `NOT_VERIFIED`.

The previous-boot export was captured from TWRP before other recovery
diagnostics:

```text
private file: research/private/hikari-recovery-debug/g29-runtime-pm-safe-20260904/previous-proc-last_kmsg-20260904T051307Z.raw
size: 49,291 bytes
SHA-256: 6c039e617a12308f647b53e01cab3c5153b335ec6d971a8e6d832a5b2e171a51
```

The raw persistent ring contains a valid leading mainline record followed by
stale/corrupt legacy-ring data. Only the prefix identified by Linux
`7.3.0-rc1-g3c1ddf679af0` and model `Sony Xperia acro S (Hikari)` is used
below. The raw file stays private because its later legacy content was not
sanitized.

## Physical timeline

The leading record proves this progression:

```text
0.151  ramoops console enabled
0.173  Qualcomm RPM firmware 2.0.102
0.201  MSM8x60 MMFAB registered
0.864  built-in g_serial driver registered (not USB enumeration)
0.874  AS3676 detected at 0x40
1.145  MSM8x60 MMCC fabric unhalt completed
1.182  BQ24160 charging-enabled programming completed
1.371  MSM8x60 DSI V2 configuration selected
1.387  one-shot firmware-state quiesce completed; AHB clocks retained
1.393  MDP4 component bound the DSI component
8.477..72.133  asynchronous charger-policy work continued
```

There is no subsequent `MDP4 version`, DRM registration, initramfs release,
`Run /init`, or Hikari init marker in the mainline prefix. Background workqueue
messages continuing for 72 seconds rule out a whole-kernel panic at 1.393.
The physical backlight was visible, but the host did not enumerate the USB
gadget.

## Root cause and correction

The deployed Hikari DT described MDP4 clocks but omitted its power domain.
Current `mdp4_kms_init()` enables the clocks and immediately reads
`REG_MDP4_VERSION`; the missing version message locates the first unconfirmed
operation at that MMIO read. Reading an unpowered MSM8x60 multimedia island
can stall the initiating CPU rather than return a clean bus error.

Exact Sony/OpenSEMC MSM8x60 sources independently require footswitch
`FS_MDP` for `mdp.0` and associate its clocks with `footswitch-8x60.4`:

```text
arch/arm/mach-msm/devices-msm8x60.c: FS_8X60(FS_MDP, "vdd", "mdp.0", ...)
arch/arm/mach-msm/clock-8x60.c:       mdp clocks -> footswitch-8x60.4
```

The current MMCC implementation represents that hardware as `MDP_GDSC` ID 4,
GDSCR offset `0x0190`. The modern platform core attaches a DT power domain
with `PD_FLAG_ATTACH_POWER_ON` before driver probe. The corrected DT therefore
adds exactly:

```dts
power-domains = <&mmcc MDP_GDSC>;
```

The MDP4 binding now permits one power domain, and a host gate resolves the
final DTB phandle and rejects any domain other than MMCC ID 4. A diagnostic
message immediately precedes the first revision read.

As a containment measure, `driver_async_probe=mdp4,msm_dsi` moves display
component probing off the synchronous initcall path. If another MMSS access
stalls, later USB initcalls can still register the already verified ttyGS0
kernel console. This does not hide a display error and does not replace the
GDSC fix.

`LAST_CONFIRMED_STAGE`: MDP4 bound the DSI component.

`FIRST_UNCONFIRMED_STAGE`: powered MDP4 revision read / continuation of KMS
initialization.

USB is not reclassified as broken: `g_serial ready` is only gadget-driver
registration. The display initcall stalled before the UDC could probe and
enumerate, so the missing host USB device is a downstream consequence.
