#!/usr/bin/env python3
"""FAN-3981: per-pack engine-object cost table from representation_probe logs.

Usage: pack_object_table.py <log> [<log> ...]
Parses the `probe <pack>: objects before N / after M, C captures, max diff
before/after D, vs source S` lines and prints a Markdown table plus totals.
"""
import re
import sys

ROW = re.compile(r"^probe (\S+): objects before (\d+) / after (\d+), (\d+) captures, max diff before/after (\d+), vs source (\d+)")
rows = {}
for path in sys.argv[1:]:
    for line in open(path, encoding="utf-8", errors="replace"):
        match = ROW.match(line.strip())
        if match:
            pack, before, after, captures, diff, source = match.groups()
            rows[pack] = (int(before), int(after), int(captures), int(diff), int(source))
print("| pack | objects before (AtlasTexture per frame) | objects after (trim table) | captures compared | max diff before/after (0-255) | max diff vs source frame |")
print("|---|---|---|---|---|---|")
tb = ta = tc = 0
md = ms = 0
for pack in sorted(rows):
    before, after, captures, diff, source = rows[pack]
    tb += before; ta += after; tc += captures; md = max(md, diff); ms = max(ms, source)
    print(f"| {pack} | {before} | {after} | {captures} | {diff} | {source} |")
print(f"| **{len(rows)} packs** | **{tb}** | **{ta}** | **{tc}** | **{md}** | **{ms}** |")
