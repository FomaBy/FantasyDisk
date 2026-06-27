"""SCRUM-478 phase 3: render the BRIGHT minimalist PANEL/MODAL/CARD/TOOLTIP/HUD
frame textures in-place over the existing exact-size minimal_metal frames.

Each frame keeps its exact source size and 9-slice content margins, so runtime
layout is unchanged. The bright style matches the phase-2 buttons: semi-opaque
dark fill, thin amber border, small corner accents kept INSIDE the 9-slice margin
band so corners stay crisp and only the flat center stretches.

Originals backed up once to docs/design/backups/minimal_metal_frames_pre_bright/.

Run from project root:  python3 tools/render_bright_frames.py
"""
from __future__ import annotations

import shutil
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
FRAME_DIR = ROOT / "assets/sprites/ui/frames/minimal_metal"
BACKUP = ROOT / "docs/design/backups/minimal_metal_frames_pre_bright"

AMBER = (228, 170, 52)
ACCENT = (245, 196, 96)
FILL_TOP = (34, 31, 27)
FILL_BOT = (24, 22, 19)
FILL_ALPHA = 214
# inner border thickness band (must sit within the 9-slice content margin)
BORDER_W = 4


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def render(w: int, h: int) -> Image.Image:
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    pad = 3
    rad = max(10, min(26, h // 12))
    x0, y0, x1, y1 = pad, pad, w - pad - 1, h - pad - 1

    # semi-opaque dark fill (gradient) inside rounded rect
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle((x0, y0, x1, y1), radius=rad, fill=255)
    grad = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    gp = grad.load()
    for yy in range(h):
        t = min(1.0, max(0.0, (yy - y0) / max(1, y1 - y0)))
        c = lerp(FILL_TOP, FILL_BOT, t)
        for xx in range(w):
            gp[xx, yy] = c + (FILL_ALPHA,)
    img = Image.composite(grad, img, mask)

    d = ImageDraw.Draw(img)
    # amber border + faint inner line
    d.rounded_rectangle((x0, y0, x1, y1), radius=rad, outline=AMBER + (255,), width=BORDER_W)
    d.rounded_rectangle((x0 + BORDER_W, y0 + BORDER_W, x1 - BORDER_W, y1 - BORDER_W),
                        radius=max(4, rad - BORDER_W), outline=lerp(FILL_TOP, AMBER, 0.4) + (110,), width=1)

    # corner accents (L brackets) — kept short so they stay within margin band
    L = max(14, min(30, h // 14))
    for cx, cy, sx, sy in ((x0 + 6, y0 + 6, 1, 1), (x1 - 6, y0 + 6, -1, 1),
                           (x0 + 6, y1 - 6, 1, -1), (x1 - 6, y1 - 6, -1, -1)):
        d.line([(cx, cy), (cx + sx * L, cy)], fill=ACCENT + (255,), width=3)
        d.line([(cx, cy), (cx, cy + sy * L)], fill=ACCENT + (255,), width=3)
    return img


def main() -> None:
    if not BACKUP.exists():
        shutil.copytree(FRAME_DIR, BACKUP, ignore=shutil.ignore_patterns("*.import"))
    n = 0
    for p in sorted(FRAME_DIR.glob("*.png")):
        w, h = Image.open(p).size
        render(w, h).save(p)
        n += 1
    print(f"rendered {n} bright frames in-place (sizes preserved); backup: {BACKUP.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
