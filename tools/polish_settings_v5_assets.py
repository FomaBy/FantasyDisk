#!/usr/bin/env python3
"""SCRUM-805 v5 polish: despill магента-каймы рамки + перегенерация chip/track/fill."""
from __future__ import annotations

import base64
import os
import pathlib
import sys

from PIL import Image, ImageFilter

ROOT = pathlib.Path(__file__).resolve().parent.parent
DIR = ROOT / "assets" / "sprites" / "ui" / "frames" / "settings_v5"

STYLE = (
    "Dark fantasy game UI element, crisp pixel-art style, dark aged leather and bronze, muted gold, "
    "single isolated element centered on a fully transparent background, flat front-facing UI sprite, "
    "no text, no lettering, no watermark. "
)

REGEN = [
    ("ui_settings_v5_value_chip.png", (96, 48),
     "The element is a wide horizontal bar with proportions about 2 to 1, filling most of the canvas width. "
     "Small recessed rectangular plate: very dark, almost black sunken leather center, thin dark bronze frame, "
     "completely empty face, no ornament, no gems."),
    ("ui_settings_v5_slider_track.png", (420, 18),
     "The element is a wide horizontal bar with proportions about 12 to 1, filling most of the canvas width. "
     "Long slim horizontal slider groove: plain dark iron channel with subtle bronze end caps, completely plain "
     "along its length, NO center ornament, NO decorations, flat."),
    ("ui_settings_v5_slider_fill.png", (416, 12),
     "The element is a wide horizontal bar with proportions about 16 to 1, filling most of the canvas width. "
     "Long slim horizontal molten-gold glowing fill bar with straight rectangular ends, completely plain, "
     "NO ornaments, NO decorations, flat."),
]


def flood_clean(im: Image.Image, tol: int = 26) -> Image.Image:
    from collections import deque
    im = im.convert("RGBA")
    px = im.load()
    w, h = im.size
    bg = px[0, 0][:3]
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


def fix_frame_fringe() -> None:
    path = DIR / "ui_settings_v5_modal_frame.png"
    im = Image.open(path).convert("RGBA")
    px = im.load()
    w, h = im.size
    # 1) Despill: явные маджента-пиксели гасим в бронзу (усредняем к зелёному каналу).
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a > 0 and (r - g) > 28 and (b - g) > 28:
                nr = (r + g) // 2
                nb = (b + g) // 2
                px[x, y] = (nr, g, nb, a)
    # 2) Erode альфы на 2px: убираем полупрозрачную кайму по силуэту.
    alpha = im.getchannel("A")
    eroded = alpha.filter(ImageFilter.MinFilter(5))
    im.putalpha(eroded)
    im.save(path)
    print("fringe fixed", path.name)


def regen(client, name: str, final: tuple[int, int], prompt: str) -> None:
    out = DIR / name
    res = client.images.generate(model="gpt-image-2", prompt=STYLE + prompt,
                                 size="1024x1024", quality="high", n=1)
    raw = base64.b64decode(res.data[0].b64_json)
    tmp = DIR / ("_src_" + name)
    tmp.write_bytes(raw)
    im = Image.open(tmp).convert("RGBA")
    if im.getpixel((0, 0))[3] > 8:
        im = flood_clean(im)
    w, h = im.size
    band = int(h * 0.72 / 2)
    if final[1] <= 20:  # слайдерные ленты: срезаем вертикальные поля
        im = im.crop((0, h // 2 - band, w, h // 2 + band))
    bbox = im.getchannel("A").getbbox()
    if bbox:
        im = im.crop(bbox)
    im = im.resize(final, Image.Resampling.LANCZOS)
    im.save(out)
    tmp.unlink()
    print("regen", name, im.size)


def main() -> int:
    fix_frame_fringe()
    from openai import OpenAI
    client = OpenAI()
    for name, final, prompt in REGEN:
        regen(client, name, final, prompt)
    return 0


if __name__ == "__main__":
    if not os.environ.get("OPENAI_API_KEY"):
        print("no key", file=sys.stderr)
        sys.exit(2)
    sys.exit(main())
