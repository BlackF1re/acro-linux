#!/usr/bin/env python3
"""Run one Hikari USB ACM shell command without a host-side echo loop."""

import argparse
import errno
import glob
import os
import select
import sys
import termios
import time


def configure_raw(fd: int) -> None:
    attrs = termios.tcgetattr(fd)
    attrs[0] = 0
    attrs[1] = 0
    attrs[2] |= termios.CLOCAL | termios.CREAD
    attrs[3] = 0
    attrs[6][termios.VMIN] = 0
    attrs[6][termios.VTIME] = 0
    termios.tcsetattr(fd, termios.TCSANOW, attrs)
    termios.tcflush(fd, termios.TCIFLUSH)


def write_all(fd: int, payload: bytes, timeout: float) -> None:
    deadline = time.monotonic() + timeout
    offset = 0
    while offset < len(payload):
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise TimeoutError("timed out writing the ACM command")
        _, writable, _ = select.select([], [fd], [], min(remaining, 0.5))
        if not writable:
            continue
        try:
            offset += os.write(fd, payload[offset:])
        except BlockingIOError:
            pass


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--device")
    parser.add_argument("--timeout", type=float, default=8.0)
    parser.add_argument("--no-read", action="store_true")
    parser.add_argument("--no-interrupt", action="store_true")
    parser.add_argument("--read-only", action="store_true")
    parser.add_argument("command", nargs=argparse.REMAINDER)
    args = parser.parse_args()
    devices = [args.device] if args.device else sorted(glob.glob("/dev/ttyACM*"))
    if not devices or not devices[-1]:
        parser.error("no ACM device found")
    if not args.command and not args.read_only:
        parser.error("a command is required")

    fd = os.open(devices[-1], os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
    try:
        configure_raw(fd)
        if not args.read_only:
            command = " ".join(args.command).encode()
            prefix = b"\r\n" if args.no_interrupt else b"\x03\x15\r\n"
            write_all(fd, prefix + command + b"\r\n", args.timeout)
        if args.no_read:
            return 0
        deadline = time.monotonic() + args.timeout
        while time.monotonic() < deadline:
            readable, _, _ = select.select([fd], [], [], 0.5)
            if not readable:
                continue
            try:
                data = os.read(fd, 4096)
            except BlockingIOError:
                continue
            except OSError as exc:
                if exc.errno in (errno.EIO, errno.ENODEV):
                    return 0
                raise
            if data:
                sys.stdout.buffer.write(data)
                sys.stdout.buffer.flush()
        return 0
    finally:
        os.close(fd)


if __name__ == "__main__":
    raise SystemExit(main())
