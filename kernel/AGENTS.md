# Kernel work rules

Use current upstream Linux as the base. Retrieve unmerged shared work through
lore/b4, preserve authorship and record revision and Message-ID. Android BSP
code is research evidence, never production architecture.

Keep builds out of the repository and do not commit generated kernels, DTBs,
initramfs archives or firmware. Use current kernel coding style, small
bisectable commits and existing bindings before proposing new ones. Run DT
schema validation for DTS work and resolve warnings rather than suppressing
them.

Any temporary bring-up hack must be clearly marked. A compile or probe is not
hardware verification: only an acceptance test on the physical Xperia can set
target status to `VERIFIED`.
