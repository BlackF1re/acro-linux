# Local-only Hikari kernel build

This is an offline development procedure. The scripts have no `adb`,
`fastboot`, USB, flash, reboot, restore, or phone-writing operation. Sources
and generated output remain outside this Git repository.

## Pinned inputs

- Canonical Linux source tree: `/home/paul/xperia/src/linux`.  Its exact HEAD
  is recorded with each artifact; it contains the pinned Linus base plus the
  documented, authorship-preserving MSM8x60 and Hikari bring-up commits.
- BusyBox source tree: `/home/paul/xperia/src/busybox`, commit
  `74ac096e895acd6b02976bb010e9b3511234e899`.
- Canonical active kernel output: `/home/paul/xperia/build/linux-hikari-current`.
- Canonical active initramfs output:
  `/home/paul/xperia/build/hikari-initramfs-current`.
- Canonical active artifact output:
  `/home/paul/xperia/build/hikari-artifacts-current`.
- Private RPM input: the confirmed p3 RPM segment outside the repository.

The Hikari DTS is copied into the external Linux worktree by
`scripts/prepare-hikari-kernel-tree.sh`.  Kernel sources and generated output
remain outside this repository, while project-owned DTS/config/build inputs
remain reviewable here.

Historical `linux-hikari-boot*`, `hikari-artifacts-g*`, and similarly named
directories are immutable experiment records.  They are not alternative
active source trees and must not be selected by default.  New work uses the
three `*-current` locations above, preventing silent builds against a stale
worktree while preserving the exact files used in previous physical tests.

## Reproducible host commands

```sh
./scripts/build-hikari-elf.sh
./scripts/test-sony-elf.sh
./scripts/test-hikari-firstboot-artifact.sh
```

`build-hikari-elf.sh` is the canonical end-to-end entry point.  On a fresh
output directory it first builds the host `gen_init_cpio` helper, then builds
the native static BusyBox diagnostic initramfs, rebuilds the kernel with that
initramfs, appends the Hikari DTB, and constructs a local Sony ELF32 with the
three segment classes observed in p3.  It refuses to overwrite output and
rejects output outside `/home/paul/xperia/build/`. The private RPM binary,
kernel outputs and ELF prototype are never added to Git.

## Validation results at this revision

- `make ... zImage qcom/qcom-msm8260-sony-hikari.dtb`: passed.
- `make ... dtbs`: passed; no DTC warning was emitted for the Hikari DTS.
- Targeted `make O=/home/paul/xperia/build/linux-hikari-current CHECK_DTBS=y
  qcom/qcom-msm8260-sony-hikari.dtb`: passed without a schema warning. The
  missing MSM8660 MMSS SFPB schema, DSI PHY name, controller fallback and
  register-name issues found by this check were fixed rather than suppressed.
- Direct `dt-doc-validate` of the project-added bindings and targeted
  `dt-validate` of the final Hikari DTB also passed. `dtschema` 2026.6 is
  installed in an isolated `pipx` environment, not global Python.
- The ELF self-test and artifact validator passed. The latter checks the
  original offline p3 hash and size, p3 capacity, appended-DTB tail, ELF32
  header, segment ranges and load-address overlap.
- Exact hashes and ranges of the current local artifact are recorded below and
  must be checked again before any owner-approved deployment.

This establishes local build integrity only. It is neither a boot test nor
authorization to deploy any artifact. The current deployment gate is in
[FIRST_BOOT_PLAN.md](FIRST_BOOT_PLAN.md).

## Corrected third local build

Following post-mortem analysis, the third local build uses the physical MSM8x60
low-memory base `0x40000000`, reserves its first 2 MiB through
`CONFIG_ARCH_QCOM_RESERVE_SMEM=y`, and uses the resulting upstream
`0x40208000` zImage load candidate.  The current initramfs is deliberately
placed at `0x42c10000`: the larger current kernel relocates through
`0x42c03d39`, so the former `0x42a00000` address is no longer safe.  The exact
artifact and code-derived range checks are recorded in
[THIRD_BOOT_PLAN.md](THIRD_BOOT_PLAN.md) and
[FIRST_BOOT_MEMORY.md](FIRST_BOOT_MEMORY.md).  Deployment remains a separate,
owner-approved operation.

## Earlier secure-MMCC artifact

The locally validated artifact at that earlier checkpoint was:

```text
/home/paul/xperia/build/hikari-artifacts-current/hikari-current.elf
size:   13,357,633 bytes
SHA-256 a85034101356d98efe79067dc419320adba73510b9613a8db132d9c5808e4648
```

It was built from signed external kernel tree HEAD
`9d823ead2c7bedb424dff16f547c2c1cdce910d7`. It preserves the verified
memory, RPM, ramoops, stable PID 1, and USB ACM shell foundation. The
source-derived firmware-state reset now runs exactly once during DSI probe,
with a tracked common-clock-framework reference held across the operation.
The three MSM8x60 DSI AHB clocks remain referenced for this early bring-up
artifact, so ordinary runtime suspend/resume cannot repeat the destructive
reset or enter the physically failing branch-disable path. Driver removal and
probe unwind release the reference. This deliberately trades display-block
idle power for deterministic bring-up; it is not the final runtime-PM policy.
Display and useful positive-current charging remain unverified until physical
acceptance tests pass. In addition to the `MDP_GDSC` relationship it now
reproduces the exact Sony/C.A.F. eight-clock MDP footswitch initialization.
MDP4 refuses MMIO if clock preparation fails and probes MDP4/DSI asynchronously
as a USB-console fail-safe. Physical g33 evidence then showed the secure-MMCC
driver deferred before probe because the DT contained no SCM platform device;
the early architecture convention message was insufficient. This artifact
adds `qcom,scm-msm8660` with the required RPM Daytona core clock. It is a narrow
correction for the observed supplier boundary, not a display acceptance claim.
The initramfs also installs three read-only reports for general hardware,
display, and power/charging diagnosis. It retains the same BusyBox binary and
408-applet set.

Its components are:

```text
zImage:     12,108,208 bytes, 40599ab4391be985ec9b9cd891920402df49c3a99cc8b8f02684c262086a42b7
zImage+DTB: 12,128,762 bytes, e0859c50013bea576fdc945b8492d1b05f642c172f7bfe6dd7c3a138625d8aec
DTB:            20,554 bytes
DTB SHA-256: 20afcc7bd765a8cdd7197572fffd3ba22314e40b12dee89e23da3f4afcd6b68a
initramfs:  1,104,991 bytes, 075ec51ce74d873c5673dd1ff0475fbe855f951fb42bd720d5035d382f494c5b
```

The Sony ELF loads segment 0 at `0x40208000`, segment 1 at `0x42c10000`, and
the private RPM segment at `0x00020000`. All decompressor, appended-DTB,
initramfs, RPM, SMEM and ramoops range gates pass. Passing these checks is
local artifact integrity, not permission to flash or a hardware claim.

The final Sony ELF segment table is:

```text
segment 0: offset 0x001000, paddr 0x40208000, size 0xb911fa
segment 1: offset 0xb921fa, paddr 0x42c10000, size 0x10dc5f
segment 2: offset 0xc9fe59, paddr 0x00020000, size 0x01d3e8
```

## Physically accepted display artifact 0066 (2026-09-10)

The final no-IOMMU scanout artifact is retained at:

```text
/home/paul/xperia/build/hikari-artifacts-direct-scanout-0066-20260910/display/hikari-display-fastboot.elf
size:   13,382,459 bytes
SHA-256 561917ad4a123b0aa9a65c2d8b00111a5171c480e9b06d5b0395940c1e67f321
```

Inputs:

```text
zImage: 12,126,808 bytes, de5d9f37fcfa732c1d5812ea8c181719f7f6535042d3c130162b81864a7d1d32
DTB:        21,871 bytes, f4ca61e33eb20761e4b4119c98dc477da57d015fa0a1fd277fe4c4abfa7caa2c
```

The package memory-layout validator, Sony ELF validator, display static gate,
and materialized-source gate passed. The updated patch also applied cleanly to
a detached pre-0065 worktree. S1Boot flashed only `boot` partID `0x00000003`.
The physical device then produced readable native 720x1280 fbcon, advancing
MDP/DSI interrupts, and no underrun or kernel fault. This is a physical display
acceptance result, not merely a successful build; the detailed evidence is in
[display-physical-scanout-success.md](../research/device/current/boot/display-physical-scanout-success.md).

## Verified display patch cleanup 0060 (2026-09-11)

Five superseded MDP-IOMMU experiments were retired from the production series
after physical 0066 proved that Hikari requires contiguous CMA scanout and does
not use either MDP IOMMU provider. The DRM/MSM, panel and MMCC execution paths
are unchanged; both unused IOMMU provider nodes are now explicitly disabled.

The clean 60-patch tree materialized and built successfully with the exact
accepted 0066 kernel configuration. Display, MMCC, USB recovery, ramoops,
kernel-source, safe-profile, GPU-profile, charging, board-hardware, memory-map
and Sony ELF gates passed. The boot-only candidate is:

```text
/home/paul/xperia/build/hikari-artifacts-display-cleanup-0060-20260911/display/hikari-display-fastboot.elf
size:    13,382,219 bytes
SHA-256: 0f08c2f67b6e210c0f45ebe9c228d5fff6e1e48bafe8313066be814764b015bf
```

The image was flashed only to `boot` and physically passed native 720x1280
fbcon acceptance. MDP4 used physical scanout at `0x7bd00000`, the panel command
sequence completed, the initramfs wrote its display witness, and the captured
log contained no display underrun or kernel fault. The owner visually confirmed
working output. This artifact is `VERIFIED`; accepted 0066 remains the rollback
control. See
[display-patch-cleanup.md](../research/device/current/boot/display-patch-cleanup.md).

## Earlier MDP multi-provider display artifact

The latest physical post-mortem reached secure MMCC setup, MMFAB unhalt, the
MDP footswitch, and the first MDP IOMMU provider before an Oops in
`qcom_iommu_of_xlate()`. Signed kernel commit
`fb48685d80a0bfb4b55b67afc5ec1463d2833d0f` replaces the driver's invalid
single-client-pointer model with one matching client master per IOMMU
provider. This historical correction is archived with the other retired
IOMMU experiments; it has no production consumer after MDP was detached.

The historical, physically tested successor artifact was:

```text
/home/paul/xperia/build/hikari-artifacts-20260906T020500Z/display/hikari-display-fastboot.elf
size:   13,382,214 bytes
SHA-256 2922e71f51365ca75e6274544d25e281dc997bebcc6957e22598e0250a44182e
entry:  0x40208000
```

It was built from project artifact commit
`12f21b39fe84dd460f86c4c8909f7ff9317b232d` and signed external kernel commit
`fb48685d80a0bfb4b55b67afc5ec1463d2833d0f`. Its components are:

```text
zImage:     12,126,696 bytes, f1aa56e3722cf4df438a811959bf5eb2552e0a9ee799edf4d1d581d89d1b2bc1
zImage+DTB: 12,148,434 bytes, 83f9a9502fb1eb50758f4d473292cc5c0c22f4c3b91632bb795ad0c98cfc2df4
DTB:            21,738 bytes, ed42cb9341d65cc0b4a086df73bf1fc836365362b201e40212c4755a7e0bfdc0
initramfs:   1,109,900 bytes, 3228c3a81460b406ba0dba2d55f8c1e2ab83a011cd9d4ca8f200e01f4543d279
```

Sony ELF segments:

```text
segment 0: offset 0x001000, paddr 0x40208000, size 0xb95ed2
segment 1: offset 0xb96ed2, paddr 0x42c10000, size 0x10ef8c
segment 2: offset 0xca5e5e, paddr 0x00020000, size 0x01d3e8
```

The target IOMMU object and full kernel built successfully. Kernel source,
display source, display DT, focused binding, Sony ELF, appended-DTB, SMEM,
ramoops, initramfs, USB regression, charging, board-hardware, partition-size,
and ARM decompressor relocation/overlap gates pass. The final Hikari DTB
retains both MDP providers and exact Sony non-secure MIDs 0 and 2 on each. Its
physical run passed the corrected translation path, initialized DSI V2, bound
MDP4 to DSI, and read MDP4 version v4.1 before revealing the separate
page-table DMA recursion documented below.

## Current MDP-IOMMU page-table-ownership artifact

The preceding physical artifact passed both Hikari MDP IOMMU providers,
selected the MSM8x60 DSI V2 host, bound MDP4 to DSI, and read MDP4 version
v4.1. It then crashed while ARM32 detached its automatic DMA domain before
DRM attached the display domain. The legacy IOMMU driver incorrectly used the
MDP client as `io_pgtable_cfg.iommu_dev`; freeing ARMv7s page tables therefore
recursed through that same client's IOMMU-backed DMA-unmap path.

Signed kernel commit `96651e282822a6b587b43dc3c4767a1f27581933`
assigns page-table DMA ownership to an actual IOMMU provider, retains the
provider for the domain lifetime, and fixes multi-provider context attach,
detach, unwind and TLB handling. This historical patch is archived for
research and is no longer enforced by production source gates.

The new locally validated, **not deployed** display artifact is:

```text
/home/paul/xperia/build/hikari-artifacts-iommu-fix-20260906/display/hikari-display-fastboot.elf
size:   13,381,798 bytes
SHA-256 47a34d7c1b2ccf0cebf1a36ad06182a360fbd15423e18898c90d42db1782f4aa
entry:  0x40208000
```

It was built from project artifact commit
`f519c40a936401c680bfbbd59d7107ffeba39847` and signed external kernel commit
`96651e282822a6b587b43dc3c4767a1f27581933`. Its components are:

```text
zImage:     12,126,280 bytes, 1516a1974486c85c9dd01067855a955e5f758c9e4ef7d9148fb90bcf5a0d4968
zImage+DTB: 12,148,018 bytes, 9c2e944ba7d43247bf44bdfc0af0245de786e5470ef69f0b1018709b5326faab
DTB:            21,738 bytes, ed42cb9341d65cc0b4a086df73bf1fc836365362b201e40212c4755a7e0bfdc0
initramfs:   1,109,900 bytes, 3228c3a81460b406ba0dba2d55f8c1e2ab83a011cd9d4ca8f200e01f4543d279
```

Sony ELF segments:

```text
segment 0: offset 0x001000, paddr 0x40208000, size 0xb95d32
segment 1: offset 0xb96d32, paddr 0x42c10000, size 0x10ef8c
segment 2: offset 0xca5cbe, paddr 0x00020000, size 0x01d3e8
```

The complete clean kernel/bundle build and independent artifact rerun passed.
The verified memory model still uses SMEM at
`0x40000000-0x401fffff`, kernel load `0x40208000`, initramfs
`0x42c10000`, and ramoops `0x7ffe0000+0x20000`. Physical display acceptance
remains separate and owner-approved. The post-mortem is documented in
[display-mdp-iommu-pgtable-dma-oops.md](../research/device/current/boot/display-mdp-iommu-pgtable-dma-oops.md).

## Hikari rounded pixel-clock artifact

The live predecessor reached an active 720x1280 DRM CRTC, `msmdrmfb`, bound
fbcon, and visible AS3676 backlight illumination, but produced no pixels or
MDP/DSI interrupts. Its clock tree proved that the 69,673,000 Hz request made
from DRM's integer-kHz mode skipped the MMCC table row labelled 69,672,960 Hz
and selected 76.8 MHz. Signed kernel commit
`7da01ebc48fea5db687cb64dedbe5e2f7a4df312` retains the source-derived
`567/3125` PLL8 divider while labelling the row with the rounded request.

The locally validated, **not deployed** successor is:

```text
/home/paul/xperia/build/hikari-artifacts-pixelclock-20260906/display/hikari-display-fastboot.elf
size:   13,380,894 bytes
SHA-256 2dd8da13418ecbea5156b361e1622c18f7a55056225c90de62a829792258aa03
entry:  0x40208000
```

It was built from project commit
`15fdbc43a3bdac175a446a813be785449726d6ab` and the signed kernel commit above.
Its components are:

```text
zImage:     12,125,376 bytes, d8a0a0a2163439b7e440d73d2d1df0131ba2a4d8dd14513797d389c66f87f344
DTB:            21,738 bytes, 6984d204fb57a6a5c07df9dd190d99798ca91f21cb77a45f73d860a600cb2b01
zImage+DTB: 12,147,114 bytes, 06477a45f7e00df89112516db14fd70e6179b34f79897b338624d087538c7327
initramfs:   1,109,900 bytes, 3228c3a81460b406ba0dba2d55f8c1e2ab83a011cd9d4ca8f200e01f4543d279
```

Sony ELF segments:

```text
segment 0: offset 0x001000, paddr 0x40208000, size 0xb959aa
segment 1: offset 0xb969aa, paddr 0x42c10000, size 0x10ef8c
segment 2: offset 0xca5936, paddr 0x00020000, size 0x01d3e8
```

The kernel, three DTBs, initramfs, source guards, display, charging,
board-hardware, USB-regression, safe-profile, GPU-profile, Sony ELF,
appended-DTB, p3-size, SMEM, ramoops and decompressor-overlap gates pass.
Direct validation against the complete DT schema also finishes successfully
but reports existing non-display warnings for five pinctrl child-node names
and the disabled A220 compatible; they are not introduced by this narrow
pixel-clock correction. Visible pixels, advancing VSYNC interrupts and fbcon
remain a physical acceptance test rather than a build claim.

## Hikari DSI-PLL-start artifact

Exact Sony MSM8x60 code starts the programmed 45 nm DSI PLL by setting bit 0
of `DSIPHY_PLL_CTRL_0`; the predecessor left the register at disabled value
`0x40`. Signed kernel commit `825085ffdeb71af31431455927df68561406d86e`
implements the source-backed `0x40 -> 0x41` transition and logs its readback.
The compiled object was disassembled and contains the final immediate `0x41`
MMIO store. The locally validated, **not deployed** successor is:

```text
/home/paul/xperia/build/hikari-artifacts-dsi-pll-20260907/display/hikari-display-fastboot.elf
size:   13,382,122 bytes
SHA-256 a9bc6ff21e6311a0a26330e82b1626c6cb88d88de8682f44475f65f1eca74aa1
entry:  0x40208000
```

It was built from project commit
`05a05c2686d516000721b896c0a1c6b0b1ef974f` and the signed kernel commit
above. Its components are:

```text
zImage:     12,126,592 bytes, 705e286ef0560dd9cae5ea5f9bf2e538b6964ff6ae70bc585a124d90c098cd74
DTB:            21,750 bytes, ffdcc2fd3412b4a82fa22d783e9596d1ec007ceeb473204f24f086576ce4954d
zImage+DTB: 12,148,342 bytes, 035069410902f6a4881474f2d8e759e95c0bdd2d61001e780d2240baedfa7342
initramfs:   1,109,900 bytes, 3228c3a81460b406ba0dba2d55f8c1e2ab83a011cd9d4ca8f200e01f4543d279
```

Sony ELF segments:

```text
segment 0: offset 0x001000, paddr 0x40208000, size 0xb95e76
segment 1: offset 0xb96e76, paddr 0x42c10000, size 0x10ef8c
segment 2: offset 0xca5e02, paddr 0x00020000, size 0x01d3e8
```

Kernel and all three DTBs built. The kernel-source, display, charging,
board-hardware, USB-regression, safe-profile, GPU-profile, persistent-RAM,
Sony-ELF, appended-DTB, p3-size, SMEM and decompressor-overlap gates pass.
Visible pixels and advancing VSYNC remain a physical acceptance test.

## Hikari MDP-LUT-clock successor

The DSI-PLL physical run exposed an earlier MDP4 clock failure. Exact Sony
MSM8x60 source has no independently controlled MDP LUT clock, so signed
kernel commit `b776ddafcde9eba1f5c81b34f54c533605c880ca` aliases the common
driver's LUT clock ID to the real MDP core clock. The locally validated,
**not deployed** display successor is:

```text
/home/paul/xperia/build/hikari-artifacts-mdp-lut-fix-20260907/display/hikari-display-fastboot.elf
size:   13,382,386 bytes
SHA-256 bca5f0844c90c964116eb5119a0c095aaa97ac0cf63b09b78ebba9d6e9ab4150
entry:  0x40208000

segment 0: offset 0x001000, paddr 0x40208000, size 0xb95f7e
segment 1: offset 0xb96f7e, paddr 0x42c10000, size 0x10ef8c
segment 2: offset 0xca5f0a, paddr 0x00020000, size 0x01d3e8
```

Kernel and all three DTBs built. Kernel-source, display, charging,
board-hardware, USB-regression, safe-profile, GPU-profile, persistent-RAM,
Sony-ELF, appended-DTB, p3-size, SMEM and decompressor-overlap gates pass.
This build does not claim physical display success.

## Hikari MSM8x60 command-DMA-timeout successor

The failed physical display run reached the first MDV22 `B0` command, but the
mainline DSI host aborted after waiting for a command-DMA completion interrupt.
The controller snapshot was idle and error-free, while `TRIG_DMA` remained
set.  A register dump from the working Sony/TWRP stack proves that this trigger
bit also remains set after successful display initialization.  The downstream
MSM8x60 transmitter waits for the interrupt, logs a timeout if it is absent,
and nevertheless returns the transmitted length.

Patch 0056 reproduces that behavior only for the MSM8x60 configuration and
only when the command engine is idle with no FIFO, ACK, timeout, contention or
lane-0 PHY error.  Other platforms and genuine controller errors retain the
strict `-ETIMEDOUT` path.  The locally validated, **not deployed** display
artifact is:

```text
/home/paul/xperia/build/hikari-artifacts-cmd-dma-0056-20260910/display/hikari-display-fastboot.elf
size:   13,381,525 bytes
SHA-256 8ed95e4957dc2e8221c3ca7df3bde0b97f30449c25c5afd2d12c4f73ee7bfe44
entry:  0x40208000
```

Its components are:

```text
zImage:     12,125,888 bytes, 0469bdd25df21d319eafa3c741d4c3705b97dfeabd2813c3d9187b6ad82cf3f1
DTB:            21,857 bytes, 3a8416259349cf6ed7e10b55df6e3e9613f3fd03c3a91a3e4cd87d32121cf11b
zImage+DTB: 12,147,745 bytes, c9929866cc1817bd2d674133e9bbc74a0124dfa66d83b1a805726647ee9cf2b2
initramfs:   1,109,900 bytes, 3228c3a81460b406ba0dba2d55f8c1e2ab83a011cd9d4ca8f200e01f4543d279
```

Sony ELF segments:

```text
segment 0: offset 0x001000, paddr 0x40208000, size 0xb95c21
segment 1: offset 0xb96c21, paddr 0x42c10000, size 0x10ef8c
segment 2: offset 0xca5bad, paddr 0x00020000, size 0x01d3e8
```

The artifact was built from materialized kernel commit
`460c1e3a76c05d4d83162142ce38201a2fa6b665`.  After the patch-mail metadata
was cleaned up, a fresh 56-patch materialization produced commit
`0a673b2063ecb8d94b7bd158fa4a3a7a5ff937ca`; both commits have the identical
source tree `317a097f1e89a02639c860ae8766b3de6bb9959b`.

Kernel and all three DTBs built.  Kernel-source, display, charging,
board-hardware, USB-regression, diagnostic-survival, safe-profile,
GPU-profile, persistent-RAM, initramfs-layout, Sony-ELF, appended-DTB, SMEM
and decompressor-overlap gates pass.  `checkpatch.pl --strict` reports zero
errors, warnings and checks for patch 0056.  The first build attempt failed
because WSL inherited a Windows temporary directory; rebuilding with a native
WSL temporary directory succeeded.  No device was flashed or rebooted.
Visible pixels and advancing display interrupts remain the required physical
acceptance test.

## Hikari USB/OTG/charging successor

Build 0075 physically verified High-Speed USB device operation and
disconnect/reconnect, then exposed an OTG teardown deadlock: the kernel console
and immediately respawned shell both held `ttyGS0` while ChipIdea tried to
remove the UDC. Build 0076 fixed that deadlock: it completed three host-mode
entries/removals and returned to the High-Speed serial gadget. However, its
host VBUS remained absent and no peripheral enumerated. Debugfs showed PM8901
MPP1 still configured as a bidirectional digital pin, despite the regulator
consumer requesting an output.

Build 0077 proved that the logical host sequence completed but still supplied
no physical VBUS. PM8901 regmap readback showed MPP1 register `0x27` remained
at `0x30` (output low), because the generic driver used PM8058's MPP base
`0x50`. The current successor, build 0078, contains patch 0071 selecting the
Sony-backed PM8901 MPP base `0x27`:

```text
/home/paul/xperia/build/hikari-artifacts-usb-otg-0078/display/hikari-display-fastboot.elf
size:   13,390,021 bytes
SHA-256 35ba338b8e8bd95ce3cae33fd3aadc6c959e2b5d1278ac23893518534d60b46a
```

It retains patch 0070's GPIO direction/value correction and all physically
verified display and USB-role work. `SHA256SUMS`, Sony ELF structure,
first-boot memory-layout checks and the complete build/static gate suite pass.
This artifact has not been deployed. USB device mode must be regression-tested;
in host mode register `0x27` must read `0x31`, VBUS must be measured, a low-risk
peripheral must enumerate and transfer real data, and the phone must return to
device mode. Positive-current charging with a battery below 3.9 V remains a
separate required acceptance test.

Build 0079 physically verified the corrected PM8901 register base and complete
OTG cycle: external VBUS powered a Mercusys adapter, EHCI enumerated its
Realtek `2c4e:0102` interface at High Speed, teardown completed, and the gadget
returned to device role. Build 0083 is the accepted successor, adding a small
ARM EABI console launcher so CDC ACM receives a controlling tty, canonical
signals, working Ctrl-C, EOF respawn and reliable repeated host reopens:

```text
/home/paul/xperia/build/hikari-artifacts-usb-otg-0083/display/hikari-display-fastboot.elf
size:   13,393,307 bytes
SHA-256 611668745691aff4a0a038a7addaa3f137dedd276938e43ef0d9a7d66b108160
```

The complete build/static gate suite passed before deployment. The physical
records are `usb-otg-0079-device-test/README.md` and
`usb-console-0083-device-test/README.md`. USB OTG and the diagnostic terminal
are `VERIFIED_DEVICE`; positive-current charging remains a separate test.

The 63-patch series, ending at patch 0068, adds PM8901 support and the
source-backed BQ24160/dual-role USB power path while retaining the physically
verified 0066 display stack. The final **not deployed** display artifact is:

```text
/home/paul/xperia/build/hikari-artifacts-usb-otg-0068-final/display/hikari-display-fastboot.elf
size:   13,387,117 bytes
SHA-256 a5df4cd8535f7e48bf379de20d7b3f7cf3812f5a4d743969945cc888140fd529
```

Companion profiles and initramfs:

```text
gpu/hikari-gpu-fastboot.elf
SHA-256 b2d55146072a09d69ecdb5118aba8c643f287b07a9bef2c3dd839f2327855c96
safe/hikari-safe-fastboot.elf
SHA-256 e63dd8e51b11cd5964ea8141c34e88839b8540bc36bf1ee45c1f20877df6a090
/home/paul/xperia/build/hikari-initramfs-usb-otg-0068-final/hikari-firstboot.cpio.gz
SHA-256 ff8a8f638ace114cc936fffb14264e5fcb69558692273a20319647cb0d25a386
```

The materialized kernel source commit is
`ca6633c7d4dd48aaaf57bc8b5648a3aedb1ce693`.

Kernel and all three DTBs built. Kernel-source, USB config/DT graph, charging,
board-hardware, display, diagnostic-survival, initramfs-layout, safe-profile,
GPU-profile, persistent-RAM, Sony-ELF, appended-DTB, p3-size, SMEM and
decompressor-overlap gates pass. DT schema checking has no new USB/PM8901/
BQ24160/NCP373 error; the remaining warnings predate this change and concern
other board nodes. The build reused only A220 firmware whose pinned SHA-256
matched `firmware/a220/source.lock`. No device was flashed or rebooted.
