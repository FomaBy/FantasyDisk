#!/usr/bin/env python3
"""SCRUM-805 v5: modal frame regen — strict 4:3, hard-alpha crop (checkerboard-proof)."""
from __future__ import annotations

import base64
import os
import pathlib
import sys

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "sprites" / "ui" / "frames" / "settings_v5" / "ui_settings_v5_modal_frame.png"

PROMPT = (
    "Dark fantasy game UI window panel, crisp pixel-art style, centered on a SOLID PURE MAGENTA (#FF00FF) "
    "background with a clear magenta margin around all sides. A single rectangular panel with proportions "
    "4 to 3 (landscape). Thin riveted bronze-iron border strip along its outer edge with small ornate corner "
    "caps holding tiny ember-red gems. The ENTIRE inside of the panel is a vast flat dark aged leather field: "
    "no inner frame, no inner border, no ornament, no pattern inside. No text, no watermark."
)


def hard_alpha_bbox(im: Image.Image, threshold: int = 200) -> tuple[int, int, int, int]:
    a = im.getchannel("A").point(lambda v: 255 if v >= threshold else 0)
    return a.getbbox()


def flood_clean_two_tone(im: Image.Image, tol: int = 40) -> Image.Image:
    """BFS от краёв: снимает запечённый фон, включая checkerboard из двух тонов.

    Доминантные цвета берём из 4px-рамки по периметру; чистим пиксели,
    близкие к ЛЮБОМУ из двух. Бронзовый контур рамки останавливает заливку,
    так что тёмная кожа внутри не страдает.
    """
    from collections import Counter, deque
    im = im.convert("RGBA")
    px = im.load()
    w, h = im.size
    ring = []
    for x in range(w):
        for y in (0, 1, 2, 3, h - 4, h - 3, h - 2, h - 1):
            ring.append(px[x, y][:3])
    for y in range(h):
        for x in (0, 1, 2, 3, w - 4, w - 3, w - 2, w - 1):
            ring.append(px[x, y][:3])
    quant = Counter((r // 16, g // 16, b // 16) for r, g, b in ring)
    dominants = [tuple(c * 16 + 8 for c in key) for key, _ in quant.most_common(2)]

    def is_bg(rgb):
        return any(sum(abs(rgb[i] - d[i]) for i in range(3)) <= tol * 3 for d in dominants)

    seen = [[False] * w for _ in range(h)]
    q = deque()
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
        if a == 0 or is_bg((r, g, b)):
            px[x, y] = (r, g, b, 0)
            q.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
    return im


def main() -> int:
    from openai import OpenAI
    client = OpenAI()
    res = client.images.generate(model="gpt-image-2", prompt=PROMPT, size="1536x1024",
                                 quality="high", n=1)
    raw = base64.b64decode(res.data[0].b64_json)
    tmp = OUT.with_name("_src_modal_frame.png")
    tmp.write_bytes(raw)
    im = Image.open(tmp).convert("RGBA")
    # Bluescreen-вырезание: всё близкое к маджента -> прозрачно (глобально).
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if r > 150 and b > 150 and g < 110 and (r - g) > 70 and (b - g) > 70:
                px[x, y] = (r, g, b, 0)
    bbox = hard_alpha_bbox(im)
    if bbox:
        im = im.crop(bbox)
    im.putalpha(im.getchannel("A").point(lambda v: 0 if v < 90 else v))
    bbox2 = hard_alpha_bbox(im, 90)
    if bbox2:
        im = im.crop(bbox2)
    im = im.resize((1420, 1060), Image.Resampling.LANCZOS)
    im.save(OUT)
    tmp.unlink()
    print("saved", OUT, im.size)
    return 0


if __name__ == "__main__":
    if not os.environ.get("OPENAI_API_KEY"):
        print("no key", file=sys.stderr)
        sys.exit(2)
    sys.exit(main())
