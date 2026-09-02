#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Synthetic tests for the no-ECC Hikari persistent-RAM parser."""
import importlib.util
import struct
import unittest
from pathlib import Path

MODULE = Path(__file__).parents[1] / "tools" / "hikari-persistent-ram.py"
SPEC = importlib.util.spec_from_file_location("hikari_persistent_ram", MODULE)
assert SPEC and SPEC.loader
RAM = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(RAM)


def image(start, size, data, capacity=16):
    return struct.pack("<III", RAM.SIGNATURE, start, size) + data.ljust(capacity, b"\0")


class PersistentRamTest(unittest.TestCase):
    def test_partial_buffer_is_linear(self):
        start, size, decoded = RAM.parse_buffer(image(0, 5, b"hello"))
        self.assertEqual((start, size, decoded), (0, 5, b"hello"))

    def test_full_buffer_is_circular(self):
        start, size, decoded = RAM.parse_buffer(image(5, 16, b"abcdefghijklmnop"))
        self.assertEqual((start, size), (5, 16))
        self.assertEqual(decoded, b"fghijklmnopabcde")

    def test_rejects_invalid_header(self):
        with self.assertRaises(ValueError):
            RAM.parse_buffer(b"\0" * 28)

    def test_rejects_out_of_range_size(self):
        raw = struct.pack("<III", RAM.SIGNATURE, 0, 17) + b"\0" * 16
        with self.assertRaises(ValueError):
            RAM.parse_buffer(raw)


if __name__ == "__main__":
    unittest.main()
