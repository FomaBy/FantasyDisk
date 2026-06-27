"""SCRUM-478 phase 2: render the BRIGHT minimalist button set in-place over the
existing exact-size minimal_metal button textures.

Each minimal_metal button PNG is already authored at its exact pixel size
(170..560 x 104, etc.). We re-render each at the SAME size in the new bright
amber-accent minimalist style (matching the generated anchor in
docs/design/references/ui_minimalist_478/), so every button across the whole UI
updates without any code change and WITHOUT runtime stretching (each asset stays
1:1 to its slot). State is read from the filename suffix.

Originals are backed up once to docs/design/backups/minimal_metal_buttons_pre_bright/.

Run from project root:  python3 tools/render_bright_buttons.py
"""
from __future__ import annotations

import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
BTN_DIR = ROOT / "assets/sprites/ui/frames/minimal_metal_buttons"
BACKUP = ROOT / "docs/design/backups/minimal_metal_buttons_pre_bright"

# palette per state: (border, body_top, body_bottom, accent, glow)
AMBER = (228, 170, 52)
STATES = {
    "normal":   {"border": AMBER,            "body": ((44, 40, 34), (30, 27, 23)), "accent": (245, 196, 96),  "glow": None, "dy": 0},
    "hover":    {"border": (255, 206, 96),    "body": ((58, 50, 36), (38, 33, 24)), "accent": (255, 224, 140), "glow": (255, 200, 90), "dy": 0},
    "pressed":  {"border": (176, 130, 44),    "body": ((30, 26, 20), (22, 19, 15)), "accent": (210, 165, 80),  "glow": None, "dy": 2},
    "disabled": {"border": (120, 118, 112),   "body": ((52, 50, 48), (40, 38, 36)), "accent": (150, 148, 142), "glow": None, "dy": 0},
    "focus":    {"border": (245, 192, 80),    "body": ((50, 44, 34), (34, 30, 22)), "accent": (255, 220, 130), "glow": (235, 185, 80), "dy": 0},
}


def state_of(name: str) -> str:
    for s in ("hover", "pressed", "disabled", "focus"):
        if name.endswith("_" + s):
            return s
    return "normal"


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def render(w: int, h: int, state: str) -> Image.Image:
    cfg = STATES[state]
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    pad = 4
    dy = cfg["dy"]
    rad = max(8, min(20, (h - pad * 2) // 4))
    x0, y0, x1, y1 = pad, pad + dy, w - pad - 1, h - pad - 1 + dy

    # optional outer glow (hover/focus)
    if cfg["glow"]:
        glow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        ImageDraw.Draw(glow).rounded_rectangle((x0, y0, x1, y1), radius=rad,
                                               outline=cfg["glow"] + (180,), width=6)
        img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(5)))

    d = ImageDraw.Draw(img)
    # body vertical gradient
    top, bot = cfg["body"]
    body = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    bd = ImageDraw.Draw(body)
    bd.rounded_rectangle((x0, y0, x1, y1), radius=rad, fill=(255, 255, 255, 255))
    grad = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    gp = grad.load()
    for yy in range(h):
        t = (yy - y0) / max(1, (y1 - y0))
        t = min(1.0, max(0.0, t))
        c = lerp(top, bot, t)
        for xx in range(w):
            gp[xx, yy] = c + (255,)
    body = Image.composite(grad, Image.new("RGBA", (w, h), (0, 0, 0, 0)), body.split()[3])
    img.alpha_composite(body)

    # border + thin inner highlight
    d.rounded_rectangle((x0, y0, x1, y1), radius=rad, outline=cfg["border"] + (255,), width=3)
    d.rounded_rectangle((x0 + 3, y0 + 3, x1 - 3, y1 - 3), radius=max(4, rad - 3),
                        outline=lerp(cfg["body"][0], cfg["border"], 0.35) + (120,), width=1)

    # small corner accents (L brackets) — skip on tiny buttons
    if min(w, h) >= 48:
        a = cfg["accent"]; L = max(8, min(16, h // 6))
        for cx, cy, sx, sy in ((x0 + 4, y0 + 4, 1, 1), (x1 - 4, y0 + 4, -1, 1),
                               (x0 + 4, y1 - 4, 1, -1), (x1 - 4, y1 - 4, -1, -1)):
            d.line([(cx, cy), (cx + sx * L, cy)], fill=a + (255,), width=2)
            d.line([(cx, cy), (cx, cy + sy * L)], fill=a + (255,), width=2)
    return img


def main() -> None:
    if not BACKUP.exists():
        shutil.copytree(BTN_DIR, BACKUP, ignore=shutil.ignore_patterns("*.import"))
    n = 0
    for p in sorted(BTN_DIR.glob("*.png")):
        w, h = Image.open(p).size
        render(w, h, state_of(p.stem)).save(p)
        n += 1
    print(f"rendered {n} bright buttons in-place (sizes preserved); backup: {BACKUP.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
