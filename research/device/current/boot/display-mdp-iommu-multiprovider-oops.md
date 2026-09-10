# Hikari MDP multi-provider IOMMU Oops

Status: sanitized `VERIFIED_DEVICE` post-mortem evidence. The fault was fixed
and its successor physically passed this boundary. Display scanout, panel
pixels, physical backlight output, and fbcon remain `NOT_VERIFIED`.

## Capture and provenance

TWRP exported the retained mainline console through `/proc/last_kmsg`. The
private raw capture remains outside Git:

```text
/home/paul/xperia/research/private/hikari-recovery-debug/20260905T183458Z/proc-last_kmsg.pull3.raw
size: 41,966 bytes
SHA-256: fa8f57620cbfae1088a5b63b57645f7f5160e3c9fe8dd3fe82ac20a52ac13c5c
kernel: 7.3.0-rc1-gaa355cd51909-dirty
```

The ring contains isolated damaged characters but the boot sequence, register
state, exception registers, and complete call trace are mutually consistent.
No raw command line or device-unique identifier is committed.

## Last confirmed stage

The run passed the previously failing secure-MMCC operations and MDP power
sequence:

```text
1.600606  secure MMCC initialization begin
1.600805  secure MMCC AHB control initialized
1.600963  secure MMCC AXI control initialized
1.602356  MMSS fabric unhalted all master ports (0-13)
1.630499  MDP footswitch reset completed (GFS=0x11f)
1.636239  first MDP IOMMU mapped, IRQ 50, two context banks
1.641654  NULL dereference at virtual address 0x00000088
```

The exception is in the asynchronous deferred-probe worker:

```text
PC is at qcom_iommu_of_xlate+0x84/0x184
r1 = 0x00000000
qcom_iommu_of_xlate
  -> of_iommu_xlate
  -> of_iommu_configure
  -> of_dma_configure_id
  -> platform_dma_configure
  -> __iommu_probe_device
  -> iommu_device_register
  -> msm_iommu_probe
```

The last confirmed display stage is successful secure MMCC/MDP-foot-switch
initialization followed by registration of the first MDP IOMMU provider. The
first unconfirmed stage is successful translation and attachment of the MDP
client to both MDP IOMMU providers. DRM, DSI packet transfer, panel pixels,
and fbcon were never tested by this run.

## Root cause

The Hikari MDP correctly references two independent MSM8x60 IOMMU providers.
Exact Sony source defines `mdp_port0` and `mdp_port1`, each with two context
banks; the non-secure context on each port owns MIDs 0 and 2. The DT therefore
uses:

```dts
iommus = <&mdp_port0 0>, <&mdp_port0 2>,
         <&mdp_port1 0>, <&mdp_port1 2>;
```

The generic `msm_iommu` driver incorrectly represented all translations for a
client with one `dev_iommu_priv` pointer. During the first deferred probe it
created a provider-local master for the available IOMMU, then returned
`-ENODEV` for the provider that had not probed. The IOMMU core released the
per-device state, while the first provider retained its master in `ctx_list`.

On retry, the old code saw the non-empty provider list, skipped allocation,
left the per-device master pointer null, and dereferenced `master->num_mids`.
That is the observed null-plus-`0x88` access. Attach/detach also selected the
first list entry and could program masters belonging to another client.

The same single-pointer/first-entry assumptions are present in the checked
Linus tree. The current Tenderloin MSM8x60 port instead looks up a client
master within each IOMMU provider. Its branch `6.18`, head
`37d5887cd67dae88b0eb37564adc8e6c0c39c609` (checked 2026-09-06), was used as
the modern working architecture reference; Sony remains the authority for the
Hikari providers, context banks, and MIDs.

## Correction

Signed kernel commit `fb48685d80a0bfb4b55b67afc5ec1463d2833d0f`
implements provider-local client-master lookup. It creates one persistent
master per client and provider, translates repeated MIDs into that exact
master, and makes attach/detach configure only matching masters. It no longer
uses the single per-device private pointer for this relationship.

The historical patch is retained at
`research/patches/retired-display-iommu/0041-iommu-msm-track-client-masters-per-provider.patch`.
It was removed from the production series after physical scanout succeeded
with MDP detached from both IOMMU providers.

## Locally validated successor

```text
/home/paul/xperia/build/hikari-artifacts-20260906T020500Z/display/hikari-display-fastboot.elf
size: 13,382,214 bytes
SHA-256: 2922e71f51365ca75e6274544d25e281dc997bebcc6957e22598e0250a44182e
kernel commit: fb48685d80a0bfb4b55b67afc5ec1463d2833d0f
project artifact commit: 12f21b39fe84dd460f86c4c8909f7ff9317b232d
```

The target driver object and full kernel built successfully. The final Hikari
DTB, focused new bindings, display/static source guards, appended DTB, Sony
ELF, SMEM, ramoops, ARM zImage relocation, initramfs, USB regression, charging,
and board-hardware gates passed. Targeted full-DTB validation emitted only the
already tracked non-display pin-state naming and experimental A220-compatible
warnings; it emitted no MDP/IOMMU/MMCC/DSI/panel/backlight error.

This artifact was later deployed in a controlled physical display retry. It
passed the multi-provider translation boundary, registered both IOMMUs,
initialized DSI V2, bound MDP4 to DSI, and read MDP4 version v4.1 before a
separate ARMv7s page-table DMA ownership fault. That successor fault is
documented in
[display-mdp-iommu-pgtable-dma-oops.md](display-mdp-iommu-pgtable-dma-oops.md).
