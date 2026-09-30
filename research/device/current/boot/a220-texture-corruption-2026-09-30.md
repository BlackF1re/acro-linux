# Adreno 220 compositor corruption diagnosis — 2026-09-30

State: `VERIFIED_DEVICE` diagnostic evidence; root cause remains `RESEARCHING`.

The physical Hikari runs Mesa Freedreno renderer `FD220`. Simple solid GLES2
rendering and readback work, while Phosh/Phoc frames contain black or corrupted
triangles. The corruption also occurs in headless full-Phosh tests, so MDP4 is
not its sole cause.

A separate scanout blocker was localized with exact GEM-object identity. The
native MSM object was created with flags `0x00020000` and reached framebuffer
prepare with the same flags: the kernel did not lose `MSM_BO_SCANOUT`. A stale
locally installed Gallium library had omitted the
`FD_BO_SCANOUT -> MSM_BO_SCANOUT` mapping. Reinstalling the reproducible
`25.0.7-2+deb13u1+hikari5` package produced `0x00020001` on the same object,
allowed contiguous no-IOMMU MDP4 scanout and removed the atomic `-EINVAL` loop.

The original rendering fault is independent. A controlled 720x1280 probe
renders a source, samples it as a texture into a destination, and reads the
destination back. Solid rendering always passes, but textured draws alternate
strictly between correct output and a fully black result. The same alternation
occurs with a 4x4 CPU-uploaded texture, excluding dma-buf import,
render-to-texture preservation, buffer age, partial damage and MDP4. Adjacent
PASS and FAIL processes submit byte-identical command streams, identical
texture constants, handles and IOVAs; all fences complete successfully and the
kernel reports no GPU fault. Full RD dumps differ only in the resulting render
target contents.

Current boundary: incomplete A220 texture/context state or hardware cache
initialization. The next experiment must identify the missing state transition
in the A2xx texture path. Phosh stays on `WLR_RENDERER=pixman` as a safe
baseline; this is not the final GPU fix.

An unrelated boot regression was traced to the experimental
`CONFIG_ARM_QCOM_CPUFREQ_MSM8660`: failing boots repeatedly raised RPM fatal
IRQ 19. The currently booted DRM test kernel has that option disabled.
