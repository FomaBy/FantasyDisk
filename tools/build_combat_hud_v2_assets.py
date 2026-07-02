#!/usr/bin/env python3
"""SCRUM-806: generate compact combat HUD v2 base assets via OpenAI gpt-image-2.

Outputs (assets/sprites/ui/hud/combat_hud_v2/):
  ui_hud_v2_bar_track.png   512x32  — slim recessed bar track, thin brass edging (h-9-slice)
  ui_hud_v2_cluster_bg.png  768x256 — soft dark leather backing plate, full-bleed 9-slice

Bar fills are reused from assets/sprites/ui/hud/combat_hud/ui_hud_bar_fill_*.png.
Icons come from PixelLab MCP (pixel art pass on top), not from this script.
"""
from __future__ import annotations

import base64
import os
import sys
from collections import deque
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "assets/sprites/ui/hud/combat_hud_v2"

STYLE = (
    "dark fantasy RPG game UI, aged dark leather and antique brass, subtle gold trim, "
    "Baldur's Gate / D&D style, muted palette, clean edges, no text, no letters, "
    "plain flat background"
)

JOBS = [
    {
        "name": "ui_hud_v2_bar_track.png",
        "size": "1536x1024",
        "crop_to": (1536, 128),   # center strip, then downscale
        "final": (512, 32),
        "prompt": (
            "A single long thin horizontal empty progress bar track for a game HUD, "
            "recessed dark iron groove with a very thin antique brass edging along the "
            "border, slightly rounded ends, empty interior almost black, centered on the "
            "canvas, spanning the full width, " + STYLE
        ),
    },
    {
        "name": "ui_hud_v2_cluster_bg.png",
        "size": "1536x1024",
        "crop_to": None,
        "final": (768, 256),
        "prompt": (
            "A wide rectangular soft backing plate for a game HUD corner cluster, dark "
            "worn leather with a very thin understated brass border line near the edge, "
            "flat and uncluttered center, no ornaments in the middle, low contrast, "
            + STYLE
        ),
    },
]


def flood_clean_alpha(im: Image.Image, tol: int = 26) -> Image.Image:
    """Remove border-connected near-uniform background (baked bg fix, no resize)."""
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()
    corners = [px[0, 0], px[w - 1, 0], px[0, h - 1], px[w - 1, h - 1]]
    bg = tuple(sum(c[i] for c in corners) // 4 for i in range(3))
    seen = [[False] * w for _ in range(h)]
    q: deque = deque()
    for x in range(w):
        q.append((x, 0)); q.append((x, h - 1))
    for y in range(h):
        q.append((0, y)); q.append((w - 1, y))
    while q:
        x, y = q.popleft()
        if x < 0 or y < 0 or x >= w or y >= h or seen[y][x]:
            continue
        seen[y][x] = True
        r, g, b, a = px[x, y]
        if a == 0 or (abs(r - bg[0]) + abs(g - bg[1]) + abs(b - bg[2])) <= tol * 3:
            px[x, y] = (r, g, b, 0)
            q.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
    return im


def generate(client, job: dict) -> Image.Image:
    kwargs = dict(model="gpt-image-2", prompt=job["prompt"], size=job["size"],
                  quality="high", n=1)
    try:
        res = client.images.generate(background="transparent", **kwargs)
    except Exception:
        res = client.images.generate(**kwargs)
    raw = base64.b64decode(res.data[0].b64_json)
    tmp = OUT_DIR / ("_src_" + job["name"])
    tmp.write_bytes(raw)
    return Image.open(tmp).convert("RGBA")


def postprocess(im: Image.Image, job: dict) -> Image.Image:
    # If background still baked in (opaque corners), flood-clean it.
    corner_alpha = im.getpixel((0, 0))[3]
    if corner_alpha > 8:
        im = flood_clean_alpha(im)
    if job["crop_to"]:
        cw, ch = job["crop_to"]
        w, h = im.size
        box = ((w - cw) // 2, (h - ch) // 2, (w + cw) // 2, (h + ch) // 2)
        im = im.crop(box)
    # Trim fully transparent border rows/cols, then letterbox back to aspect.
    bbox = im.getchannel("A").getbbox()
    if bbox:
        im = im.crop(bbox)
    return im.resize(job["final"], Image.Resampling.LANCZOS)


def main() -> int:
    if not os.environ.get("OPENAI_API_KEY"):
        print("OPENAI_API_KEY is not set", file=sys.stderr)
        return 2
    from openai import OpenAI
    client = OpenAI()
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for job in JOBS:
        out = OUT_DIR / job["name"]
        print("generating", job["name"], flush=True)
        im = generate(client, job)
        im = postprocess(im, job)
        im.save(out)
        print("saved", out, im.size, flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
