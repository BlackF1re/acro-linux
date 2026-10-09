# Power management

## Current implementation

The native charging/gauge policy is described in [CHARGING.md](CHARGING.md).
The source integration includes Scorpion CPU DVFS, shared L2 coordination,
RPM/interconnect votes and per-core SAW regulators (patches 0082/0083).
It validates speed-bin/PVS and boot clock state before taking ownership.
These safety guards must remain even when verbose register dumps are silenced.

The latest resolved build configuration enables the CPU and SAW drivers.
The connected SYSTEM at the 2026-10-04 cleanup audit exposes no cpufreq
policies. Do not claim full DVFS validation of that running image.

MSM8660 TSENS and the PM8058 board NTC use standard thermal/IIO consumers.
Their source and measurement evidence remains in [SOURCES.md](SOURCES.md)
and the hardware inventory. Protective trips/throttling need acceptance.

## Sleep and recovery

The Hikari SYSTEM suspend backend prepares the conservative
MSM8660 RPMRS sleep set before `PM_SUSPEND_MEM` collapse and uses SAW's
RPM-notified power-collapse mode. An aborted collapse restores a conservative
untimed sleep set; a completed collapse relies on RPM returning to its ACTIVE
context on wake. CPU idle remains on the standalone SAW path. Five
conservative CPU/RPM collapse cycles with RTC wake passed on 2026-10-08;
peripheral resume and deeper sleep levels still need acceptance.

The earlier production image advertised only s2idle. Prior
platform/suspend tests caused Wi-Fi/USB and display underrun regressions.
Those failures predated the RTC and screen-off acceptance recorded below.
A 2026-10-08 boot test found that the MSM8660
cpuidle callback nested context tracking already provided by cpuidle core;
using `CPU_PM_CPU_IDLE_ENTER_PARAM_RCU()` removed the physical `ct_kernel_exit`
warning while both WFI and SPC counters advanced. This validates idle entry,
not suspend/resume. MPM wake routing is implemented with partial device checks;
deep RPMRS sleep-level policy remains unimplemented. The current
`sleep.target`/`suspend.target` unit state alone is not proof of a mask or of
working resume.

Retain watchdog, pstore/ramoops and error logging. BOOT remains immutable;
experimental SYSTEM kernels reside in separate microSD directories. Prior
suspend attempts are summarized here; no experimental suspend hook is enabled
in production.

The 2026-10-08 IRQ-diagnostic SYSTEM boot reached Phosh with `cpuidle.off=1`.
Its temporary source change added `-dirty` to the kernel release; modules
installed for the release without that suffix did not autoload, leaving the
Synaptics touchscreen absent. Building and installing modules for the exact
running release restored RMI4 probing and the `Synaptics TM1964-001` input
device without reboot. Touch interaction still requires physical acceptance.
This boot does not establish that the intermittent black-screen failure or
suspend/resume is fixed.

## MSM8660 MPM port

The next source stage adapts the maintained Qualcomm MPM irqchip to MSM8660's
legacy protocol. Sony 6.2.B.1.96, commit
`ae953d9a9f149db0c3a51e2b587074d0d911b7ea`, provides the mapping and protocol in
`arch/arm/mach-msm/devices-msm8x60.c` and `mpm.c` (`VERIFIED_VENDOR_SOURCE`):

- 64 pins, with separate RPM request (`0x1049d8`) and status (`0x104df8`)
  windows; no later-generation MPM timer words;
- ENABLE, edge/level DETECT, POLARITY and write-one CLEAR banks;
- APSS IPC at `0x2082008`, bit 1; RPM resource transactions use bit 2;
- GPIO wake mapping through the existing TLMM hierarchical IRQ support;
- separate buffered wake masks, noirq arm/disarm and pending-status snapshot;
- rollback of the runtime request buffer after disarm.

This is `IMPLEMENTING`, not hardware-verified support. The shared DT node
remains disabled. A separate stage adds wake-status replay and connects MPM
to RPMRS only when PXO is OFF or VDD_DIG is at RET_HIGH/RET_LOW, matching Sony's
`msm_rpmrs_use_mpm()`. The current conservative profile does neither and keeps
its existing path. A requested deeper profile fails and rolls back if MPM
is unavailable or rejects its wake configuration.

On exit, the driver snapshots pending pins before disarming and clearing MPM.
Edge events already observed by Linux are not replayed twice. Mapped GIC
edges use its pending-state interface. GPIO edges use the still-armed generic
IRQ flow to mark the event suspended/pending; device handlers are deferred to
normal IRQ resume and software resend. Writing TLMM INTR_STATUS cannot inject
such an event because that register is write-one-to-clear. Level interrupts
remain hardware-driven, as in Sony's implementation. MPM is disarmed before
RPMRS abort rollback, including when that rollback fails.

On 2026-10-08, a separate microSD candidate enabled MPM and TLMM's
`wakeup-parent` (`VERIFIED_DEVICE`, partial acceptance). It booted to hardware
Phosh without IRQ errors. A disposable module verified GPIO88 -> MPM5
(PM8058) and GPIO127 -> MPM57 (touch), then completed five noirq arm/disarm
cycles. The requested wake masks reached message RAM, duplicate entry returned
`-EBUSY`, and the original runtime enable masks were restored. This did not
exercise CPU collapse or pending-event replay.

CPU1 offlining succeeded, but subsequent onlining failed, including with a
holding-pen-only candidate. Sony's holding pen is required to avoid consuming
stale `secondary_data`; additionally, modern ARM `ipi_teardown()` masks the
wake SGI that this platform relies on. The combined holding-pen/wake-IPI
candidate subsequently passed one initial cycle and twenty consecutive
CPU1 offline/online cycles (`VERIFIED_DEVICE`), returning `0-1` each time.
Phosh remained on GLES2; this validates hotplug recovery, not suspend current
or full-system collapse. A five-second RTC alarm fired
while awake; a subsequent `freeze` test did not restore USB. Its ramoops ends
at console suspension, without a panic trace; the failing device callback is
not yet identified. Logs and checksummed test
bundles are in separate `/boot/hikari-mpm-probe-20261008` and
`/boot/hikari-hotplug-pen-20261008` directories; the production bundle is intact.

The subsequent PM-debug candidate failed before reaching its initramfs. Its
ramoops records repeated `unexpected IRQ trap at vector 21` (hexadecimal
Linux IRQ33), a charger I2C timeout and an RCU stall. This is an early-boot IRQ
storm, not evidence of a suspend panic. The initramfs log left on SD belonged
to the preceding kernel and must not be attributed to this attempt. The
failed console is preserved in
`/boot/hikari-pmcheck-20261008/results/boot-failed-ramoops.txt`. A separate
read-only diagnostic candidate confirmed IRQ33 is TLMM's summary interrupt,
GIC hardware IRQ48. BOOT retains enabled APPS GPIO forwarding across kexec,
while the receiving driver initially has no child IRQ handlers. A receiving
kernel safeguard masks those inherited APPS forwards before registering the
GPIO IRQ controller. It preserves latched status, raw detection, modem targets
and direct-connect routing. Consumers re-enable their own IRQs normally.

The safeguard candidate
`7.3.0-rc1-hikari-system-tlmmhandoff-20261008-g6d2d103e2952` passed three
BOOT-to-kexec starts with `Err: 0`, five inherited IRQs masked each time,
Phosh on GLES2/renderD128 and the Synaptics input device present. Ten further
CPU1 offline/online cycles passed. This is device evidence for the safeguard,
not proof that every intermittent cold-boot failure or suspend failure is
resolved. Read-only diagnostics remain outside the canonical patches. Logs
and checksums are in `/boot/hikari-tlmmhandoff-20261008/results`.

Next: isolate device suspend/resume, then audit wake
constraints and deeper levels.
Both-edge wake requests are rejected on entry rather than silently dropping
one edge on this single-polarity hardware. Unmapped wake sources, dual-edge
handling and their constraints must be audited before any PXO OFF level.
PXO OFF, deeper L2/VDD states and timed-wake policy remain disabled.

Local checks on 2026-10-08 passed: exact patch-series materialization,
ARM zImage and matching modules for both MPM stages, DT binding/example and
DTB schema checks, and the existing ten repository tests. The final prepared
tree is `73d66f75d52a05a215becb9f12485343680664ed`. These are build checks;
the physical checks above cover MPM arm/disarm only. At recovery the phone is
in immutable BOOT; the production SYSTEM bundle remains unchanged.

The hotplug stage updates the prepared tree to
`8b5eb5d1b7164def40ca5df00ea13ebc20943956`. Exact series materialization and
the ten repository tests passed. The device test used kernel
`7.3.0-rc1-hikari-system-irqsource-20261008-ge7b82749665b`, with read-only IRQ
diagnostics outside the canonical patches, matching modules, `cpuidle.off=1`
and MPM enabled only in its test DTB. Logs are in
`/boot/hikari-irqsource-20261008/results/hotplug-20.log`.

The TLMM handoff stage updates the prepared tree to
`d9fbfe8b6cc17531202e8792dd058c5cb40ba6cf`; exact materialization and all ten
repository tests passed. BOOT and the production SYSTEM bundle remain intact.

The handoff safeguard also handles unmapped PM8xxx interrupt sources. A
2026-10-08 diagnostic boot stalled in PM8058 parent-IRQ registration before
child IRQ mappings existed. The candidate masked and acknowledged unmapped
IRQ75 (keypad-stuck), then booted with `Err: 0` and hardware Phosh
(`VERIFIED_DEVICE`). Mapped sources retain their ordinary IRQ handling.
Exact materialization passes with prepared tree
`9978f3ab02f5cbb73a7f2193848c5a71ebc6f39b`.

Device-only suspend testing (`pm_test=devices`, `freeze`) returned successfully;
USB re-enumeration required restoring the host NCM link. Wi-Fi resume logged
an HTAvail timeout and remains unresolved. The subsequent `pm_test=platform`
passed all noirq callbacks but stopped during Adreno runtime resume: rail
enable completed, then `enable_clk()` did not return. Ramoops contains no
panic trace. GPU hardware re-init and CPU/RPM collapse were not reached.
Clock-call diagnostics remain outside the canonical patches. Logs are in
`/boot/hikari-pmichandoff-20261008/results/pm-platform` and
`/boot/hikari-tlmmhandoff-20261008/results/pm-devices`. This is an unresolved
resume failure, not verified suspend support.

Further read-only traces narrowed this failure to `gfx3d_clk` enable: OPP
rate setting and preparation of all four GPU clocks completed. Sony's
`clock-8x60.c` makes GFX3D depend on `gmem_axi_clk`. Enabling the A220 core last
removed the hard clock hang, but the first physical candidate still failed
GPU hardware re-init with `-EINVAL` and produced a blue display, underruns and
flip timeouts. A returned PM-test shell command was insufficient evidence.

The GPU resume stage also follows Sony's `footswitch-8x60.c`: synchronous
GFX3D resets run with memory, bus, interface and core clocks enabled; an extra
core reset follows unclamping; GFX3D_CC bit 31 retains core memory while
clock-gated. Power-off clears retention and asserts resets before gating and
clamping. Clock preparation occurs at probe, outside noirq callbacks.

The separate `hikari-fsresume-20261008` candidate combines this GPU stage with
MDP4 fetch/IRQ restoration before modeset. It passed three device/noirq
`pm_test=platform` freeze cycles, GPU re-init returned zero, and the owner
confirmed normal image and touchscreen (`VERIFIED_DEVICE`, partial PM
acceptance). Eight independent S1c24/S1x32 processes produced 448 NEAR and
zero SEVERE; the S3 texture-varying probe passed 16/16 draws. Phosh retained
GLES2/FD220 with all mapped Mesa DSOs in `/opt/hikari-mesa-a220`.

Each display restart can still report one primary underrun; there were no
persistent underruns or flip timeouts on this candidate. Wi-Fi HTAvail and
MPU3050 runtime-PM errors remain separate unresolved issues. These tests used
`cpuidle.off=1`: they did not exercise CPU/RPM collapse or validate suspend
current. The diagnostic kernel contains temporary traces not exported into
the canonical patches; the trace-free acceptance below checks that result.

Evidence and checksums are saved in `/boot/hikari-fsresume-20261008/results`
and the corresponding host build directory. Tested release:
`7.3.0-rc1-hikari-system-fsresume-20261008-g1cf9ba7e425c`; zImage SHA256:
`1777e55652e4fb9652054ed04c23f74d7fa02cd18d72cf8054d42e33dd16aee3`.
The GPU stage prepared tree is
`262603834608deed07d0d44d057c473d360b083e`.
BOOT and the production SYSTEM bundle remain unchanged.

The display resume stage restores MDP4's base fetch/CSC/port configuration
and its saved IRQ mask before `drm_mode_config_helper_resume()`. Atomic
plane state alone did not restore those registers after domain collapse.
It runs only after the noirq suspend stage was reached and does not
reinstall IRQ handlers. The combined prepared tree is `da80374e82c2a3ff72dcf1ac86bad9fd082b5f2e`.

The canonical, trace-free series was materialized and built locally, then
booted through immutable BOOT on 2026-10-08 (`VERIFIED_DEVICE`, device/noirq
resume only). Release:
`7.3.0-rc1-hikari-system-resume-clean-20261008-g3fe898c012ff`; zImage SHA256:
`ea4e33fea63d76765282ddaebb360bb267b1b920a4adb00a8b6cac0576cbbead`.
Three further `pm_test=platform` freeze cycles passed. Four independent
transition processes gave 224 NEAR / zero SEVERE; S0 passed 4/4 and S3 passed
16/16. Hardware Phosh remained active, its screenshot was clean, and IRQ
errors were zero. Mesa maps and the complete staged environment were saved.
The six cycles across both candidates cover device/noirq resume, not actual
CPU/RPM sleep: `cpuidle.off=1` remains on the test command line.

A single primary underrun remains at each display restart, without persistent
blue scanout, flip timeouts or GPU/MMU faults. Do not classify the entire
suspend stack as verified from these results. Logs, runtime maps, screenshots
and checksums are in `/boot/hikari-resume-clean-20261008/results/acceptance`
and the corresponding host build directory. The phone remains in this test
SYSTEM with Phosh GLES2 and `pm_test=none`; immutable BOOT and the production
`hikari-next` kernel are unchanged.

System sleep registration is now independent of `cpuidle.off=1`. Both SAWs
and SCM warm-boot routing are still required. Automatic SPC can remain
disabled while `mem_sleep=deep` is tested explicitly. Dynamic debug reports
RPMRS ACK/error, clock entry and actual collapse versus aborted WFI.
This stage built locally and enabled the explicit deep-sleep tests below.

Actual s2idle returned with working USB/Phosh, but its first wake IRQ was
59 (headset detection), not RTC. A second run temporarily disabled wake on
`gpio-keys`; it woke on PM8058 summary IRQ36 before the RTC deadline, again
without an alarm IRQ. An awake alarm test incremented the RTC IRQ counter.
These are successful resume tests, not proof of RTC wake from sleep.

Source audit found that PM8xxx declares `IRQCHIP_MASK_ON_SUSPEND` but only
provides `irq_mask_ack`; generic `mask_irq()` does not call that operation.
Sony `drivers/mfd/pm8xxx-irq.c` provides both mask and mask_ack. The new stage
adds the non-clearing mask callback for PM8058/PM8921, allowing non-wake
sources to be masked before noirq without discarding latched events.
Physical RTC-wake acceptance is recorded below.

The PM8xxx-mask candidate booted with `cpuidle.off=1` and advertised both
s2idle and deep sleep. An isolated 15-second RTC s2idle test completed with
exit zero, the alarm IRQ counter increased from zero to one, and Phosh/USB
returned (`VERIFIED_DEVICE`). GPIO-key wake was temporarily disabled for
the test and restored afterward. BMA180 resume logged `-EACCES`; its recovery
remains unresolved.

The first explicit deep-sleep attempt returned safely but did not collapse:
RPMRS entry, clock transition and CPU PM entry returned zero; `cpu_suspend`
reported `collapsed=0, ret=-1`, and rollback succeeded. The wake IRQ was 25,
`qcom_rpm_ack`. Sony's noirq RPM path clears the GIC pending ACK after
consuming message RAM; the port had left that edge pending. This is an
aborted-WFI result, not successful deep sleep. Logs are saved in
`/boot/hikari-rpm-suspend-20261008/results/rtc-{freeze,mem}`; kernel SHA256
`85fc2676f3ab98477e67ed52ed7689f5b9e2e8362495aaffe382cb0be5492ab8`.

The RPM ACK stage reproduces Sony's polling order using the generic IRQ-chip
state API. It waits for the edge as well as message RAM, then flushes the
ACK clear and retires only that consumed pending ACK before unmasking. Normal
interrupt-driven RPM writes are unchanged.

The separate `hikari-rpm-ack-20261008` candidate passed five actual
`mem_sleep=deep`, `pm_test=none` cycles with 15-second RTC alarms
(`VERIFIED_DEVICE`, conservative CPU/RPM collapse). Each cycle reported
`collapsed=1`, successful RPMRS entry/exit and an increased RTC IRQ counter.
CPU1 returned online. Four fresh post-resume transition processes produced
224 NEAR / zero SEVERE; S3 passed 16/16. Phosh retained GLES2/FD220 and its
matching Mesa paths; the owner confirmed working display and touchscreen.

GPIO-key wake was disabled only during the isolated RTC tests and restored
after each test. Automatic cpuidle was disabled; default mem sleep remains
s2idle. This does not validate headset/button wake, MPM pending replay,
PXO OFF, lower VDD/L2 levels or suspend current. BMA250 (bma180 driver)
intermittently fails resume with `-EACCES`, MPU3050 reports a runtime-PM
usage underflow, and Wi-Fi reports HTAvail timeouts. A single primary MDP
underrun can appear at display restart without persistent blue scanout.
These peripheral failures prevent full-system suspend acceptance.

Test release: `7.3.0-rc1-hikari-system-rpm-ack-20261008-gf76ca33a071e`;
zImage SHA256:
`f5508abfbadc2eb0651e3f0fbffbc28c1cef54d2d704af59fe5bf23bb1b2733e`.
Prepared tree: `e6d6234a42e98cc830b663dfd8922adf40849074`.
Logs, interrupt counters, ordered readback hashes, runtime maps and a
screenshot are saved in `/boot/hikari-rpm-ack-20261008/results` and the
corresponding host build directory. The phone remains in this test SYSTEM;
immutable BOOT and the production SYSTEM bundle remain unchanged.


The MPU3050 auxiliary-bus stage fixes a specific asynchronous-PM dependency.
I2C adapter 3 is parented to upstream adapter 2, so the BMA250 could resume
while its MPU3050 gate still had runtime PM disabled. The gate select then
returned `-EACCES`. Mux core always calls deselect, even after select fails;
that path incorrectly dropped an unacquired runtime reference. A stateless
PM device link orders the auxiliary adapter after the MPU3050, and deselect
now releases only a successful select's reference.

A separately loaded matching module passed three further actual RTC/deep
collapse cycles: accelerometer and gyro raw reads succeeded after every
wake, no new sensor resume error or usage underflow occurred, and the MPU3050
usage count returned to zero. This verifies reads and PM ordering, not motion
calibration or trigger-buffer acceptance. The resulting source series passed fresh-boot acceptance below. Logs and module hashes are in
`/boot/hikari-rpm-ack-20261008/results/sensor-pm`.


Fresh-boot acceptance of `hikari-sensor-pm-20261008` passed three additional
actual RTC/deep cycles (`VERIFIED_DEVICE`). Each reported `collapsed=1`,
advanced the RTC alarm IRQ, returned both CPUs online and restored sensor
raw reads with zero new sensor resume errors or PM underflows. Three fresh
GPU transition processes gave 168 NEAR / zero SEVERE; S0 passed 4/4 and S3
passed 16/16. Hardware Phosh remained active with the correct Mesa paths,
and its captured frame was clean. The initial trigger registered normally.

Wi-Fi delivered three of three ICMP replies after these cycles despite a
resume HTAvail warning. That warning and broader wireless endurance still
need investigation; it is not evidence of a completely unavailable radio.
GPIO-key wake was restored, the RTC alarm cleared, dynamic debug disabled,
`pm_test=none` and default sleep s2idle retained. Automatic deep sleep remains
disabled pending other wake-source and power-current acceptance.

Release: `7.3.0-rc1-hikari-system-sensor-pm-20261008-g6b3311f9f240`;
zImage SHA256:
`d818af7b9e15e9c8e08ab3e12a6af2887002cff6a2165a2631912dde51eaedc3`.
Prepared tree: `cfc10da67160657fe27eae04066ecafefd8ded62`.
Complete per-cycle logs, interrupt counters, readbacks, maps and screenshot:
`/boot/hikari-sensor-pm-20261008/results/acceptance`, mirrored on the host.
This test SYSTEM remains running. Immutable BOOT and the production
`hikari-next` bundle are unchanged.

### Screen-off to deep sleep acceptance (2026-10-09)

`VERIFIED_VENDOR_SOURCE`: Sony 6.2.B.1.96, commit
`ae953d9a9f149db0c3a51e2b587074d0d911b7ea`, keeps PM8058 L0 enabled
at 1.2 V (`vreg-fuji_hikari_row.c`). L0 supplies both DSI and Timpani.
Turning it off with the panel produced a false GPIO61 headset wake.
An L0-only hold/release A/B/A restored/eliminated that wake; S4 alone did
not help. The Hikari DTS now keeps L0 always on, matching Sony.

`VERIFIED_DEVICE`: four L0-only DT cycles and three final-kernel cycles
slept until their RTC alarm with all GPIO-key wake sources enabled. Panel
DCS sleep-in (0x10, 80 ms) now runs in `.disable`, before stopping the video
source; the previous command-DMA timeout no longer occurs.

Phosh 0.46 itself only blanks on short power-key release and inhibits
logind's key handler. `hikari-screen-sleep` bridges its ScreenSaver
ActiveChanged signal to ordinary logind Suspend after a two-second debounce;
it checks the screen is still blank, respects logind inhibitors and suppresses
requests during suspend/resume. It also covers automatic screen blanking.
The user-session helper requires python3-dbus/python3-gi; it has no polling.
The sleep policy selects `mem`/`deep`.

A physical power-key cycle reported `PM: suspend entry (deep)`,
`collapsed=1`, successful RPMRS entry/exit, and increased power-key IRQs
without any RTC IRQ increase. The owner confirmed restored screen and touch.
Post-RTC GPU regression: S0 4/4 EXACT, two independent transition processes
112 NEAR / zero SEVERE, S3 16/16; hardware Phosh remained active.

Test bundle: `/boot/hikari-sleep-final-20261009`, zImage SHA256
`9cc293de1b82c7f54c25e15dd3a5b1b14f535d5ce03868f5567a286449ce0d58`;
prepared tree `b06b7bd1396866954f5869f31c1c562a409e2e6e`.
Logs are in its `results` directory and mirrored in the host build directory.
Button integration is currently staged in `/run`; BOOT and `hikari-next`
are unchanged. Wi-Fi was blocked for this acceptance. A single MDP primary
underrun still occurs on resume; complete peripheral/wake-source acceptance,
deepest Sony levels and suspend-current measurement remain outstanding.

### Sony/Fuji deep-level acceptance (2026-10-09)

`VERIFIED_VENDOR_SOURCE`: Sony 6.2.B.1.96 Fuji's eight RPMRS levels now
feed selection by sleep votes, latency QoS, RTC deadline and MPM wake
coverage. Normal/active-only PXO clocks aggregate separate sleep votes;
PMIC GPIO wake routes are checked through their parent interrupt domains.
MSM8660 TSENS is powered down in suspend, matching Sony, without a wake vote.

`VERIFIED_DEVICE`: bundle `/boot/hikari-levels5-20261009` completed four
level-7 collapses (PXO OFF, L2 HSFS_OPEN, MEM/DIG sleep votes 750/500 mV),
including Phosh screen-blank-triggered sleep. A 5000-us latency constraint
selected level 5 and also resumed successfully. All five had `collapsed=1`,
RPMRS entry/exit success and no kernel warning, GPU fault or MDP underrun.
After resume, 256x256 GPU tests gave S0 4/4 PASS, three independent
S1c24→S1_32 processes 168 NEAR/0 SEVERE, and S3 16/16 PASS.
Hardware Phosh and the persistent screen-sleep helper remained running.

Kernel SHA256: `d44dfde0ed7ff317393e385308cf5f143b9bf76521caea857f9025a64798d60d`.
Prepared tree: `f469600d8e3ca5e454b9eb63a5cd7513eb9fc6e2`.
Logs are in the bundle's `results/` directory. BOOT and `hikari-next`
remain untouched. Wi-Fi was blocked; all-peripheral wake coverage, every
individual level and minimum suspend current are not yet verified.

The preceding overnight discharge was not deep sleep: after the 21:24
power-key events there were no suspend entries. The helper had only been
staged in volatile storage and disappeared on reboot. It and its autostart
entry are now installed on the existing rootfs, with the mem/deep policy.
Battery percentages alone do not establish minimum sleep power.
