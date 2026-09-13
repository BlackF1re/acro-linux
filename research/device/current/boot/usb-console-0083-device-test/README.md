# Hikari USB console build 0083 device test

Date: 2026-09-14

Evidence state: `VERIFIED_DEVICE` for the observations below.

The physical Hikari booted build 0083 and enumerated on the development host
as the High-Speed CDC ACM gadget `0525:a4a7`; WSL exposed `/dev/ttyACM0`.
Commands executed as uid 0 on `/dev/ttyGS0`, while the authoritative sysfs
state was USB role `device` and UDC state `configured`.

## Root cause and correction

Build 0082 proved that `setsid -c` established a real controlling tty, but
termios initially reported `-isig -icanon` and the interactive ash status had
`SigIgn: 0000000000284006`. Enabling `stty sane` did not repair Ctrl-C because
bit 1 remained set: ash inherited `SIGINT=SIG_IGN` from the PID 1 ash and, per
shell signal semantics, preserved it. Foreground `sleep 30` therefore ignored
the terminal-generated signal too.

Build 0083 starts the disposable shell with the freestanding ARM EABI
`hikari-console-launch`. The 4528-byte launcher uses direct syscalls so it does
not add another static libc to the constrained Sony ELF layout. It establishes
the ttyGS0 session and foreground process group, sets canonical `ISIG` termios,
resets inherited signal dispositions and execs `/bin/sh -i`.

On build 0083, the live shell reported:

```text
uid=0 gid=0
/dev/ttyGS0
opts=smi
SigIgn: 0000000000284004
device
configured
```

The missing `0x2` bit is the expected removal of ignored SIGINT. Two physical
VINTR tests then passed: Ctrl-C returned ash from an unmatched single quote to
its primary prompt, and interrupted a foreground `sleep 30` without executing
the command that followed it.

Sending EOF at an empty prompt terminated the shell. After the supervisor's
bounded retry, a new root shell executed commands with PID 482. Three further
independent host opens, each separated by seven seconds, returned:

```text
__0083_REOPEN_ONE__   pid=482 device configured
__0083_REOPEN_TWO__   pid=482 device configured
__0083_REOPEN_THREE__ pid=482 device configured
```

The retained live kernel log also showed the expected recovery paths: the
initial enumeration transition ended the first shell with SIGHUP (`rc=129`),
then the supervisor restarted it; the deliberate EOF later recorded `rc=0`
and another restart. After all tests, a refined dmesg scan found zero kernel
panic, Oops, BUG, unhandled-fault or blocked-task signatures.

The tested display-profile Sony ELF was:

```text
SHA-256 611668745691aff4a0a038a7addaa3f137dedd276938e43ef0d9a7d66b108160
size    13393307 bytes
```

This verifies the diagnostic CDC ACM terminal's command traffic, controlling
TTY semantics, Ctrl-C recovery, foreground job interruption, EOF respawn and
reopen stability. It does not define a production USB identity or production
login/authentication policy.
