# Status

The physical reconnaissance baseline is ScrubbModRom KK4.4.2 v1.4.1, Android
4.4.2 userdebug/test-keys, with custom 3.4.0-Elite-1.5+. It is not a clean
Sony stock baseline. Its board files, driver registrations and logs are useful
evidence, but its policy and parameters are not factory facts.

In particular, a 1890 MHz CPU setting observed in this custom kernel is not a
Sony-approved OPP and must not be carried into a target kernel without
independent evidence and validation.

## Boot and recovery characterization

Physical fastboot is `VERIFIED_DEVICE`: Sony S1Boot Fastboot appears as
`0fce:0dde`, protocol `0.5`, version `CRH1099189_R10C008`, with `secure: no`.
The old S1Boot returns empty `unlocked` and boot-partition metadata variables;
this is unsupported/absent metadata, not evidence of a locked bootloader.
Owner history independently records an earlier unlock, custom ROM installation,
and root; it is retained as owner-provided history rather than an attestation.
Following the first failed native-Linux attempt, **Power + Volume Up** was
observed to force reset/shutdown; this is distinct from phone-off Volume-Up USB
entry to S1Boot.

The currently installed recovery is `VERIFIED_DEVICE` as a reachable TWRP
2.6.3.0 runtime: `adb reboot recovery` reached it and the owner returned to
Android normally. Offline p3 analysis shows that its bootrec controller refers
to p11 as an external FOTA/recovery payload, but p11 has not been read. Thus
its physical storage, relationship to p3, and independence as a rollback route
remain `UNKNOWN`. The current p3 legacy `/boot` artifact is a verified Sony ELF
layout documented in [BOOT_FORMAT.md](BOOT_FORMAT.md). The first local-only
upstream Hikari kernel/DTB/initramfs/ELF prototype was physically written once:
S1Boot accepted it, but no target-Linux proof of life appeared during the
120-second observation window. `FIRST_MAINLINE_BOOT` is therefore
`NOT_VERIFIED`, not a kernel-panic diagnosis.

The rollback model is now `VERIFIED_DEVICE`: after the failed attempt, hardware
S1Boot entry remained available; the exact original p3 ELF was flashed through
logical `boot`; and the ScrubbModRom baseline returned normally. This proves
the p3 rollback route for this device and artifact, without generalizing it to
other partitions. `fastboot boot` remains `UNKNOWN`. See [ROLLBACK.md](ROLLBACK.md).

The second candidate was physically written once and S1Boot accepted the
expected logical `boot`/p3 mapping. After reboot, the 120-second observation
had no target-Linux marker, ADB, fastboot, or new USB target; the owner
observed a black, unresponsive handset and used the verified **Power + Volume
Up** forced reset. The original p3 was restored and Android returned. Thus
`SECOND_MAINLINE_BOOT` is `NOT_VERIFIED` and `BOOT_PROOF` is `NOT_OBSERVED`.
The only captured TWRP previous-boot log belongs to a later legacy Android
reboot, so it does not locate the target failure stage; see
[secondboot post-mortem](../research/device/current/boot/secondboot-postmortem.md).

Post-attempt review identified a double application of the MSM8x60 SMEM offset
in the second DTS/layout model. TWRP's later read-only `/proc/iomem` capture
now physically confirms that Linux-visible low System RAM begins at
`0x40200000`, while its own code is at `0x40208000`; this supports the
corrected physical-base/SMEM model without making a target-boot claim. Boot #4
uses `0x40208000` again and reserves a distinct legacy-compatible persistent
console at `0x7ffe0000-0x7fffffff`. See
[FIRST_BOOT_MEMORY.md](FIRST_BOOT_MEMORY.md) and
[PERSISTENT_LOGGING.md](PERSISTENT_LOGGING.md).

Boot #4 then provided the first direct target-kernel execution evidence. Its
recovered `/proc/last_kmsg`, exported by TWRP from the compatible persistent
console before recovery reset the physical ring, identifies the Hikari FDT,
corrected RAM layout, two CPU bring-up, ramoops, RPM, initramfs unpacking, and
`Run /init as init process`. The diagnostic PID 1 then exited with status zero,
causing `Attempted to kill init`; this is a controlled initramfs-liveness bug,
not an early-kernel hang. Thus `FIRST_MAINLINE_EXECUTION=VERIFIED_DEVICE` and
target lifecycle is `BOOTS` at the native initramfs boundary. No peripheral
acceptance claim follows. See [boot #4 post-mortem](../research/device/current/boot/boot4-postmortem.md).

BOOT #5 then physically verified the target USB device-mode hardware path:
the Qualcomm HS PHY, vendor ULPI initialization, ChipIdea UDC, and built-in
`g_serial` enumerated as non-unique `0525:a4a7` at High Speed (480 Mbps), and
the host created `/dev/ttyACM0`. BOOT #5.1 corrected BOOT #5's missing device
nodes and BusyBox applet links, then physically exposed `/dev/ttyGS0` and an
interactive root shell. The first shell exited with status zero and the
independent supervisor spawned another one. `HIKARI ALIVE` markers from 2.18
through 1082.67 seconds prove a stable PID 1 and supervisor for at least
18 minutes. The initial `uname: not found` was caused by missing initramfs
symlinks, not a missing compiled BusyBox applet. The L6 voltage warning was
non-blocking for this acceptance test and remains a power-management blocker.

BOOT #6 has now reached a physically working display. It adds source-derived
MSM8x60 MMCC/GDSC/NoC infrastructure, MDP4, the DRM/MSM DSI v2 host, a fixed
rate 45 nm DSI PHY, the exact R63306/TMD MDV22 panel profile, AS3676
backlight, fbdev emulation and fbcon while preserving the verified USB and
ramoops paths. The final 0066 run produced visible native 720x1280 fbcon,
active MDP/DSI interrupts, and no scanout underrun or kernel fault. See
[DISPLAY_BOOT6.md](DISPLAY_BOOT6.md).

The latest live diagnosis rules out both a missing GPU and an empty
framebuffer: MDP4 had a changing dumb framebuffer and does not need Adreno for
scanout. The DSI parent correction was physically deployed and retained a
working USB shell, but the next exact failure was `dsi1_clk status stuck at
'off'`: the core gate write is accepted while MSM8x60 halt readback
`0x01d0/bit2` falsely remains off, causing `msm_dsi_host_power_on()` to return
`-EBUSY` before DSI video starts. Sony enables this gate without a status poll;
the successor kernel uses `BRANCH_HALT_SKIP` for this proven unreliable branch
while retaining the actual gate operation. Display remains `PARTIAL`, not
`VERIFIED`, until visible stable pixels are observed.

The successor physical run passed that clock boundary but timed out on the
first MDV22 command (`0xb0`). The DSI DMA register contained MDP-domain IOVA
`0x7bc41000`, outside physical RAM; the trigger remained asserted and DSI IRQ
114 stayed at zero. The V2 host had allocated its command buffer against the
IOMMU-attached DRM/MDP device rather than the DSI bus master. A narrow fix now
allocates/frees the buffer through the DSI platform device. It is built and
validated, not yet physically verified.

BOOT #7 supplied the first display-path post-mortem: deferred DRM/MSM probing
faulted before `/init` because the Hikari DTS connected DSI to MDP4 port 0,
which current DRM/MSM deliberately excludes from component matching.  DSI1 is
MDP4 port 1.  The corrected DT graph is built into the canonical locally
validated artifact, and its static gate rejects the old port-0 topology. This
is a precise software boot-blocker diagnosis, not a target-Linux display
acceptance claim. See
[the sanitized BOOT #7 evidence](../research/device/current/boot/boot7-display-component-crash.md).

The next live run passed component matching and DSI variant selection, then
hard-stalled CPU0 before `/init` in DSI runtime suspend while waiting for an
incorrectly described MMSS clock branch. Exact MSM8x60 source assigns DSI
slave AHB halt bit 20, while the bootstrap MMCC driver used bit 21 and marked
the branch critical. The current local kernel corrects that ownership/bit and
also fixes truncated MDV22 command-table payloads. These corrections are built
and validated but not deployed; display/fbcon remain `NOT_VERIFIED`.

A later physical log advanced to DSI link-clock setup and rejected three
unsupported runtime reparent operations with `-EINVAL`. Exact Fuji clock data
shows that MSM8x60 uses a direct byte branch, fixed PXO/2 escape clock, and the
shared MDP pixel RCG rather than the APQ8064-style source-clock graph. The
current local kernel and canonical project DTS implement that model; the build
gate now rejects the obsolete assigned-parent topology. This is a precise
software correction, not yet evidence of visible scanout or charging.

The g27 physical log selected the MSM8x60 DSI V2 configuration and bound MDP4,
then emitted checked-disable warnings for `dsi_s_ahb_clk`, `dsi_m_ahb_clk`,
and `amp_ahb_clk` before the persistent ring became corrupt/truncated. It did
not reach an observable `/init` or stable ACM terminal. The individual halt
poll is bounded, so the warnings identify an incomplete boot-state teardown,
not a proven infinite loop or exact terminal instruction. Exact Sony shutdown
clears DSI `CLK_CTRL`, `CTRL`, and the 45 nm PLL. A subsequent artifact placed
that full operation in repeatable `msm_dsi_runtime_suspend()` and again ended
around the same three branch-disable warnings before `/init`. The current
local kernel instead performs firmware handoff exactly once during DSI probe,
under a tracked clock reference, and retains those AHB clocks across normal
runtime suspend/resume. Removal/error unwind releases them. This avoids both
repeated controller destruction and the physically failing halt-poll path at
the deliberate cost of higher display-block bring-up power. Physical display
acceptance remains open. The same g27 log physically verified charger
activation and a status transition, but not positive battery current or
increasing state of charge.

The g29 log located a missing MDP power-domain relationship. The subsequent
g30 physical log proved that a plain `MDP_GDSC` attachment still left the
MSM8x60 register bus inaccessible: after DSI quiesce and component binding,
the kernel stopped exactly at the first MDP4 version-register read. AS3676 had
already enabled the observed backlight; g_serial had only registered, so the
global MMSS hang also prevented stable physical USB enumeration. The current
local correction reproduces the exact Sony/C.A.F. eight-clock FS_MDP reset,
rail, unclamp and retention sequence, retains the island for bring-up, caps
MSM8260 MDP at 200 MHz, and rejects clock failures before MMIO. Display probing
remains asynchronous as a USB-console fail-safe. This is an evidence-backed
boot-blocker fix, not a claim that scanout or fbcon is working.

The g31 physical log then proved that the source-derived MDP footswitch
sequence itself completed. Its cleanup immediately reported the LCDC, pixel
and TV branches stuck on, then dereferenced a null clock parent while restoring
a bootloader rate through `clk_rcg_bypass_determine_rate()`. This kernel Oops
occurred during MMCC probe, before DRM and `/init`; it explains the stable USB
electrical connection without terminal bytes and gives no panel verdict. The
current g32 local kernel keeps the eight reset-clock references prepared for
the temporary always-on domain and releases them only through device-managed
probe/unbind cleanup. See [the sanitized g31 post-mortem](../research/device/current/boot/g31-display-mmcc-cleanup-oops.md).

The g32 physical run removed that cleanup Oops but again stopped at the first
MDP4 register read. Its decisive clue is the preceding footswitch readback
`GFS=0x0`: the enable operation never latched. Exact Sony/C.A.F. MSM8x60 code
selects secure IO and routes the complete multimedia clock-controller access
path through SCM. The current local kernel therefore uses SCM-backed MMCC
regmap accesses, restores the legacy footswitch delay/retention setup, and
rejects an invalid final enable/clamp readback before MDP MMIO. The corrected
artifact became physical run g33; display/fbcon remained `NOT_VERIFIED` and
the next supplier failure boundary is recorded below. See [the sanitized g32
post-mortem](../research/device/current/boot/g32-display-secure-mmcc.md).

The g33 physical run proved that the secure-MMCC implementation failed safely
but never reached MMCC probe.  The native kernel and USB shell remained alive;
`4000000.clock-controller` was unbound and DSI/MDP were deferred behind it.
Although the architecture convention probe printed `qcom_scm: convention: smc
legacy`, there was no bound SCM platform device because the Hikari DT lacked a
`qcom,scm` firmware node.  The current local DT now instantiates the MSM8660
SCM interface with its required RPM Daytona core clock.  The final DTB and a
scoped SCM `dtbs_check` pass.  This fixes the exact deferred-supplier boundary;
display pixels, fbcon, and real backlight output remain `NOT_VERIFIED` until a
physical run. See [the sanitized g33 diagnosis](../research/device/current/boot/g33-display-scm-provider.md).

The later g35 physical run proved that the SCM provider itself binds, then
stopped synchronously at the first secure MMCC operation before DRM, `/init`,
or stable UDC operation. The retained log contains no Oops or panic. Exact
Sony MSM8x60 source exposed two concrete implementation errors: legacy atomic
`SCM_IO_READ` returns its register value directly in `r0`, not SMCCC-style
`r1`, and MMCC `SAXI_EN` is register offset `0x0030` with value `0x000001d8`
(not offset `0x01d8`). The current local kernel corrects both, restores the
exact Sony AHB/MAXI masks, and adds post-operation stage markers. At that
checkpoint the g36 ELF passed all local gates; display/fbcon were still
`NOT_VERIFIED`. See [the sanitized g35 diagnosis](../research/device/current/boot/g35-display-secure-mmcc-init-hang.md).

The latest retained physical log proves that those secure-MMCC corrections
worked: AHB/AXI setup completed, MMFAB unhalted, the MDP footswitch latched
`GFS=0x11f`, and the first MDP IOMMU provider registered. Deferred MDP probing
then hit a reproducible null dereference in `qcom_iommu_of_xlate()`. The
generic driver kept one client pointer even though MDP spans two independent
IOMMU providers; a failed first probe left a provider-local master behind but
the retry had a null per-device pointer. Exact Sony context-bank/MID data and
the current working Tenderloin MSM8x60 implementation agree that the client
must be tracked independently within each provider. Signed kernel commit
`fb48685d80a0` implements that model, and the successor ELF passes the complete
local display/DT/build/memory validation suite. This removes the observed
pre-DRM crash; pixels and fbcon still require physical verification. See
[the sanitized IOMMU post-mortem](../research/device/current/boot/display-mdp-iommu-multiprovider-oops.md).

The physical successor passed that correction: both MDP IOMMU providers
registered, DSI V2 initialized, MDP4 bound to DSI, and MDP4 version v4.1 was
read. It then crashed while ARM32 detached its automatic DMA domain before DRM
created the display IOVA domain. The legacy driver used the MDP client itself
for ARMv7s page-table DMA cache maintenance, so freeing a page table recursively
entered the same domain's DMA-unmap path and failed in `__bitmap_clear()`.
Signed kernel commit `96651e282822` assigns the physical IOMMU provider as the
page-table DMA owner and corrects page-table/context lifetime across both
providers. A fresh successor ELF passed the full clean build and local gates;
the physical successor passed both IOMMU attachments and remained alive for at
least 895 seconds without an Oops. Its fbdev damage worker instead timed out
waiting for every vblank. Exact Sony DSI-video code separates primary-DMA
completion from `PRIMARY_VSYNC`, while current MDP4 had used the DMA-complete
interrupt for both commit completion and vblank accounting. The current kernel
now keeps those IRQs separate and uses `PRIMARY_VSYNC` for DSI video. That run
also exposed a diagnostic-format bug: a full 131,060-byte zero-ECC mainline
ring exceeds TWRP's 116,468-byte ECC-enabled ring capacity. Ramoops now uses
the exact recovery defaults (`128/16/8/0x11d`). Both corrections are built-time
guarded but still need this physical run for display and full-ring acceptance.
See the sanitized
[page-table DMA post-mortem](../research/device/current/boot/display-mdp-iommu-pgtable-dma-oops.md)
and [vblank-timeout diagnosis](../research/device/current/boot/display-mdp-vblank-timeout.md).

That physical run reached an active DRM `720x1280@60` mode, `msmdrmfb`, and a
bound fbcon. A standard backlight-class unblank produced visible LCD
illumination, so the target AS3676 backlight path is now `VERIFIED_DEVICE`.
There were still no pixels or MDP/DSI interrupts. Live `clk_summary` showed the
MDP pixel clock at 76.8 MHz: DRM requests 69,673,000 Hz for its rounded
69,673 kHz mode, while the MMCC table had labelled the exact Hikari M/N row
69,672,960 Hz. The generic ceiling selector skipped that row. Kernel commit
`7da01ebc48fe` retains the exact `567/3125` divider but labels it with the
rounded request. Visible pixels and fbcon remain `NOT_VERIFIED` pending the
next physical run. See the
[live clock diagnosis](../research/device/current/boot/display-pixel-clock-mismatch.md).

## Status domains

status/hardware.yaml deliberately separates physical hardware evidence, the
legacy Android baseline, and native target-Linux progress for every subsystem.
The legacy baseline and target Linux both have a `BOOTS` lifecycle. BOOT #5.1
physically verified native initramfs execution, stable PID 1, persistent
diagnostics, and the USB peripheral/root-console path. Legacy runtime
observations are retained in their own field, but are neither target-Linux
progress nor functional verification.

VERIFIED is reserved for a defined acceptance test on the physical Xperia.
This pass was topology collection only; it performed no functional acceptance
tests.
## Native charging (local implementation)

The first native BQ24160/BQ27520 charging stack is `IMPLEMENTING`. Both chips
physically probed and USB input was online, but the observed state was `Not
charging` with negative battery current. Raw status `0x27` identifies a
current USB-ready state plus a latched/read-to-clear fault-history value; the
driver previously misclassified that history as a current fatal fault. The
current local kernel fixes this without weakening the 500 mA cap,
temperature/voltage policy, read-only BQ27520 use, or NVM prohibition. Native
charging remains unverified pending positive-current/SOC testing. Raw
STAT/FAULT transition logging remains diagnostic; it does not force charging.
The latest local kernel additionally logs successful CE/HZ release once; the
last physical attempt stalled in DSI runtime suspend before initramfs could
provide a complete charge-current observation.
Cradle/IN and suspend charging remain blocked pending dedicated physical
evidence. See
[CHARGING.md](CHARGING.md).

The display-cleanup boot supplied the first long post-display charging and USB
trace. USB device mode initially enumerated and exchanged shell data, but the
transport was later lost while the BQ24160 reported a current USB-supply fault
and repeatedly lost/reacquired its input. The kernel and display remained alive
through at least 515 seconds. Battery voltage declined during the mainline run;
the immediate TWRP control instead measured +366 mA and a capacity increase
from 8% to 9% on the same cable. Target USB reliability is `REGRESSION` and
charging is `PARTIAL`; the correlation does not yet prove a shared cause. See
[the USB/charging post-mortem](../research/device/current/boot/usb-charging-postmortem-2026-09-11.md).

The local 0068 successor addresses both sides of that post-mortem without
changing the already verified display path. It selects BQ24160 USB input and
releases `OTG_LOCK` at probe, removes a blocking raw ttyGS write from the
reconnect supervisor, changes HSUSB1 to a GPIO-driven role switch, and adds
the exact PM8901 MPP1/NCP373 VBUS source chain. Host enable takes the charger
OTG lock and disables charging before energizing either 5 V switch. The full
kernel/DTB/initramfs/ELF build and static gates pass. At that point nothing in
this successor had been deployed: USB device was still `REGRESSION`, charging
was `PARTIAL`, and USB OTG had entered `IMPLEMENTING`. The later 0075 results
below supersede that interim USB-device status.

A later Sony-derived Android control run established the working hardware
baseline. Removing USB changed the fuel-gauge current from positive to
roughly -0.16--0.28 A and the charger to `Discharging`. Reconnecting the
notebook selected a standard downstream port at 500 mA; BQ24160 returned to
`Charging`, battery current reached +0.31--0.36 A, voltage rose from about
4.09 V to 4.18 V, and SOC advanced 93% to 94%. OTG independently enumerated
QUMO `090c:1000`, Kingston DataTraveler `0951:1665`, and a `25a7:fa61`
keyboard/mouse receiver. PM8901 MPP1 and TLMM28 asserted together and NCP373
fault recovered high. Cradle charging was not tested because the available
cradle appears defective.

The 0072 target log then isolated a DT numbering defect: both MPP GPIO chips
registered, but the PM8901 MPP1 consumer used specifier 0. The SSBI MPP driver
uses physical one-based MPP numbers, so its translation rejected 0 and the
fixed regulator remained at `-EPROBE_DEFER`. Changing PM8901 index 0 to
physical MPP1 fixed that consumer, but the first pass incorrectly treated the
Sony PM8058 indices as physical numbers.

The resulting 0073 display/GPU/safe bundle builds cleanly and passes the USB,
charging, board-hardware, display, GPU, diagnostic, memory-layout and artifact
gates. The compiled display DTB was independently checked for MPP1, the
then-assumed MPP10 and
the BQ24160 post-init dependency. The display fastboot ELF is 13,388,993 bytes
with SHA-256
`59a77176ffaf9090d56b91129f52e521363900485728e1b32409d07a288593f3`.
The 0073 image was then physically booted with the notebook cable attached.
Display and PID 1 remained alive, and BQ24160 reported `raw=0x2b`, current
state `USB_READY` with a stale fault-history field. However, `ttyGS0` was
disabled at about 2.25 seconds and ChipIdea registered its EHCI host
controller. Therefore the missing host enumeration was a target role-selection
failure, not merely a WSL forwarding failure.

The retained 0073 `last_kmsg` exposed a second one-based PMIC GPIO error.
PM8058 GPIO consumers use physical one-based specifiers, while USB ID was
encoded as 29. Reading that wrong line low made the connector falsely select
host mode with a normal notebook cable. The first correction used 30 and the
0074 image did not enumerate on either Windows or WSL. Rechecking Sony's
`board-msm8660.h` then established that its PMIC namespace explicitly starts
at zero: Sony GPIO index 30 is physical mainline GPIO31, and Sony MPP index 10
is physical mainline MPP11. PM8901 index 0 remains physical MPP1. The local DT
and compiled-DTB gate now encode and check GPIO31, MPP11 and MPP1.
The retained 0074 `last_kmsg` confirms the intermediate image still selected
EHCI host with the notebook cable: `g_serial` became ready at 1.03 seconds,
`ttyGS0` was disabled at 2.37 seconds and ChipIdea registered EHCI immediately
afterward. The final GPIO31/MPP11 correction is build 0075. On the phone it
enumerated the `g_serial` CDC ACM gadget at High Speed, carried bidirectional
root-shell traffic and repeated that result after a physical notebook-cable
disconnect/reconnect. USB device mode is therefore `WORKING` and
`VERIFIED_DEVICE`. The same run detected notebook power at both the USB
charger and BQ24160, but the battery was already at 4.080--4.096 V and the
Sony revision-23 policy correctly held charging off above 4.0 V. Positive
battery current below the 3.9 V restart threshold remains to be tested.

The attempted 0075 OTG transition supplied no observable VBUS and the gadget
did not return. The retained `last_kmsg` makes the failure narrower than the
power path: `ci_otg_work` blocked for more than 122 seconds in
`gserial_free_port()` while removing the UDC, before EHCI registered. Both the
kernel console and the immediately respawned diagnostic shell held `ttyGS0`
open. Build 0076 removed both holds. The physical run then registered and
removed EHCI three times and returned to the High-Speed serial gadget, proving
the dual-role transition itself no longer deadlocks. There was still no VBUS
or peripheral enumeration. Debugfs exposed PM8901 MPP1 as inherited
`digital bi-dir`; the generic SSBI MPP output callback failed to clear input
mode and ignored the requested value. Patch 0070 corrects those output-state
semantics in build 0077. The 0077 physical test completed the logical host
sequence but still supplied no power. Raw PM8901 readback made the cause
unambiguous: MPP1 register `0x27` remained `0x30`, while the generic driver
addressed the PM8058 MPP base `0x50`. Sony's PM8901 source specifies base
`0x27`; patch 0071 applies that compatible-specific base in build 0078.
Build 0079 supplied the missing physical result. The owner observed source
power at a Mercusys Wi-Fi adapter; retained `last_kmsg` records EHCI
registration, High-Speed enumeration of the Realtek `2c4e:0102` `802.11n NIC`,
its disconnect, EHCI removal, and return to USB device role. Target USB OTG is
therefore `WORKING` with `VERIFIED_DEVICE` evidence for role switching, VBUS,
enumeration/control traffic and teardown. Wi-Fi network traffic through that
adapter remains a separate untested function.

## Current display boundary: DSI PLL start

The latest retained physical run did not crash: DRM registered a native
`720x1280` framebuffer and fbcon, backlight illumination worked, `/init` and
the USB-shell supervisor ran, and PID 1 continued emitting alive markers. The
failure began at the first vblank wait because no DSI video interrupt arrived.

Exact Sony MSM8x60 code starts the 45 nm DSI PLL by changing
`DSIPHY_PLL_CTRL_0` from programmed value `0x40` to `0x41`. The project driver
had omitted that separate enable operation. Kernel commit `825085ffdeb71af3`
implements the transition and a build guard enforces it. This is the first
source-exact explanation consistent with backlight plus initialized DRM but
zero VSYNC. It is implemented and locally testable, but display output remains
`NOT_VERIFIED` until a later owner-approved physical boot.

The latest physical successor did not reach that PLL check: its fabricated
MSM8960-style `mdp_lut_clk` gate stayed off and MDP4 rejected the clock enable
before reading its revision. Exact Sony MSM8x60 clock source has no separate
LUT gate. Kernel commit `b776ddafcde9` now aliases the LUT clock binding ID to
the real MDP core clock. The corrected ELF passes all local gates, but display
scanout and fbcon remain `NOT_VERIFIED` pending a physical run.

## Current display boundary: sticky command-DMA trigger

The exact working KXP/TWRP tree and a live TWRP register dump show that the
subsequent timeout classifier was wrong: working Hikari leaves DSI
`TRIG_DMA` equal to `1`, while the local fallback required it to clear. The
legacy host logs a missing 200 ms completion but always continues with the
command length. The current patch stack now does so only for MSM8x60 and only
when the command engine is idle with no FIFO, ACK, timeout, contention, or
lane-0 PHY error. The long MDV22 ID00/ID01 command sequence is independently
confirmed correct. A read-only check of the currently running vendor kernel
also records 12 physical `MIPI_DSI` interrupts and the expected four-lane
418037760-bit/s configuration. This correction is `IMPLEMENTING`, not
`VERIFIED`, until a later explicitly authorized boot produces stable visible
pixels.

## Display accepted on physical Hikari (2026-09-10)

The paragraphs above retain the chronological failure history. They are
superseded by physical artifact 0066 for current display status.

Readback from both MDP IOMMU context banks proved that the hardware never
enabled those translations. Earlier DRM runs therefore programmed IOVA
`0x5000`, which MDP interpreted as a physical address, causing one
`PRIMARY_INTF_UNDERRUN` per frame and the solid-blue output. The working
Sony/TWRP configuration also has `CONFIG_MSM_IOMMU` disabled. Patch 0065 now
uses physically contiguous CMA scanout when no KMS VM exists and guards the
corresponding GEM VMA teardown path.

The corrected 0066 run placed fbdev at physical `0x7bd00000`. Live DRM state
showed connected DSI-1, active CRTC0, native 720x1280 mode and an XR24 fbcon
plane. MDP and DSI interrupt counts advanced; the complete log through at
least 867 seconds had no underrun, MDP error IRQ, Oops, BUG, unhandled fault,
or hung task. The owner visually confirmed readable terminal output and
repeating `HIKARI DISPLAY ALIVE` lines. Native panel output and fbcon are therefore
`VERIFIED` with `VERIFIED_DEVICE` evidence. Suspend/resume, brightness policy,
and accelerated GPU remain separate acceptance domains. See
[the physical scanout record](../research/device/current/boot/display-physical-scanout-success.md).

The follow-up cleanup reduces the production stack from 65 to 60
patches by retiring five MDP IOMMU experiments that have no runtime consumer in
the accepted physical-CMA design. It leaves the verified DRM/DSI/MMCC and panel
paths unchanged and explicitly disables both unused MDP IOMMU providers. The
artifact passed the complete local build/static-gate suite and a boot-only
physical test: native 720x1280 fbcon remained visible and the captured boot log
showed physical scanout with no underrun or kernel fault. It is `VERIFIED` with
`VERIFIED_DEVICE` evidence; artifact 0066 remains the rollback control. See
[the cleanup record](../research/device/current/boot/display-patch-cleanup.md).

## Debian and modular update architecture (2026-09-14)

The known-good display, USB dual-role path, charging coordination, storage,
ext4 and recovery console now form a built-in rescue boundary. A small
initramfs waits for an ext4 filesystem labelled `HIKARI_ROOT` and switches to a
minimal Debian 13 `armhf` userspace. Wi-Fi, Bluetooth, NFC, RMI4 touch and
motion sensors are built as modules with modversions; unrelated modules from
the multi-board default configuration are pruned. The canonical kernel build,
rootfs and boot artifact are each updated in place instead of creating
timestamped trees.

The kernel, DTB and initramfs pass their static gates. The packaged Sony ELF is
12,858,228 bytes, below the 20,971,520-byte p3 limit, with SHA-256
`08bceef5fd9f02ce20938906438a05e268a13070d6575cf3d36d91c86fe54750`.
The signed-release-verified Debian root tree completed with 110 package records,
no unpacked packages, 20 stripped modules exactly matching `modules.order`, and
207 MiB host disk use. A single in-tree driver-directory build was exercised
without dirtying the kernel source tree or leaving an `updates/` duplicate.
These results are `IMPLEMENTING`, not device acceptance. Debian-on-microSD,
module loading and ARM kexec remain `UNKNOWN` until the physical tests in
[TESTING.md](TESTING.md) pass. No eMMC partition or phone was written while
preparing this architecture.
