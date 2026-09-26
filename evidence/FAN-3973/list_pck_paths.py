#!/usr/bin/env python3
"""FAN-3973: list the file table of a Godot 4 PCK and check the export exclusions.

Usage: list_pck_paths.py <file.pck> [--dump <paths.txt>]

Prints the file count, the total payload size, every path that falls under a
non-game location the 0.3.1 Setup shipped by mistake (must be empty), and a
per-top-level-directory summary. Exit code 1 when a forbidden path is present.
"""
from __future__ import annotations

import struct
import sys
from collections import Counter
from pathlib import Path

FORBIDDEN_PREFIXES = (
    "res://evidence/",
    "res://skills/",
    "res://docs/",
    "res://tools/",
    "res://tests/",
    "res://references/",
    "res://source_docs/",
    "res://build/",
    "res://releases/",
)
FORBIDDEN_FILES = (
    "res://before_berserk_648p.png",
    "res://before_berserk_648p.png.import",
    "res://after_berserk_648p.png",
    "res://after_berserk_648p.png.import",
)
PACK_DIR_ENCRYPTED = 1 << 0


def read_pck(path: Path) -> list[tuple[str, int]]:
    with path.open("rb") as handle:
        magic = handle.read(4)
        if magic != b"GDPC":
            raise SystemExit(f"{path}: not a Godot PCK (magic {magic!r})")
        pack_version, major, minor, patch = struct.unpack("<IIII", handle.read(16))
        flags, file_base = struct.unpack("<IQ", handle.read(12))
        if flags & PACK_DIR_ENCRYPTED:
            raise SystemExit(f"{path}: encrypted directory, cannot list")
        if pack_version >= 3:
            # Pack format 3+ (Godot 4.4+) stores the file directory at an
            # explicit offset (it is written after the payload).
            (dir_offset,) = struct.unpack("<Q", handle.read(8))
            handle.seek(dir_offset)
        else:
            handle.read(16 * 4)  # reserved
        (count,) = struct.unpack("<I", handle.read(4))
        print(f"{path.name}: pack format {pack_version}, engine {major}.{minor}.{patch}, flags {flags}, {count} files")
        entries: list[tuple[str, int]] = []
        for _ in range(count):
            (length,) = struct.unpack("<I", handle.read(4))
            raw = handle.read(length)
            file_path = raw.split(b"\0", 1)[0].decode("utf-8")
            _offset, size = struct.unpack("<QQ", handle.read(16))
            handle.read(16)  # md5
            handle.read(4)  # per-file flags
            entries.append((file_path, size))
    return entries


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(__doc__)
        return 2
    pck = Path(argv[1])
    dump = Path(argv[argv.index("--dump") + 1]) if "--dump" in argv else None
    entries = read_pck(pck)
    if dump is not None:
        dump.write_text("\n".join(f"{size}\t{file_path}" for file_path, size in sorted(entries)) + "\n", encoding="utf-8")
    total = sum(size for _, size in entries)
    print(f"payload: {total} bytes ({total / 1048576:.1f} MiB)")
    forbidden = [
        (file_path, size)
        for file_path, size in entries
        if file_path.startswith(FORBIDDEN_PREFIXES) or file_path in FORBIDDEN_FILES
    ]
    by_top = Counter()
    by_top_bytes = Counter()
    for file_path, size in entries:
        rel = file_path.removeprefix("res://")
        top = rel.split("/", 1)[0] if "/" in rel else "<root>"
        by_top[top] += 1
        by_top_bytes[top] += size
    print("| top-level | files | bytes |")
    print("|---|---|---|")
    for top, count in sorted(by_top.items(), key=lambda item: -by_top_bytes[item[0]]):
        print(f"| {top} | {count} | {by_top_bytes[top]} |")
    root_files = sorted(file_path for file_path, _ in entries if "/" not in file_path.removeprefix("res://"))
    print("root files:", ", ".join(root_files))
    if forbidden:
        print(f"FORBIDDEN paths present: {len(forbidden)}")
        for file_path, size in forbidden[:20]:
            print(f"  {file_path} ({size} bytes)")
        return 1
    print("forbidden paths present: 0")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
