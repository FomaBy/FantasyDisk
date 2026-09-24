#!/usr/bin/env python3
"""List the resource paths packed into a Godot 4 .pck (export proof helper).

Usage: python3 evidence/FAN-3966/list_pck_paths.py <file.pck> [prefix-filter]
Prints one packed path per line; with a prefix filter prints only matching
paths and a final count line. Reads the PCK v2/v3/v4 directory only, never file data.
"""
import struct
import sys


def read_paths(path):
    with open(path, "rb") as pck:
        magic = pck.read(4)
        if magic != b"GDPC":
            raise SystemExit(f"{path}: not a Godot pack (magic {magic!r})")
        version, major, minor, patch = struct.unpack("<4I", pck.read(16))
        if version not in (2, 3, 4):
            raise SystemExit(f"{path}: unsupported pack format {version}")
        flags, file_base = struct.unpack("<IQ", pck.read(12))
        if flags & 1:
            raise SystemExit(f"{path}: encrypted directory, cannot list")
        if version >= 3:
            # Godot 4.4+ stores the directory at an explicit offset (format 3;
            # format 4 keeps the same header/entry layout with new flag bits).
            (dir_offset,) = struct.unpack("<Q", pck.read(8))
            pck.seek(dir_offset)
        else:
            pck.read(16 * 4)  # reserved
        (count,) = struct.unpack("<I", pck.read(4))
        paths = []
        for _ in range(count):
            (length,) = struct.unpack("<I", pck.read(4))
            raw = pck.read(length)
            pck.read(8 + 8 + 16 + 4)  # offset, size, md5, flags
            paths.append(raw.rstrip(b"\0").decode("utf-8", "replace"))
        return (major, minor, patch), paths


def main(argv):
    if len(argv) < 2:
        raise SystemExit(__doc__)
    engine, paths = read_paths(argv[1])
    prefix = argv[2] if len(argv) > 2 else ""
    matched = [p for p in paths if p.startswith(prefix)] if prefix else paths
    for p in matched:
        print(p)
    print(f"# engine {engine[0]}.{engine[1]}.{engine[2]}; packed files {len(paths)}; matching '{prefix}': {len(matched)}")


if __name__ == "__main__":
    main(sys.argv)
