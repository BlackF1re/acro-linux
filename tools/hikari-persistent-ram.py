#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Decode the Hikari/TWRP legacy ram_console ring from a host-side dump.

The Xperia recovery uses the Android persistent-RAM defaults: 128-byte data
blocks and 16 Reed-Solomon parity bytes.  This parser reconstructs the ring
without modifying the dump.  It validates the ECC geometry but deliberately
does not claim to correct or authenticate parity bytes.
"""
from __future__ import annotations

import argparse
import struct
import sys
from pathlib import Path

SIGNATURE = 0x43474244  # ASCII "DBGC" in little-endian memory
HEADER_SIZE = 12


def data_capacity(raw_size: int, ecc_size: int = 16,
                  block_size: int = 128) -> tuple[int, int]:
    if raw_size < HEADER_SIZE:
        raise ValueError(f"buffer is too short for a persistent-RAM header: {raw_size} bytes")
    if ecc_size < 0 or block_size <= 0:
        raise ValueError("ECC and block sizes must be non-negative and positive respectively")
    raw_data = raw_size - HEADER_SIZE
    if ecc_size == 0:
        return raw_data, 0
    if raw_data <= ecc_size:
        raise ValueError("buffer is too short for ECC data and header parity")
    # Same geometry as both exact TWRP persistent_ram.c and current mainline
    # ram_core.c.  There is one parity block per data block plus one for the
    # 12-byte header.
    ecc_blocks = (raw_data - ecc_size + block_size + ecc_size - 1) // (block_size + ecc_size)
    parity_bytes = (ecc_blocks + 1) * ecc_size
    capacity = raw_data - parity_bytes
    if capacity <= 0:
        raise ValueError("ECC geometry leaves no data capacity")
    return capacity, parity_bytes


def parse_buffer(raw: bytes, ecc_size: int = 16,
                 block_size: int = 128) -> tuple[int, int, bytes]:
    if len(raw) < HEADER_SIZE:
        raise ValueError(f"buffer is too short for a persistent-RAM header: {len(raw)} bytes")
    signature, start, size = struct.unpack_from("<III", raw)
    capacity, _ = data_capacity(len(raw), ecc_size, block_size)
    if signature != SIGNATURE:
        raise ValueError(f"unexpected signature 0x{signature:08x}; expected DBGC (0x{SIGNATURE:08x})")
    if size > capacity:
        raise ValueError(f"size {size} exceeds data capacity {capacity}")
    if start > size:
        raise ValueError(f"start {start} exceeds valid size {size}")
    data = raw[HEADER_SIZE:HEADER_SIZE + capacity]
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
    parser.add_argument("--ecc-size", type=int, default=16,
                        help="Reed-Solomon parity bytes per block (default: 16; use 0 for no ECC)")
    parser.add_argument("--block-size", type=int, default=128,
                        help="ECC data block size (default: 128)")
    args = parser.parse_args()

    raw = args.raw.read_bytes()
    if args.expect_size and len(raw) != args.expect_size:
        raise SystemExit(f"raw size {len(raw)} does not equal expected {args.expect_size}")
    try:
        capacity, parity_bytes = data_capacity(len(raw), args.ecc_size, args.block_size)
        start, size, ordered = parse_buffer(raw, args.ecc_size, args.block_size)
    except ValueError as exc:
        raise SystemExit(f"persistent RAM is invalid: {exc}") from exc

    print("signature=DBGC")
    print(f"start={start}")
    print(f"size={size}")
    print(f"data_capacity={capacity}")
    print(f"ecc_size={args.ecc_size}")
    print(f"ecc_block_size={args.block_size}")
    print(f"ecc_parity_bytes={parity_bytes}")
    print("ecc_correction=not_performed")
    if args.output:
        args.output.write_bytes(ordered)
        print(f"reconstructed={args.output}")
    else:
        sys.stdout.buffer.write(ordered)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
