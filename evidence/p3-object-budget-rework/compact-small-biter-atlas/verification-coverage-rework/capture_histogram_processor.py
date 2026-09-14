#!/usr/bin/env python3
"""FAN-3934: committed processor for the capture-derived control assertions.

Computes, from two committed capture PNGs: (a) the old checker's 8th-pixel
color histogram equality, and (b) byte-level SHA-256 inequality — the two
executed measurements behind old-vs-new-control-derived.json's capture fields.
Reads inputs verbatim; prints a JSON verdict; exit 0 when the measured
outcomes match the derived record's asserted values.

Usage: python3 capture_histogram_processor.py <sprite.png> <reference.png> <expected_old_equal> <expected_sha_differ>
"""
from __future__ import annotations

import hashlib
import json
import struct
import sys
import zlib
from pathlib import Path


def read_png_rows(path: str):
    data = Path(path).read_bytes()
    pos = 8
    width = height = 0
    bit_depth = color_type = 0
    idat = b""
    while pos < len(data):
        length = struct.unpack(">I", data[pos:pos + 4])[0]
        ctype = data[pos + 4:pos + 8]
        chunk = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if ctype == b"IHDR":
            width, height, bit_depth, color_type = struct.unpack(">IIBB", chunk[:10])
        elif ctype == b"IDAT":
            idat += chunk
        elif ctype == b"IEND":
            break
    raw = zlib.decompress(idat)
    assert (bit_depth, color_type) == (8, 6), (path, bit_depth, color_type)
    stride = width * 4
    rows = []
    prev = bytearray(stride)
    pos = 0

    def paeth(a, b, c):
        p = a + b - c
        pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
        return a if pa <= pb and pa <= pc else (b if pb <= pc else c)

    for _ in range(height):
        ftype = raw[pos]; pos += 1
        line = bytearray(raw[pos:pos + stride]); pos += stride
        if ftype == 1:
            for i in range(4, stride):
                line[i] = (line[i] + line[i - 4]) & 255
        elif ftype == 2:
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 255
        elif ftype == 3:
            for i in range(stride):
                a = line[i - 4] if i >= 4 else 0
                line[i] = (line[i] + ((a + prev[i]) >> 1)) & 255
        elif ftype == 4:
            for i in range(stride):
                a = line[i - 4] if i >= 4 else 0
                b = prev[i]
                c = prev[i - 4] if i >= 4 else 0
                line[i] = (line[i] + paeth(a, b, c)) & 255
        rows.append(bytes(line))
        prev = line
    return width, height, rows


def old_histogram(rows, width, height):
    histogram = {}
    for y in range(0, height, 8):
        row = rows[y]
        for x in range(0, width, 8):
            i = x * 4
            r, g, b, a = row[i], row[i + 1], row[i + 2], row[i + 3]
            if a < 13:
                continue
            key = f"{r},{g},{b}"
            histogram[key] = histogram.get(key, 0) + 1
    return histogram


def rows_sha(rows):
    digest = hashlib.sha256()
    for row in rows:
        digest.update(row)
    return digest.hexdigest()


def main() -> int:
    sprite, reference = sys.argv[1], sys.argv[2]
    expected_old_equal = sys.argv[3] == "true"
    expected_sha_differ = sys.argv[4] == "true"
    inputs = {p: hashlib.sha256(Path(p).read_bytes()).hexdigest() for p in (sprite, reference)}
    w1, h1, r1 = read_png_rows(sprite)
    w2, h2, r2 = read_png_rows(reference)
    assert (w1, h1) == (w2, h2)
    old_equal = old_histogram(r1, w1, h1) == old_histogram(r2, w2, h2)
    sha_differ = rows_sha(r1) != rows_sha(r2)
    verdict = {
        "processor": "capture_histogram_processor.py",
        "inputs": inputs,
        "old_checker_histogram_equal": old_equal,
        "spatial_sha_differ": sha_differ,
        "matches_derived_record": old_equal == expected_old_equal and sha_differ == expected_sha_differ,
    }
    print("FAN3934_CAPTURE_PROCESSOR " + json.dumps(verdict))
    return 0 if verdict["matches_derived_record"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
