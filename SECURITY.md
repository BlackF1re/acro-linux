# Security policy

## Supported scope

Security fixes are developed on `main`. Historical kernels, archived experiments
and Android reference environments are research inputs, not supported production
releases. This port has no security-qualified stable release yet.

## Sensitive reports

Do not publish an exploit, credentials, keys or device-private data in an issue.
Contact the maintainer through a private channel listed on the
[project owner's profile](https://github.com/BlackF1re). If no private channel
is available, open an issue asking only for a secure reporting channel, without
vulnerability details. No response-time guarantee is currently offered.

Useful reports identify the affected revision/component, reproducible conditions,
impact and a minimal sanitized example. Ordinary non-sensitive bugs belong in issues.

## Deployment caveats

Diagnostic root access is deliberately retained during bring-up; that is not a
hardened deployment policy. Restrict diagnostic interfaces to trusted hosts.
Experimental boot/sleep/power changes can remove remote access: keep physical
BOOT recovery available. Signing verifies provenance, not hardware safety or
absence of vulnerabilities.
