# Hikari USB console build 0080 device test

Date: 2026-09-13

Evidence state: `VERIFIED_DEVICE` for the observations below.

Build 0080 booted on the physical Hikari and enumerated on the development
host as the High-Speed CDC ACM gadget `0525:a4a7`; WSL created
`/dev/ttyACM0`. The role-aware console supervisor recovered a clean root shell
after an EOF and then executed commands through two independent serial opens,
including a seven-second closed-port interval:

```text
EXEC_SESSION2
device
configured
~ #
EXEC_SESSION3
device
configured
~ #
```

The same run reproduced the remaining usability defect. An accidentally
incomplete command left ash at its `>` continuation prompt. Sending `Ctrl-C`
was echoed but did not interrupt the parser; EOF exited it and the supervisor
started a clean shell after its bounded retry. Process inspection showed the
shell as plain `/bin/sh -i`. This is consistent with its redirected ttyGS0
file descriptors but lack of a controlling terminal.

Build 0081 attempted to keep the already tested role-aware supervisor while
launching the shell through `setsid cttyhack`. Its physical boot kept CDC ACM
enumerated but returned no shell bytes. Source inspection explains the result:
BusyBox `cttyhack` deliberately discovers `/sys/class/tty/console/active`
(`tty0` here), opens that node and duplicates it over stdin/stdout/stderr; it
does not preserve a redirected ttyGS0 stdin. Build 0082 replaces it with
`setsid -c sh -i`, whose `-c` performs `TIOCSCTTY` directly on stdin. This
README does not claim that 0082 works; it requires a physical Ctrl-C and
reconnect test.

Later physical testing is recorded separately in the build-0083 evidence.
Build 0082 did acquire ttyGS0 as its controlling terminal, but retained PID
1's inherited ignored-SIGINT disposition. Build 0083 resets signal state in a
small launcher and passed the Ctrl-C, EOF and repeated-reopen tests.

The tested build-0080 display ELF was:

```text
SHA-256 6104999543678f957b10e3a73d87883ea56346d203a8787822c7cb5dec54fb98
size    13390966 bytes
```
