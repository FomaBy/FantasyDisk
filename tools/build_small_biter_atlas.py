#!/usr/bin/env python3
"""FAN-3934: deterministic lossless Small Biter atlas packer.

Packs the 184 committed 512x512 Small Biter frames into at most three
4096x4096 RGBA pages (64 slots per page; 184 frames occupy pages 0-2 with
56 slots on page 2), rewrites `small_biter_spriteframes.tres` so every
standalone texture reference becomes an AtlasTexture region, and writes the
committed manifest binding source hashes, layout and import settings.

Lossless guarantees: every original pixel byte, transparent padding, logical
frame dimensions, animation names/order/FPS/loop and per-frame durations are
preserved; the registry interface (AnimatedSprite2D.sprite_frames) is
unchanged. Original PNGs and their import sidecars stay in place.

Usage: python3 tools/build_small_biter_atlas.py [--check]
  --check verifies the committed atlas/manifest/tres instead of writing.
"""
from __future__ import annotations

import hashlib
import json
import struct
import sys
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FRAMES_DIR = ROOT / "assets/sprites/enemies/full_frame"
TRES = FRAMES_DIR / "small_biter_spriteframes.tres"
MANIFEST = FRAMES_DIR / "small_biter_atlas_manifest.json"
ATLAS_BASE = "small_biter_atlas"
PAGE_SIZE = 4096
SLOT = 512
SLOTS_PER_PAGE = (PAGE_SIZE // SLOT) ** 2  # 64
MAX_PAGES = 3
MAX_FRAME_EQUIVALENTS = 192  # PM bound: total decoded RGBA area


def read_png(path: Path) -> tuple[int, int, bytes]:
    data = path.read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", path
    pos = 8
    width = height = 0
    bit_depth = color_type = 0
    idat = b""
    while pos < len(data):
        length = struct.unpack(">I", data[pos:pos+4])[0]
        ctype = data[pos+4:pos+8]
        chunk = data[pos+8:pos+8+length]
        pos += 12 + length
        if ctype == b"IHDR":
            width, height, bit_depth, color_type = struct.unpack(">IIBB", chunk[:10])
        elif ctype == b"IDAT":
            idat += chunk
        elif ctype == b"IEND":
            break
    raw = zlib.decompress(idat)
    return width, height, bit_depth, color_type, raw


def paeth(a: int, b: int, c: int) -> int:
    p = a + b - c
    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
    if pa <= pb and pa <= pc:
        return a
    return b if pb <= pc else c


def unfilter(raw: bytes, width: int, height: int, bpp: int) -> bytes:
    stride = width * bpp
    out = bytearray()
    prev = bytearray(stride)
    pos = 0
    for _ in range(height):
        ftype = raw[pos]
        pos += 1
        line = bytearray(raw[pos:pos+stride])
        pos += stride
        if ftype == 1:
            for i in range(bpp, stride):
                line[i] = (line[i] + line[i - bpp]) & 255
        elif ftype == 2:
            for i in range(stride):
                line[i] = (line[i] + prev[i]) & 255
        elif ftype == 3:
            for i in range(stride):
                a = line[i - bpp] if i >= bpp else 0
                line[i] = (line[i] + ((a + prev[i]) >> 1)) & 255
        elif ftype == 4:
            for i in range(stride):
                a = line[i - bpp] if i >= bpp else 0
                b = prev[i]
                c = prev[i - bpp] if i >= bpp else 0
                line[i] = (line[i] + paeth(a, b, c)) & 255
        out += line
        prev = line
    return bytes(out)


def to_rgba(width: int, height: int, bit_depth: int, color_type: int, raw: bytes) -> bytes:
    assert bit_depth == 8, bit_depth
    bpp = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[color_type]
    px = unfilter(raw, width, height, bpp)
    if color_type == 6:
        return px
    out = bytearray()
    for i in range(0, len(px), bpp):
        if color_type == 0:
            g = px[i]
            out += bytes((g, g, g, 255))
        elif color_type == 2:
            out += px[i:i+3] + b"\xff"
        elif color_type == 4:
            g, a = px[i], px[i+1]
            out += bytes((g, g, g, a))
        else:
            raise AssertionError("palette sources not expected for small_biter")
    return bytes(out)


def write_png(path: Path, width: int, height: int, rgba: bytes) -> None:
    def chunk(ctype: bytes, data: bytes) -> bytes:
        head = struct.pack(">I", len(data)) + ctype + data
        return head + struct.pack(">I", zlib.crc32(ctype + data) & 0xFFFFFFFF)

    stride = width * 4
    filtered = bytearray()
    for y in range(height):
        filtered.append(0)  # filter type None per row
        filtered += rgba[y*stride:(y+1)*stride]
    out = b"\x89PNG\r\n\x1a\n"
    out += chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
    out += chunk(b"IDAT", zlib.compress(bytes(filtered), 6))
    out += chunk(b"IEND", b"")
    path.write_bytes(out)


def main() -> int:
    check_only = "--check" in sys.argv[1:]
    tres_text = TRES.read_text(encoding="utf-8")
    import re
    frame_paths = re.findall(r'path="([^"]+)"', tres_text)
    if check_only and any(ATLAS_BASE in p for p in frame_paths):
        # Already converted: the original frame list lives in the manifest.
        frame_paths = [f["path"] for f in json.loads(MANIFEST.read_text())["frames"]]
    assert frame_paths and all(p.endswith(".png") for p in frame_paths), frame_paths
    frames = []
    for res_path in frame_paths:
        width, height, bd, ct, raw = read_png(ROOT / res_path.removeprefix("res://"))
        rgba = to_rgba(width, height, bd, ct, raw)
        assert (width, height) == (SLOT, SLOT), (res_path, width, height)
        frames.append({"path": res_path, "rgba": rgba,
                       "sha": hashlib.sha256((ROOT / res_path.removeprefix("res://")).read_bytes()).hexdigest()})

    pages_count = (len(frames) + SLOTS_PER_PAGE - 1) // SLOTS_PER_PAGE
    assert pages_count <= MAX_PAGES, pages_count
    assert pages_count * SLOTS_PER_PAGE <= MAX_FRAME_EQUIVALENTS

    layout = []
    for index, frame in enumerate(frames):
        page = index // SLOTS_PER_PAGE
        slot = index % SLOTS_PER_PAGE
        layout.append({
            "path": frame["path"],
            "sha256": frame["sha"],
            "page": page,
            "x": (slot % (PAGE_SIZE // SLOT)) * SLOT,
            "y": (slot // (PAGE_SIZE // SLOT)) * SLOT,
            "w": SLOT,
            "h": SLOT,
        })

    page_bytes = {}
    for page in range(pages_count):
        canvas = bytearray(PAGE_SIZE * PAGE_SIZE * 4)
        for entry in layout:
            if entry["page"] != page:
                continue
            frame = frames[[f["path"] for f in frames].index(entry["path"])]
            for y in range(SLOT):
                dst = ((entry["y"] + y) * PAGE_SIZE + entry["x"]) * 4
                src = y * SLOT * 4
                canvas[dst:dst + SLOT*4] = frame["rgba"][src:src + SLOT*4]
        page_bytes[page] = bytes(canvas)

    manifest = {
        "version": 1,
        "source_tres_sha256": hashlib.sha256(tres_text.encode()).hexdigest(),
        "packer": "tools/build_small_biter_atlas.py",
        "layout": {"page_size": PAGE_SIZE, "slot": SLOT, "pages": pages_count,
                   "slots_per_page": SLOTS_PER_PAGE,
                   "frame_equivalents": pages_count * SLOTS_PER_PAGE},
        "import_settings": {
            "importer": "texture", "type": "CompressedTexture2D",
            "compress/mode": 0, "mipmaps/generate": False,
            "note": "lossless, no mipmaps — recorded from the committed .png.import sidecars; same settings class as the original per-frame textures",
        },
        "frames": layout,
        "pages": [],
    }

    # Rewrite the tres: keep everything except texture ext_resources; append
    # AtlasTexture sub_resources and swap references.
    lines = [l for l in tres_text.splitlines()
             if not (l.strip().startswith("[ext_resource") and 'type="Texture2D"' in l)]
    text = "\n".join(lines) + "\n"
    ext_ids = re.findall(r'id="([^"]+)"', "\n".join(
        l for l in tres_text.splitlines()
        if l.strip().startswith("[ext_resource") and 'type="Texture2D"' in l))
    sub_lines = []
    for page in range(pages_count):
        sub_lines.append(f'[ext_resource type="Texture2D" '
                         f'path="res://assets/sprites/enemies/full_frame/{ATLAS_BASE}_{page}.png" '
                         f'id="{page}_atlas"]')
    sub_lines.append("")
    for k, (eid, entry) in enumerate(zip(ext_ids, layout)):
        sub_lines += [
            f'[sub_resource type="AtlasTexture" id="Atlas_{k}"]',
            f'atlas = ExtResource("{entry["page"]}_atlas")',
            f'region = Rect2({entry["x"]}, {entry["y"]}, {entry["w"]}, {entry["h"]})',
            "",
        ]
    idx = text.index("[resource]")
    text = text[:idx] + "\n".join(sub_lines) + text[idx:]
    for k, eid in enumerate(ext_ids):
        text = text.replace(f'ExtResource("{eid}")', f'SubResource("Atlas_{k}")')
    text = re.sub(r"(load_steps=)\d+", lambda m: f"{m.group(1)}{1 + pages_count + len(ext_ids)}",
                  text, count=1)

    if check_only:
        ok = True
        committed_manifest = json.loads(MANIFEST.read_text())
        if committed_manifest["layout"] != manifest["layout"] or committed_manifest["frames"] != layout:
            print("CHECK FAIL: committed layout/frames differ from computed packing")
            ok = False
        for page in range(pages_count):
            png = FRAMES_DIR / f"{ATLAS_BASE}_{page}.png"
            width, height, bd, ct, raw = read_png(png)
            if to_rgba(width, height, bd, ct, raw) != page_bytes[page]:
                print(f"CHECK FAIL: page {page} pixels differ")
                ok = False
            recorded = next((e["sha256"] for e in committed_manifest["pages"] if e["page"] == page), None)
            if recorded != hashlib.sha256(png.read_bytes()).hexdigest():
                print(f"CHECK FAIL: page {page} hash mismatch with manifest")
                ok = False
        committed_tres = TRES.read_text(encoding="utf-8")
        if "AtlasTexture" not in committed_tres or committed_tres != tres_text:
            print("CHECK FAIL: committed tres is not the converted form")
            ok = False
        print("ATLAS CHECK " + ("OK" if ok else "FAILED"))
        return 0 if ok else 1

    for page in range(pages_count):
        png = FRAMES_DIR / f"{ATLAS_BASE}_{page}.png"
        write_png(png, PAGE_SIZE, PAGE_SIZE, page_bytes[page])
        manifest["pages"].append({
            "page": page,
            "path": f"res://assets/sprites/enemies/full_frame/{ATLAS_BASE}_{page}.png",
            "sha256": hashlib.sha256(png.read_bytes()).hexdigest(),
        })
    TRES.write_text(text, encoding="utf-8")
    MANIFEST.write_text(json.dumps(manifest, indent=1) + "\n")
    print(f"atlas built: {pages_count} pages, {len(frames)} frames, "
          f"tres sha {hashlib.sha256(text.encode()).hexdigest()[:12]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
