#!/usr/bin/env python3
"""FAN-3976: list the file table of a Godot 4 PCK, standalone or embedded in a PE exe.

Usage: list_pck.py <FantasyDisk.pck | FantasyDisk.exe> [--dump <paths.txt>] [--json <out.json>]

Same forbidden-path rule as FAN-3973 (`evidence/FAN-3973/list_pck_paths.py`): the
built bytes must not carry evidence/, skills/, docs/, tools/, tests/ or the stray
root screenshots. Exit 1 when a forbidden path is present. For an exe the PCK is
located through the Godot embed trailer (8-byte size + "GDPC" at end of file).
"""
from __future__ import annotations

import json
import struct
import sys
from collections import Counter
from pathlib import Path

FORBIDDEN_PREFIXES = (
    "res://evidence/", "res://skills/", "res://docs/", "res://tools/", "res://tests/",
    "res://references/", "res://source_docs/", "res://build/", "res://releases/",
    "res://changelog.d/", "res://.github/", "res://.multica/", "res://.claude/",
)
FORBIDDEN_FILES = (
    "res://before_berserk_648p.png", "res://before_berserk_648p.png.import",
    "res://after_berserk_648p.png", "res://after_berserk_648p.png.import",
)
PACK_DIR_ENCRYPTED = 1 << 0
PACK_REL_FILEBASE = 1 << 1


def read_pck(path: Path) -> tuple[dict, list[tuple[str, int]]]:
    size = path.stat().st_size
    with path.open("rb") as handle:
        pck_start = 0
        if handle.read(4) != b"GDPC":
            handle.seek(size - 4)
            if handle.read(4) != b"GDPC":
                raise SystemExit(f"{path}: no PCK magic at start or in the embed trailer")
            handle.seek(size - 12)
            (pck_size,) = struct.unpack("<Q", handle.read(8))
            pck_start = size - 12 - pck_size
            handle.seek(pck_start)
            if handle.read(4) != b"GDPC":
                raise SystemExit(f"{path}: embed trailer points at a non-PCK offset {pck_start}")
        pack_version, major, minor, patch = struct.unpack("<IIII", handle.read(16))
        flags, file_base = struct.unpack("<IQ", handle.read(12))
        if flags & PACK_DIR_ENCRYPTED:
            raise SystemExit(f"{path}: encrypted directory, cannot list")
        if pack_version >= 3:
            (dir_offset,) = struct.unpack("<Q", handle.read(8))
            if flags & PACK_REL_FILEBASE:
                dir_offset += pck_start
            handle.seek(dir_offset)
        else:
            handle.read(16 * 4)
        (count,) = struct.unpack("<I", handle.read(4))
        entries: list[tuple[str, int]] = []
        for _ in range(count):
            (length,) = struct.unpack("<I", handle.read(4))
            raw = handle.read(length)
            file_path = raw.split(b"\0", 1)[0].decode("utf-8")
            if not file_path.startswith(("res://", "uid://", "user://")):
                # Pack format 3+ stores project-relative paths; normalize to res://.
                if file_path.startswith("/") or "\x00" in file_path or not file_path.isprintable():
                    raise SystemExit(f"{path}: directory parse drifted at entry {len(entries)}: {file_path!r}")
                file_path = "res://" + file_path
            _offset, fsize = struct.unpack("<QQ", handle.read(16))
            handle.read(16)
            handle.read(4)
            entries.append((file_path, fsize))
    header = {
        "container": path.name, "container_size": size, "pck_start": pck_start,
        "pck_size": size - 12 - pck_start if pck_start else size,
        "pack_format": pack_version, "engine": f"{major}.{minor}.{patch}",
        "flags": flags, "file_count": count,
    }
    return header, entries


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(__doc__)
        return 2
    target = Path(argv[1])
    header, entries = read_pck(target)
    total = sum(s for _, s in entries)
    header["payload_bytes"] = total
    forbidden = [(p, s) for p, s in entries if p.startswith(FORBIDDEN_PREFIXES) or p in FORBIDDEN_FILES]
    by_top, by_top_bytes = Counter(), Counter()
    for p, s in entries:
        rel = p.removeprefix("res://")
        top = rel.split("/", 1)[0] if "/" in rel else "<root>"
        by_top[top] += 1
        by_top_bytes[top] += s
    root_files = sorted(p for p, _ in entries if "/" not in p.removeprefix("res://"))
    print(f"{header['container']}: pack format {header['pack_format']}, engine {header['engine']}, flags {header['flags']}, {header['file_count']} files, pck_start {header['pck_start']}")
    print(f"payload: {total} bytes ({total / 1048576:.1f} MiB)")
    print("| top-level | files | bytes |")
    print("|---|---|---|")
    for top, c in sorted(by_top.items(), key=lambda i: -by_top_bytes[i[0]]):
        print(f"| {top} | {c} | {by_top_bytes[top]} |")
    print("root files:", ", ".join(root_files))
    if "--dump" in argv:
        Path(argv[argv.index("--dump") + 1]).write_text("\n".join(f"{s}\t{p}" for p, s in sorted(entries)) + "\n", encoding="utf-8")
    if "--json" in argv:
        Path(argv[argv.index("--json") + 1]).write_text(json.dumps({
            **header, "top_level": {t: {"files": by_top[t], "bytes": by_top_bytes[t]} for t in by_top},
            "root_files": root_files, "forbidden_count": len(forbidden), "forbidden_sample": forbidden[:20],
        }, indent=2) + "\n", encoding="utf-8")
    if forbidden:
        print(f"FORBIDDEN paths present: {len(forbidden)}")
        for p, s in forbidden[:20]:
            print(f"  {p} ({s} bytes)")
        return 1
    print("forbidden paths present: 0")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
