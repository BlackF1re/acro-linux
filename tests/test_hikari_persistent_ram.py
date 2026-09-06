#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Synthetic tests for the Hikari persistent-RAM parser."""
import importlib.util
import struct
import unittest
from pathlib import Path

MODULE = Path(__file__).parents[1] / "tools" / "hikari-persistent-ram.py"
SPEC = importlib.util.spec_from_file_location("hikari_persistent_ram", MODULE)
assert SPEC and SPEC.loader
RAM = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(RAM)


def image(start, size, data, capacity=16, parity=0):
    return (struct.pack("<III", RAM.SIGNATURE, start, size) +
            data.ljust(capacity, b"\0") + b"\0" * parity)


class PersistentRamTest(unittest.TestCase):
    def test_partial_buffer_is_linear(self):
        start, size, decoded = RAM.parse_buffer(image(0, 5, b"hello"), ecc_size=0)
        self.assertEqual((start, size, decoded), (0, 5, b"hello"))

    def test_full_buffer_is_circular(self):
        start, size, decoded = RAM.parse_buffer(
            image(5, 16, b"abcdefghijklmnop"), ecc_size=0)
        self.assertEqual((start, size), (5, 16))
        self.assertEqual(decoded, b"fghijklmnopabcde")

    def test_rejects_invalid_header(self):
        with self.assertRaises(ValueError):
            RAM.parse_buffer(b"\0" * 28, ecc_size=0)

    def test_rejects_out_of_range_size(self):
        raw = struct.pack("<III", RAM.SIGNATURE, 0, 17) + b"\0" * 16
        with self.assertRaises(ValueError):
            RAM.parse_buffer(raw, ecc_size=0)

    def test_exact_twrp_ecc_geometry(self):
        capacity, parity = RAM.data_capacity(131072, ecc_size=16, block_size=128)
        self.assertEqual(capacity, 116468)
        self.assertEqual(parity, 14592)

    def test_ecc_ring_ignores_parity_area(self):
        capacity = 128
        # Solve a small synthetic geometry: 12 header + 128 data + 2 data
        # parity blocks + one header parity block.
        raw = image(3, capacity, bytes(range(capacity)), capacity, parity=48)
        start, size, decoded = RAM.parse_buffer(raw, ecc_size=16, block_size=64)
        self.assertEqual((start, size), (3, 128))
        self.assertEqual(decoded, bytes(range(3, 128)) + bytes(range(3)))


if __name__ == "__main__":
    unittest.main()
