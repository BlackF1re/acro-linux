#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-or-later
"""Build and validate the small Sony ELF32 layout used by legacy LT26 images.

The program intentionally operates on local files only.  It never invokes
fastboot, ADB, or any device-writing utility.
"""

from __future__ import annotations

import argparse
import hashlib
import struct
import sys
import tempfile
from pathlib import Path

ELF_HEADER = struct.Struct("<16sHHIIIIIHHHHHH")
PROGRAM_HEADER = struct.Struct("<IIIIIIII")
PT_LOAD = 1
EM_ARM = 40
ET_EXEC = 2
RAMDISK_FLAG = 0x80000000
RPM_FLAG = 0x01000000
HEADER_SIZE = 0x1000


def fail(message: str) -> None:
    raise ValueError(message)


def digest(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def inspect(path: Path, limit: int | None = None) -> list[dict[str, int]]:
    data = path.read_bytes()
    if len(data) < ELF_HEADER.size:
        fail("file is smaller than an ELF32 header")
    fields = ELF_HEADER.unpack_from(data)
    ident, elf_type, machine, _, entry, phoff, _, _, _, phentsize, phnum, _, _, _ = fields
    if ident[:4] != b"\x7fELF" or ident[4] != 1 or ident[5] != 1:
        fail("not a little-endian ELF32 file")
    if elf_type != ET_EXEC or machine != EM_ARM:
        fail("expected ARM ELF32 ET_EXEC")
    if phentsize != PROGRAM_HEADER.size:
        fail("unexpected program-header size")
    if phnum == 0:
        fail("no program headers")
    if limit is not None and len(data) > limit:
        fail(f"artifact is {len(data)} bytes, exceeds limit {limit}")

    segments: list[dict[str, int]] = []
    for index in range(phnum):
        at = phoff + index * phentsize
        if at + phentsize > len(data):
            fail("truncated program-header table")
        kind, offset, vaddr, paddr, filesz, memsz, flags, align = PROGRAM_HEADER.unpack_from(data, at)
        if kind != PT_LOAD:
            continue
        if offset + filesz > len(data):
            fail(f"segment {index} extends beyond artifact")
        if memsz < filesz:
            fail(f"segment {index} has memsz smaller than filesz")
        segments.append({"index": index, "offset": offset, "vaddr": vaddr, "paddr": paddr,
                         "filesz": filesz, "memsz": memsz, "flags": flags, "align": align})
    if not segments:
        fail("no PT_LOAD segments")
    by_address = sorted(segments, key=lambda item: item["paddr"])
    for previous, current in zip(by_address, by_address[1:]):
        if previous["paddr"] + previous["memsz"] > current["paddr"]:
            fail(f"load-address overlap: {previous['index']} and {current['index']}")
    print(f"file={path}")
    print(f"size={len(data)}")
    print(f"sha256={digest(path)}")
    print(f"entry=0x{entry:08x}")
    for segment in segments:
        print("segment={index} offset=0x{offset:x} paddr=0x{paddr:08x} "
              "filesz=0x{filesz:x} memsz=0x{memsz:x} flags=0x{flags:08x}".format(**segment))
    return segments


def build(args: argparse.Namespace) -> None:
    inputs = [(Path(args.kernel), args.kernel_addr, 0),
              (Path(args.ramdisk), args.ramdisk_addr, RAMDISK_FLAG),
              (Path(args.rpm), args.rpm_addr, RPM_FLAG)]
    payloads = []
    for path, address, flags in inputs:
        if not path.is_file():
            fail(f"missing input: {path}")
        payloads.append((path.read_bytes(), address, flags))
    output = Path(args.output)
    if output.exists():
        fail(f"refusing to overwrite existing artifact: {output}")
    offset = HEADER_SIZE
    headers = []
    for payload, address, flags in payloads:
        headers.append((PT_LOAD, offset, address, address, len(payload), len(payload), flags, 0))
        offset += len(payload)
    if args.limit is not None and offset > args.limit:
        fail(f"artifact is {offset} bytes, exceeds limit {args.limit}")
    ident = b"\x7fELF\x01\x01\x01" + b"\0" * 9
    header = ELF_HEADER.pack(ident, ET_EXEC, EM_ARM, 1, args.kernel_addr, ELF_HEADER.size,
                             0, 0, ELF_HEADER.size, PROGRAM_HEADER.size, len(headers), 0, 0, 0)
    with output.open("xb") as stream:
        stream.write(header)
        for program_header in headers:
            stream.write(PROGRAM_HEADER.pack(*program_header))
        stream.write(b"\0" * (HEADER_SIZE - stream.tell()))
        for payload, _, _ in payloads:
            stream.write(payload)
    inspect(output, args.limit)


def selftest() -> None:
    with tempfile.TemporaryDirectory(prefix="sony-elf-test-") as temp:
        directory = Path(temp)
        for name, content in (("kernel", b"kernel"), ("ramdisk", b"ramdisk"), ("rpm", b"rpm")):
            (directory / name).write_bytes(content)
        output = directory / "test.elf"
        args = argparse.Namespace(kernel=directory / "kernel", ramdisk=directory / "ramdisk", rpm=directory / "rpm",
                                  output=output, kernel_addr=0x40208000, ramdisk_addr=0x41800000,
                                  rpm_addr=0x20000, limit=20 * 1024 * 1024)
        build(args)
        if output.stat().st_size != HEADER_SIZE + 6 + 7 + 3:
            fail("unexpected self-test artifact size")


def parse_number(value: str) -> int:
    return int(value, 0)


def main() -> int:
    parser = argparse.ArgumentParser()
    commands = parser.add_subparsers(dest="command", required=True)
    inspect_parser = commands.add_parser("inspect")
    inspect_parser.add_argument("artifact", type=Path)
    inspect_parser.add_argument("--limit", type=parse_number)
    build_parser = commands.add_parser("build")
    for name in ("kernel", "ramdisk", "rpm"):
        build_parser.add_argument(f"--{name}", required=True)
    build_parser.add_argument("--output", required=True)
    build_parser.add_argument("--kernel-addr", type=parse_number, default=0x40208000)
    build_parser.add_argument("--ramdisk-addr", type=parse_number, default=0x41800000)
    build_parser.add_argument("--rpm-addr", type=parse_number, default=0x20000)
    build_parser.add_argument("--limit", type=parse_number, default=20 * 1024 * 1024)
    commands.add_parser("selftest")
    try:
        args = parser.parse_args()
        if args.command == "inspect":
            inspect(args.artifact, args.limit)
        elif args.command == "build":
            build(args)
        else:
            selftest()
        return 0
    except (OSError, ValueError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
