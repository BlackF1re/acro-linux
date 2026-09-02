#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Decode the no-ECC legacy Hikari/TWRP ram_console binary layout.

The tool operates only on a host-side copy.  It intentionally supports the
verified zero-ECC layout; accepting an ECC buffer without its exact parameters
would make a corrupt reconstruction look trustworthy.
"""
from __future__ import annotations

import argparse
import struct
import sys
from pathlib import Path

SIGNATURE = 0x43474244  # ASCII "DBGC" in little-endian memory
HEADER_SIZE = 12


def parse_buffer(raw: bytes) -> tuple[int, int, bytes]:
    if len(raw) < HEADER_SIZE:
        raise ValueError(f"buffer is too short for a persistent-RAM header: {len(raw)} bytes")
    signature, start, size = struct.unpack_from("<III", raw)
    capacity = len(raw) - HEADER_SIZE
    if signature != SIGNATURE:
        raise ValueError(f"unexpected signature 0x{signature:08x}; expected DBGC (0x{SIGNATURE:08x})")
    if size > capacity:
        raise ValueError(f"size {size} exceeds data capacity {capacity}")
    if start > size:
        raise ValueError(f"start {start} exceeds valid size {size}")
    data = raw[HEADER_SIZE:]
    if size == capacity:
        ordered = data[start:] + data[:start]
    else:
        # Both the legacy and current implementation only advances start when
        # the circular data area is full.
        ordered = data[:size]
    return start, size, ordered


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("raw", type=Path, help="host-side raw persistent-RAM dump")
    parser.add_argument("--output", type=Path, help="write reconstructed console bytes here")
    parser.add_argument("--expect-size", type=int, default=131072,
                        help="expected raw dump size (default: 131072)")
    args = parser.parse_args()

    raw = args.raw.read_bytes()
    if args.expect_size and len(raw) != args.expect_size:
        raise SystemExit(f"raw size {len(raw)} does not equal expected {args.expect_size}")
    try:
        start, size, ordered = parse_buffer(raw)
    except ValueError as exc:
        raise SystemExit(f"persistent RAM is invalid: {exc}") from exc

    print("signature=DBGC")
    print(f"start={start}")
    print(f"size={size}")
    print(f"data_capacity={len(raw) - HEADER_SIZE}")
    print("ecc=0 (verified Hikari TWRP compatibility profile)")
    if args.output:
        args.output.write_bytes(ordered)
        print(f"reconstructed={args.output}")
    else:
        sys.stdout.buffer.write(ordered)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
