# Contributing

This is a native Linux port for Sony Xperia acro S / Hikari. Read
[AGENTS.md](AGENTS.md), [hardware scope](docs/HARDWARE_SCOPE.md) and the relevant
subdirectory instructions before changing hardware support.

## Workflow

1. Open an issue describing the function, current evidence and proposed scope.
2. Make the smallest justified change. Production kernel work stays in the
   17 subsystem patches; preserve original authorship and licensing.
3. Run repository checks and relevant source/build gates:
   ```sh
   python3 -m unittest discover -s tests
   scripts/materialize-hikari-kernel.sh /path/to/new/linux-hikari
   ```
4. For hardware claims, include the exact kernel/Mesa identity, runtime library
   maps, test procedure, logs and observed result. A build/probe is not acceptance.
5. Submit a focused pull request with **cryptographically signed commits** and
   DCO sign-off (`git commit -S -s`). Sign-off and cryptographic signing are distinct.

Contributions are under the applicable file license. A sign-off certifies the
[Developer Certificate of Origin](https://developercertificate.org/).
Do not claim hardware verification unless that function ran on the device.

## Device safety and privacy

BOOT is the recovery anchor. Do not flash or replace it, overwrite the working
SYSTEM bundle, kexec from SMP SYSTEM, or live-unbind MDP4. Use separate microSD
candidate bundles and keep a verified recovery path. Read [RECOVERY.md](docs/RECOVERY.md).

Never upload keys, credentials, TA/radio-NV, calibration, private identifiers,
unsanitized personal logs or firmware without redistribution rights. Keep binary
kernel/DTB/initramfs build products outside git.

## Reporting

Use the issue templates for reproducible failures, hardware acceptance and
feature requests. Include failed results too; retain UNKNOWN/PARTIAL where
acceptance is incomplete. For sensitive findings, follow [SECURITY.md](SECURITY.md).
