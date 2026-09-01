# Hikari boot firmware policy

## Current p3 RPM payload

The third verified p3 ELF segment is a nested ELF32 ARM executable with entry
and load address `0x00020000`, size `119784` bytes and outer Sony RPM flag
`0x01000000`. Historical Sony `mkelf.py` names that flag as the Qualcomm
MSM8x60 RPM payload flag. This is strong format evidence that the current
legacy artifact carries an RPM payload, but it does not establish a public
licence, redistribution right, build version, or a target-mainline requirement.

The binary remains only in private recovery material. Its contents are not in
Git, and it is not treated as redistributable firmware.

## First local development

The Phase F owner authorization permits the exact original payload as a
private, local input to an offline prototype when this format must be
represented. This does not authorize sending it to the phone. Any later
deployment still requires separate owner approval. Neither use authorizes
publishing, committing, or redistributing the binary. The final product needs
an independently sourced, licensable firmware provenance decision.

## Target status

Whether mainline MSM8x60 consumes RPM firmware already loaded by S1Boot is
`UNKNOWN` for this exact boot chain. No binary is required for the host-only
baseline build and no payload has been sent to the phone.
