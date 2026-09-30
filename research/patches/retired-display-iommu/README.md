# Retired Hikari MDP IOMMU experiments

These patches are retained as research evidence but are not part of the
production kernel series.

Physical Hikari register readback showed that both MSM8x60 MDP IOMMU context
banks remained disabled despite the attempted programming. The working
Sony/TWRP kernel likewise used contiguous physical framebuffer memory without
`CONFIG_MSM_IOMMU`. Patch 0065 therefore detached MDP from these providers and
implemented contiguous CMA scanout.

With no `iommus` property on the MDP node, the paging-domain, multi-provider,
MID-capacity and register-ordering changes in this directory have no production
consumer. The two hardware nodes remain documented in the Hikari DTS but are
disabled so that the unverified upstream fallback driver cannot reset or probe
them accidentally.

Retired from `kernel/patches/series` on 2026-09-11:

- 0040: deferred reset and identity default domain;
- 0041: multiple provider-local client masters;
- 0042: page-table DMA ownership correction;
- 0063: 22-entry MDP IOMMU binding capacity;
- 0064: context/TLB write completion and diagnostic readback.

Evidence state: the non-working IOMMU behavior is `VERIFIED_DEVICE`; these
patches are `HISTORICAL_SOURCE` and must not be restored to production without
new physical evidence that translation is functional.
