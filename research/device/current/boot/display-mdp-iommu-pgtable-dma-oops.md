# Hikari MDP IOMMU page-table DMA recursion Oops

Status: sanitized `VERIFIED_DEVICE` post-mortem evidence. The observed fault
has a source correction and a newly built local successor artifact. Display
scanout, panel pixels, physical backlight output, and fbcon remain
`NOT_VERIFIED` until a separate physical acceptance test.

## Capture and provenance

TWRP exported the retained mainline console through `/proc/last_kmsg`. The
private raw capture remains outside Git:

```text
/home/paul/xperia/research/private/hikari-recovery-debug/20260905T194022Z/previous-proc-last_kmsg-20260905T194023Z.raw
size: 36,854 bytes
SHA-256: 1832b601058eab366cc9db9afe3b7d9b2a9e87ffa8074c4bd34573aa60487487
kernel: 7.3.0-rc1-gfb48685d80a0-dirty
```

The persistent ring contains isolated damaged characters, but the ordered
display milestones and both complete exception traces agree. No raw command
line or device-unique identifier is committed.

## Last confirmed stage

This run passed the previous multi-provider translation failure and reached
the DRM/MSM display address-space setup:

```text
1.914  secure MMCC AHB and AXI initialization completed
1.916  MMSS fabric unhalted all master ports (0-13)
1.944  MDP footswitch reset completed (GFS=0x11f)
1.955  MDP IOMMU port 0 registered (IRQ 50, two context banks)
1.965  MDP client joined IOMMU group 0
1.966  MDP IOMMU port 1 registered (IRQ 51, two context banks)
1.969  MSM8x60 DSI V2 selected
1.971  DSI firmware state quiesced
1.993  MDP4 bound to DSI
2.041  MDP4 version v4.1 read successfully
2.065  ARMv7s page-table teardown warning
2.073  NULL dereference in __bitmap_clear
```

The `mdp_lut_clk status stuck at 'on'` warnings during the temporary MDP4
clock-disable calls are retained as a separate non-fatal clock issue. The
fatal trace is:

```text
__bitmap_clear
  -> arm_iommu_unmap_phys
  -> dma_unmap_phys
  -> __arm_v7s_free_table
  -> arm_v7s_free_pgtable
  -> msm_iommu_identity_attach
  -> iommu_detach_device
  -> arm_iommu_detach_device
  -> msm_iommu_new
  -> msm_iommu_disp_new
  -> msm_kms_init_vm
  -> mdp4_kms_init
```

The last confirmed stage is MDP4 revision discovery with both MDP IOMMU
providers present. The first unconfirmed stage is successful creation and
attachment of the DRM display IOVA domain. No DSI panel command, scanout, or
pixel result can be inferred from this run.

## Root cause

On ARM32, platform DMA setup first attaches an automatic DMA mapping domain to
the MDP client. DRM/MSM deliberately detaches that domain before attaching its
own display domain. The legacy `msm_iommu` driver built its ARMv7s page tables
with:

```text
io_pgtable_cfg.iommu_dev = MDP client device
```

`io-pgtable-arm-v7s` uses `iommu_dev` for DMA cache maintenance of its own
page-table allocations. Because the MDP client's DMA operations were
themselves backed by the domain being torn down, freeing a page table entered
`dma_unmap_phys()`, recursively called `iommu_unmap()` on the same domain, and
then attempted to release an invalid IOVA bitmap entry. This exactly explains
both the ARMv7s unmap warning and the subsequent null-plus-`0xc4` bitmap
access.

The page-table DMA owner must be a physical IOMMU provider device, whose DMA
operations do not recurse through the MDP client domain. Page-table lifetime
must also extend to domain destruction rather than ending during an ordinary
identity detach.

## Correction

Signed kernel commit `96651e282822a6b587b43dc3c4767a1f27581933`:

- assigns `io_pgtable_cfg.iommu_dev` to a referenced MSM IOMMU provider;
- retains that provider reference for the page-table lifetime;
- frees the page table only from domain destruction;
- tracks each attached provider context explicitly in the domain;
- uses `-1`, not context bank zero, as the detached sentinel;
- unwinds partially attached providers and releases context maps correctly;
- invalidates the TLB only for context banks attached to this domain;
- leaves the caller's original IOVA unchanged while flushing multiple
  providers.

Project patch
`kernel/patches/0042-iommu-msm-fix-page-table-DMA-ownership.patch` preserves
the fix in the reproducible patch stack. Source guards reject the recursive
client-as-page-table-owner pattern, page-table destruction from identity
detach, and provider-level domain lists that lose per-context ownership.

## Locally validated successor

```text
/home/paul/xperia/build/hikari-artifacts-iommu-fix-20260906/display/hikari-display-fastboot.elf
size: 13,381,798 bytes
SHA-256: 47a34d7c1b2ccf0cebf1a36ad06182a360fbd15423e18898c90d42db1782f4aa
kernel commit: 96651e282822a6b587b43dc3c4767a1f27581933
artifact source commit: f519c40a936401c680bfbbd59d7107ffeba39847
```

The kernel and all three bundle profiles built from a fresh output directory.
The display profile passed the kernel-source, display-source, final-DTB,
focused binding, Sony ELF, appended-DTB, SMEM, ramoops, initramfs, USB
regression, charging, board-hardware, partition-size, and ARM decompressor
relocation/overlap gates. This is a locally valid candidate, not a claim that
the physical LCD now works.
