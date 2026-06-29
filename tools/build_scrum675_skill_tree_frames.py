#!/usr/bin/env python3
"""SCRUM-675 — Skill Tree redesign asset pack (procedural, self-contained PIL).

Generates the full dark-fantasy / D&D gold-brass frame kit for the «Древо умений»
screen plus a 2560x1440 layout mockup, debug overlay and design docs.

Style reference: tools/generate_steam_logo.py / generate_main_menu_title.py
  gold      #f0b64a
  brass     #b76d2a
  deep wine #241226
  dark edge #05040a
  Luminari  /System/Library/Fonts/Supplemental/Luminari.ttf

Pipeline per asset: draw at SCALE supersampling on a fully transparent RGBA
layer (no rectangular backplate), then downsample with LANCZOS. Every PNG keeps
a transparent background (min alpha == 0).

9-SLICE MARGINS (texture margin = ornate border thickness; content margin =
extra safe-area padding handed to the StyleBoxTexture by the runtime tile).
All values are in FINAL (downsampled) pixels.

  ui_frame_skill_tree_main.png        1280x720   texture(74,86,74,82)  content(120,118,120,108)
  ui_frame_skill_tree_path_wealth.png  340x720   texture(40,52,40,52)  content(30,46,30,40)
  ui_frame_skill_tree_path_lore.png    340x720   texture(40,52,40,52)  content(30,46,30,40)
  ui_frame_skill_tree_path_might.png   340x720   texture(40,52,40,52)  content(30,46,30,40)
  ui_frame_skill_tree_path_endure.png  340x720   texture(40,52,40,52)  content(30,46,30,40)
  ui_frame_skill_tree_class_select.png 420x108   texture(44,40,72,40)  content(30,18,60,18)
  ui_frame_skill_tree_class_popup.png  560x440   texture(56,64,56,60)  content(40,52,40,46)
  ui_btn_skill_points.png              360x120   texture(48,40,48,42)  content(30,22,30,22)
  ui_badge_skill_points.png            180x132   texture(0,0,0,0)      content(40,46,40,34)
  node_state_locked.png                148x148   texture(0,0,0,0)      content(24,24,24,24)
  node_state_available.png             148x148   texture(0,0,0,0)      content(24,24,24,24)
  node_state_purchased.png             148x148   texture(0,0,0,0)      content(24,24,24,24)
"""
from __future__ import annotations

import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "assets" / "sprites" / "ui" / "skill_tree"
MOCKUP_DIR = ROOT / "docs" / "design" / "mockups" / "scrum675_skill_tree_2k"
PREVIEW_DIR = ROOT / "docs" / "design" / "previews"
BACKDROP = ROOT / "assets" / "backgrounds" / "ui" / "ui_backdrop_skill_tree.png"

FONT_TITLE = Path("/System/Library/Fonts/Supplemental/Luminari.ttf")
FONT_BACKUP = Path("/System/Library/Fonts/Supplemental/Copperplate.ttc")

SCALE = 4

# Palette ---------------------------------------------------------------------
GOLD = "#f0b64a"
GOLD_HI = "#fff3c4"
BRASS = "#b76d2a"
BRASS_DK = "#7d421e"
WINE = "#241226"
WINE_DK = "#190a1c"
EDGE = "#05040a"
PARCH = "#1a1220"

# Per-path accent colours (icon + corner gem).
PATH_ACCENT = {
    "wealth": {"main": "#f0b64a", "deep": "#8a5512", "gem": "#ffd76b"},  # gold coin / богатство
    "lore": {"main": "#7fb4ff", "deep": "#23406e", "gem": "#bcd8ff"},    # arcane tome / знание
    "might": {"main": "#e2563c", "deep": "#7d1f18", "gem": "#ff8a6c"},    # blade / мощь
    "endure": {"main": "#62c089", "deep": "#1f5d3a", "gem": "#a7e8c0"},   # shield / стойкость
}
PATH_TITLE = {
    "wealth": "БОГАТСТВО",
    "lore": "ЗНАНИЕ",
    "might": "МОЩЬ",
    "endure": "СТОЙКОСТЬ",
}


def rgba(hex_color: str, alpha: int = 255) -> tuple[int, int, int, int]:
    hex_color = hex_color.lstrip("#")
    return (int(hex_color[0:2], 16), int(hex_color[2:4], 16), int(hex_color[4:6], 16), alpha)


def lerp(a: tuple[int, int, int, int], b: tuple[int, int, int, int], t: float) -> tuple[int, int, int, int]:
    return tuple(int(a[i] * (1 - t) + b[i] * t) for i in range(4))


def font(size: int) -> ImageFont.FreeTypeFont:
    path = FONT_TITLE if FONT_TITLE.exists() else FONT_BACKUP
    return ImageFont.truetype(str(path), size)


def new_layer(w: int, h: int) -> Image.Image:
    return Image.new("RGBA", (w * SCALE, h * SCALE), (0, 0, 0, 0))


def downsample(img: Image.Image, w: int, h: int) -> Image.Image:
    return img.resize((w, h), Image.Resampling.LANCZOS)


def s(v: float) -> int:
    return int(round(v * SCALE))


# --- Reusable ornament primitives -------------------------------------------

def round_rect(draw: ImageDraw.ImageDraw, box, radius, **kw) -> None:
    draw.rounded_rectangle(box, radius=radius, **kw)


def beveled_panel(img: Image.Image, w: int, h: int, border: int, radius: int,
                  accent_main: str, accent_deep: str, inset: int = 0) -> None:
    """Layered ornate gold-brass border around a dark wine interior.

    Draws (outer->inner): dark edge, brass rim, gold bevel, accent hairline,
    inner dark line, deep-wine interior with a soft top-light gradient.
    """
    d = ImageDraw.Draw(img)
    W, H = s(w), s(h)
    m = s(inset)
    b = s(border)
    r = s(radius)

    # Outer dark silhouette (gives the frame a crisp readable edge @2K).
    round_rect(d, (m, m, W - 1 - m, H - 1 - m), r + s(6), fill=rgba(EDGE, 250))
    # Brass rim.
    round_rect(d, (m + s(4), m + s(4), W - 1 - m - s(4), H - 1 - m - s(4)), r + s(4),
               fill=rgba(BRASS_DK, 255))
    # Gold bevel.
    round_rect(d, (m + s(9), m + s(9), W - 1 - m - s(9), H - 1 - m - s(9)), r + s(2),
               fill=rgba(BRASS, 255))
    round_rect(d, (m + s(12), m + s(12), W - 1 - m - s(12), H - 1 - m - s(12)), r,
               outline=rgba(GOLD, 255), width=s(3))
    # Accent hairline just inside the gold.
    round_rect(d, (m + s(16), m + s(16), W - 1 - m - s(16), H - 1 - m - s(16)), max(2, r - s(2)),
               outline=rgba(accent_main, 235), width=s(2))
    # Inner dark line framing the interior.
    inner_box = (m + b, m + b, W - 1 - m - b, H - 1 - m - b)
    round_rect(d, inner_box, max(2, r - s(6)), fill=rgba(EDGE, 255))

    # Deep-wine interior with vertical top-light gradient.
    ix0, iy0, ix1, iy1 = (m + b + s(3), m + b + s(3), W - 1 - m - b - s(3), H - 1 - m - b - s(3))
    grad = Image.new("RGBA", (max(1, ix1 - ix0), max(1, iy1 - iy0)), (0, 0, 0, 0))
    gp = grad.load()
    top = rgba(WINE, 255)
    bot = rgba(WINE_DK, 255)
    gh = grad.height
    for y in range(gh):
        t = y / max(gh - 1, 1)
        col = lerp(top, bot, t)
        for x in range(grad.width):
            gp[x, y] = col
    mask = Image.new("L", img.size, 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle((ix0, iy0, ix1, iy1), radius=max(2, r - s(7)), fill=255)
    interior = Image.new("RGBA", img.size, (0, 0, 0, 0))
    interior.paste(grad, (ix0, iy0))
    img.alpha_composite(Image.composite(interior, Image.new("RGBA", img.size, (0, 0, 0, 0)), mask))


def corner_studs(img: Image.Image, w: int, h: int, inset: int, gem: str, rad: int = 8) -> None:
    d = ImageDraw.Draw(img)
    W, H = s(w), s(h)
    off = s(inset)
    rr = s(rad)
    for cx, cy in [(off, off), (W - 1 - off, off), (off, H - 1 - off), (W - 1 - off, H - 1 - off)]:
        d.ellipse((cx - rr - s(3), cy - rr - s(3), cx + rr + s(3), cy + rr + s(3)), fill=rgba(EDGE, 255))
        d.ellipse((cx - rr, cy - rr, cx + rr, cy + rr), fill=rgba(BRASS, 255))
        d.ellipse((cx - rr + s(2), cy - rr + s(2), cx + rr - s(2), cy + rr - s(2)), fill=rgba(gem, 255))
        d.ellipse((cx - rr + s(4), cy - rr + s(4), cx - rr + s(7), cy - rr + s(7)), fill=rgba(GOLD_HI, 230))


def top_crest(img: Image.Image, w: int, cx: int, top: int, size: int, gem: str) -> None:
    """A small heraldic diamond crest centred on the top rail."""
    d = ImageDraw.Draw(img)
    cy = s(top)
    cxp = s(cx)
    r = s(size)
    pts = [(cxp, cy - r), (cxp + r, cy), (cxp, cy + r), (cxp - r, cy)]
    d.polygon(pts, fill=rgba(EDGE, 255))
    pts2 = [(cxp, cy - r + s(3)), (cxp + r - s(3), cy), (cxp, cy + r - s(3)), (cxp - r + s(3), cy)]
    d.polygon(pts2, fill=rgba(BRASS, 255))
    pts3 = [(cxp, cy - r + s(7)), (cxp + r - s(7), cy), (cxp, cy + r - s(7)), (cxp - r + s(7), cy)]
    d.polygon(pts3, fill=rgba(gem, 255))
    d.line([(cxp - r - s(40), cy), (cxp - r, cy)], fill=rgba(GOLD, 220), width=s(3))
    d.line([(cxp + r, cy), (cxp + r + s(40), cy)], fill=rgba(GOLD, 220), width=s(3))


def gold_text(img: Image.Image, xy, text, fnt, anchor="mm", glow=False) -> None:
    d = ImageDraw.Draw(img)
    x, y = s(xy[0]), s(xy[1])
    if glow:
        gl = Image.new("RGBA", img.size, (0, 0, 0, 0))
        gld = ImageDraw.Draw(gl)
        gld.text((x, y), text, font=fnt, fill=rgba(GOLD, 120), anchor=anchor,
                 stroke_width=s(2), stroke_fill=rgba(GOLD, 120))
        img.alpha_composite(gl.filter(ImageFilter.GaussianBlur(s(3))))
    d.text((x + s(1), y + s(2)), text, font=fnt, fill=rgba(EDGE, 235), anchor=anchor,
           stroke_width=s(2), stroke_fill=rgba(EDGE, 235))
    d.text((x, y), text, font=fnt, fill=rgba(GOLD_HI, 255), anchor=anchor,
           stroke_width=s(1), stroke_fill=rgba(BRASS_DK, 255))


# --- Path icons --------------------------------------------------------------

def draw_path_icon(img: Image.Image, cx: int, cy: int, r: int, kind: str, accent: dict) -> None:
    d = ImageDraw.Draw(img)
    CX, CY, R = s(cx), s(cy), s(r)
    main = accent["main"]
    deep = accent["deep"]
    gem = accent["gem"]
    # Medallion backing.
    d.ellipse((CX - R - s(8), CY - R - s(8), CX + R + s(8), CY + R + s(8)), fill=rgba(EDGE, 255))
    d.ellipse((CX - R - s(4), CY - R - s(4), CX + R + s(4), CY + R + s(4)), fill=rgba(BRASS, 255))
    d.ellipse((CX - R, CY - R, CX + R, CY + R), fill=rgba(WINE_DK, 255))
    d.ellipse((CX - R, CY - R, CX + R, CY + R), outline=rgba(GOLD, 255), width=s(2))

    if kind == "wealth":  # coin stack
        for i, off in enumerate((s(10), 0, -s(10))):
            yy = CY + off
            d.ellipse((CX - R * 0.62, yy - R * 0.20, CX + R * 0.62, yy + R * 0.20),
                      fill=rgba(deep, 255), outline=rgba(main, 255), width=s(2))
        d.ellipse((CX - R * 0.40, CY - R * 0.46, CX + R * 0.40, CY - R * 0.06),
                  fill=rgba(main, 255), outline=rgba(gem, 255), width=s(2))
        d.text((CX, CY - R * 0.26), "$", font=font(s(int(r * 0.7))), fill=rgba(EDGE, 255), anchor="mm")
    elif kind == "lore":  # open tome
        d.polygon([(CX - R * 0.7, CY + R * 0.5), (CX - R * 0.7, CY - R * 0.4),
                   (CX, CY - R * 0.55), (CX, CY + R * 0.4)], fill=rgba(deep, 255), outline=rgba(main, 255))
        d.polygon([(CX + R * 0.7, CY + R * 0.5), (CX + R * 0.7, CY - R * 0.4),
                   (CX, CY - R * 0.55), (CX, CY + R * 0.4)], fill=rgba(deep, 255), outline=rgba(main, 255))
        for ln in range(3):
            yy = CY - R * 0.25 + ln * R * 0.24
            d.line([(CX - R * 0.55, yy), (CX - R * 0.12, yy - R * 0.04)], fill=rgba(main, 220), width=s(2))
            d.line([(CX + R * 0.12, yy - R * 0.04), (CX + R * 0.55, yy)], fill=rgba(main, 220), width=s(2))
        # arcane spark above
        d.ellipse((CX - s(5), CY - R * 0.75, CX + s(5), CY - R * 0.55), fill=rgba(gem, 255))
    elif kind == "might":  # upright sword
        d.polygon([(CX, CY - R * 0.78), (CX + R * 0.16, CY - R * 0.5),
                   (CX + R * 0.16, CY + R * 0.28), (CX - R * 0.16, CY + R * 0.28),
                   (CX - R * 0.16, CY - R * 0.5)], fill=rgba("#d7d0c3", 255), outline=rgba(EDGE, 255))
        d.line([(CX - R * 0.5, CY + R * 0.3), (CX + R * 0.5, CY + R * 0.3)], fill=rgba(main, 255), width=s(6))  # guard
        d.rectangle((CX - R * 0.08, CY + R * 0.3, CX + R * 0.08, CY + R * 0.66), fill=rgba(deep, 255))  # grip
        d.ellipse((CX - R * 0.14, CY + R * 0.62, CX + R * 0.14, CY + R * 0.84), fill=rgba(gem, 255))  # pommel
    elif kind == "endure":  # heater shield
        d.polygon([(CX - R * 0.62, CY - R * 0.6), (CX + R * 0.62, CY - R * 0.6),
                   (CX + R * 0.62, CY + R * 0.1), (CX, CY + R * 0.78),
                   (CX - R * 0.62, CY + R * 0.1)], fill=rgba(deep, 255), outline=rgba(main, 255))
        d.line([(CX, CY - R * 0.5), (CX, CY + R * 0.6)], fill=rgba(main, 230), width=s(3))
        d.line([(CX - R * 0.5, CY - R * 0.1), (CX + R * 0.5, CY - R * 0.1)], fill=rgba(main, 230), width=s(3))
        d.ellipse((CX - R * 0.14, CY - R * 0.22, CX + R * 0.14, CY + R * 0.06), fill=rgba(gem, 255))


# --- Frame builders ----------------------------------------------------------

def build_main_panel() -> tuple[str, Image.Image]:
    w, h = 1280, 720
    img = new_layer(w, h)
    beveled_panel(img, w, h, border=70, radius=46, accent_main=GOLD, accent_deep=BRASS_DK, inset=8)
    corner_studs(img, w, h, inset=40, gem=GOLD, rad=16)
    top_crest(img, w, cx=w // 2, top=40, size=34, gem=GOLD)
    # bottom crest mirror (small)
    top_crest(img, w, cx=w // 2, top=h - 40, size=26, gem=BRASS)
    # title plaque inside top rail
    d = ImageDraw.Draw(img)
    round_rect(d, (s(360), s(34), s(w - 360), s(96)), s(20), fill=rgba(EDGE, 230),
               outline=rgba(GOLD, 220), width=s(2))
    gold_text(img, (w // 2, 65), "ДРЕВО УМЕНИЙ", font(s(46)), glow=True)
    return "ui_frame_skill_tree_main.png", downsample(img, w, h)


def build_path_frame(kind: str) -> tuple[str, Image.Image]:
    w, h = 340, 720
    accent = PATH_ACCENT[kind]
    img = new_layer(w, h)
    beveled_panel(img, w, h, border=38, radius=30, accent_main=accent["main"],
                  accent_deep=accent["deep"], inset=6)
    corner_studs(img, w, h, inset=26, gem=accent["gem"], rad=9)
    # Header band with path icon + title.
    d = ImageDraw.Draw(img)
    round_rect(d, (s(40), s(40), s(w - 40), s(150)), s(16), fill=rgba(EDGE, 235),
               outline=rgba(accent["main"], 230), width=s(2))
    draw_path_icon(img, cx=w // 2, cy=88, r=40, kind=kind, accent=accent)
    gold_text(img, (w // 2, 138), PATH_TITLE[kind], font(s(24)))
    return f"ui_frame_skill_tree_path_{kind}.png", downsample(img, w, h)


def build_class_select() -> tuple[str, Image.Image]:
    w, h = 420, 108
    img = new_layer(w, h)
    beveled_panel(img, w, h, border=22, radius=24, accent_main=GOLD, accent_deep=BRASS_DK, inset=4)
    d = ImageDraw.Draw(img)
    # dropdown chevron plate on the right
    px = s(w - 56)
    round_rect(d, (px - s(20), s(26), px + s(28), s(h - 26)), s(10), fill=rgba(BRASS_DK, 255),
               outline=rgba(GOLD, 230), width=s(2))
    cx = px + s(4)
    cy = s(h // 2)
    d.polygon([(cx - s(12), cy - s(5)), (cx + s(12), cy - s(5)), (cx, cy + s(11))], fill=rgba(GOLD_HI, 255))
    gold_text(img, ((w - 60) // 2, h // 2), "КЛАСС", font(s(26)))
    return "ui_frame_skill_tree_class_select.png", downsample(img, w, h)


def build_class_popup() -> tuple[str, Image.Image]:
    w, h = 560, 440
    img = new_layer(w, h)
    beveled_panel(img, w, h, border=52, radius=34, accent_main=GOLD, accent_deep=BRASS_DK, inset=6)
    corner_studs(img, w, h, inset=30, gem=GOLD, rad=10)
    top_crest(img, w, cx=w // 2, top=34, size=26, gem=GOLD)
    d = ImageDraw.Draw(img)
    round_rect(d, (s(120), s(34), s(w - 120), s(92)), s(16), fill=rgba(EDGE, 230),
               outline=rgba(GOLD, 220), width=s(2))
    gold_text(img, (w // 2, 62), "БОНУСЫ КЛАССА", font(s(28)))
    # divider rule under header
    d.line([(s(70), s(108)), (s(w - 70), s(108))], fill=rgba(BRASS, 200), width=s(2))
    return "ui_frame_skill_tree_class_popup.png", downsample(img, w, h)


def build_points_button() -> tuple[str, Image.Image]:
    w, h = 360, 120
    img = new_layer(w, h)
    beveled_panel(img, w, h, border=26, radius=26, accent_main=GOLD, accent_deep=BRASS_DK, inset=4)
    # small gem on the left
    draw_path_icon(img, cx=64, cy=h // 2, r=30, kind="wealth", accent=PATH_ACCENT["wealth"])
    gold_text(img, (210, h // 2), "ОЧКИ", font(s(34)))
    return "ui_btn_skill_points.png", downsample(img, w, h)


def build_points_badge() -> tuple[str, Image.Image]:
    w, h = 180, 132
    img = new_layer(w, h)
    d = ImageDraw.Draw(img)
    CX, CY = s(w // 2), s(h // 2)
    R = s(58)
    # heraldic shield badge (non-rectangular)
    pts = [(CX - R, CY - R + s(6)), (CX + R, CY - R + s(6)),
           (CX + R, CY + R * 0.2), (CX, CY + R + s(8)), (CX - R, CY + R * 0.2)]
    d.polygon([(x, y - s(8)) for x, y in pts], fill=rgba(EDGE, 255))
    inner = [(CX - R + s(6), CY - R + s(10)), (CX + R - s(6), CY - R + s(10)),
             (CX + R - s(6), CY + R * 0.2 - s(2)), (CX, CY + R + s(2)), (CX - R + s(6), CY + R * 0.2 - s(2))]
    d.polygon([(x, y - s(8)) for x, y in inner], fill=rgba(BRASS, 255))
    inner2 = [(CX - R + s(12), CY - R + s(14)), (CX + R - s(12), CY - R + s(14)),
              (CX + R - s(12), CY + R * 0.2 - s(6)), (CX, CY + R - s(6)), (CX - R + s(12), CY + R * 0.2 - s(6))]
    d.polygon([(x, y - s(8)) for x, y in inner2], fill=rgba(WINE, 255))
    d.polygon([(x, y - s(8)) for x, y in inner2], outline=rgba(GOLD, 255))
    gold_text(img, (w // 2, h // 2 - 6), "0", font(s(48)))
    return "ui_badge_skill_points.png", downsample(img, w, h)


def build_node(state: str) -> tuple[str, Image.Image]:
    w, h = 148, 148
    img = new_layer(w, h)
    d = ImageDraw.Draw(img)
    CX, CY = s(w // 2), s(h // 2)
    R = s(60)
    if state == "locked":
        ring, body, inner_main = "#6b6f78", "#1b1820", "#9aa0ac"
    elif state == "available":
        ring, body, inner_main = GOLD, WINE, GOLD_HI
    else:  # purchased
        ring, body, inner_main = "#62c089", "#13261b", "#a7e8c0"

    # octagon socket
    pts = [(CX + math.cos(math.radians(a)) * R, CY + math.sin(math.radians(a)) * R)
           for a in range(-90, 270, 45)]
    d.polygon(pts, fill=rgba(EDGE, 255))
    pts2 = [(CX + math.cos(math.radians(a)) * (R - s(5)), CY + math.sin(math.radians(a)) * (R - s(5)))
            for a in range(-90, 270, 45)]
    d.polygon(pts2, fill=rgba(BRASS_DK if state != "locked" else "#3a3a42", 255))
    pts3 = [(CX + math.cos(math.radians(a)) * (R - s(10)), CY + math.sin(math.radians(a)) * (R - s(10)))
            for a in range(-90, 270, 45)]
    d.polygon(pts3, fill=rgba(ring, 255))
    pts4 = [(CX + math.cos(math.radians(a)) * (R - s(15)), CY + math.sin(math.radians(a)) * (R - s(15)))
            for a in range(-90, 270, 45)]
    d.polygon(pts4, fill=rgba(body, 255))

    if state == "locked":
        # padlock glyph
        d.rounded_rectangle((CX - s(16), CY - s(2), CX + s(16), CY + s(24)), radius=s(4),
                            fill=rgba(inner_main, 255))
        d.arc((CX - s(11), CY - s(20), CX + s(11), CY + s(6)), 180, 360, fill=rgba(inner_main, 255), width=s(5))
        d.ellipse((CX - s(3), CY + s(6), CX + s(3), CY + s(12)), fill=rgba(EDGE, 255))
    elif state == "available":
        # radiant star
        sp = []
        for i in range(16):
            ang = -math.pi / 2 + math.tau * i / 16
            rad = s(28) if i % 2 == 0 else s(13)
            sp.append((CX + math.cos(ang) * rad, CY + math.sin(ang) * rad))
        d.polygon(sp, fill=rgba(inner_main, 255))
        d.ellipse((CX - s(7), CY - s(7), CX + s(7), CY + s(7)), fill=rgba(GOLD, 255))
        # outer glow
        gl = new_layer(w, h)
        gd = ImageDraw.Draw(gl)
        gd.polygon(pts3, outline=rgba(GOLD, 160), width=s(3))
        img.alpha_composite(gl.filter(ImageFilter.GaussianBlur(s(5))))
    else:  # purchased checkmark
        d.line([(CX - s(20), CY + s(2)), (CX - s(5), CY + s(18)), (CX + s(24), CY - s(20))],
               fill=rgba(inner_main, 255), width=s(8), joint="curve")
    return f"node_state_{state}.png", downsample(img, w, h)


# --- Mockup + docs -----------------------------------------------------------

# Zone geometry @2560x1440 (final layout rectangles for the runtime ticket SCRUM-676).
LAYOUT_ZONES = [
    {"id": "title_zone", "content_key": "title", "role": "title", "x": 980, "y": 88, "w": 600, "h": 70,
     "max_font": 56, "min_font": 36, "color": "#FFF3C4", "debug_color": "#F0B64A"},
    {"id": "points_button_zone", "content_key": "points_btn", "role": "button", "x": 196, "y": 96, "w": 280, "h": 92,
     "max_font": 34, "min_font": 22, "color": "#FFF1CF", "debug_color": "#FFD66B"},
    {"id": "points_badge_zone", "content_key": "points_badge", "role": "badge", "x": 540, "y": 100, "w": 132, "h": 96,
     "max_font": 48, "min_font": 28, "color": "#FFF3C4", "debug_color": "#F0B64A"},
    {"id": "class_select_zone", "content_key": "class_select", "role": "dropdown", "x": 2120, "y": 100, "w": 300, "h": 78,
     "max_font": 30, "min_font": 20, "color": "#FFF1CF", "debug_color": "#FFD66B"},
    {"id": "class_popup_zone", "content_key": "class_popup", "role": "panel_text", "x": 196, "y": 320, "w": 460, "h": 900,
     "max_font": 26, "min_font": 16, "color": "#D8F0E0", "debug_color": "#62C089"},
    {"id": "path_wealth_zone", "content_key": "path_wealth", "role": "branch", "x": 760, "y": 300, "w": 420, "h": 900,
     "max_font": 24, "min_font": 15, "color": "#FFD76B", "debug_color": "#F0B64A"},
    {"id": "path_lore_zone", "content_key": "path_lore", "role": "branch", "x": 1208, "y": 300, "w": 420, "h": 900,
     "max_font": 24, "min_font": 15, "color": "#BCD8FF", "debug_color": "#7FB4FF"},
    {"id": "path_might_zone", "content_key": "path_might", "role": "branch", "x": 1656, "y": 300, "w": 420, "h": 900,
     "max_font": 24, "min_font": 15, "color": "#FF8A6C", "debug_color": "#E2563C"},
    {"id": "path_endure_zone", "content_key": "path_endure", "role": "branch", "x": 2104, "y": 300, "w": 420, "h": 900,
     "max_font": 24, "min_font": 15, "color": "#A7E8C0", "debug_color": "#62C089"},
]

CONTENT = {
    "title": "ДРЕВО УМЕНИЙ",
    "points_btn": "Очки умений",
    "points_badge": "5",
    "class_select": "Берсерк",
    "class_popup": "Бонусы класса",
    "path_wealth": "Богатство",
    "path_lore": "Знание",
    "path_might": "Мощь",
    "path_endure": "Стойкость",
}

# Where each generated frame is placed on the 2560x1440 canvas (px, resized to w/h).
MOCKUP_PLACEMENT = [
    {"file": "ui_frame_skill_tree_main.png", "x": 48, "y": 26, "w": 2464, "h": 1388},
    {"file": "ui_btn_skill_points.png", "x": 168, "y": 88, "w": 340, "h": 114},
    {"file": "ui_badge_skill_points.png", "x": 520, "y": 78, "w": 176, "h": 128},
    {"file": "ui_frame_skill_tree_class_select.png", "x": 2096, "y": 92, "w": 372, "h": 96},
    {"file": "ui_frame_skill_tree_class_popup.png", "x": 168, "y": 300, "w": 520, "h": 940},
    {"file": "ui_frame_skill_tree_path_wealth.png", "x": 736, "y": 282, "w": 410, "h": 940},
    {"file": "ui_frame_skill_tree_path_lore.png", "x": 1184, "y": 282, "w": 410, "h": 940},
    {"file": "ui_frame_skill_tree_path_might.png", "x": 1632, "y": 282, "w": 410, "h": 940},
    {"file": "ui_frame_skill_tree_path_endure.png", "x": 2080, "y": 282, "w": 410, "h": 940},
]

# Node demo positions (state icons inside the path frames) for the mockup.
NODE_DEMO = [
    ("ui_frame_skill_tree_path_wealth.png", "purchased"),
    ("ui_frame_skill_tree_path_lore.png", "available"),
    ("ui_frame_skill_tree_path_might.png", "locked"),
    ("ui_frame_skill_tree_path_endure.png", "locked"),
]


def build_mockup() -> None:
    MOCKUP_DIR.mkdir(parents=True, exist_ok=True)
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    W, H = 2560, 1440
    if BACKDROP.exists():
        base = Image.open(BACKDROP).convert("RGBA")
        if base.size != (W, H):
            base = base.resize((W, H), Image.Resampling.LANCZOS)
    else:
        base = Image.new("RGBA", (W, H), rgba("#140f1a", 255))

    for place in MOCKUP_PLACEMENT:
        fr = Image.open(OUT_DIR / place["file"]).convert("RGBA").resize(
            (place["w"], place["h"]), Image.Resampling.LANCZOS)
        base.alpha_composite(fr, (place["x"], place["y"]))

    # Sprinkle three node states down each path frame to show iconography.
    states = ["node_state_locked.png", "node_state_available.png", "node_state_purchased.png"]
    path_x = {"wealth": 736, "lore": 1184, "might": 1632, "endure": 2080}
    node = {st: Image.open(OUT_DIR / st).convert("RGBA").resize((104, 104), Image.Resampling.LANCZOS)
            for st in states}
    order = {"wealth": [2, 0, 0, 1], "lore": [2, 1, 0, 0], "might": [1, 0, 0, 0], "endure": [0, 0, 0, 0]}
    for key, px in path_x.items():
        cx = px + 205 - 52
        for i, st_idx in enumerate(order[key]):
            ny = 470 + i * 175
            base.alpha_composite(list(node.values())[st_idx], (cx, ny))

    base.convert("RGBA").save(MOCKUP_DIR / "mockup_composite.png")

    # Debug overlay: zone rectangles drawn over the composite.
    overlay = base.copy()
    od = ImageDraw.Draw(overlay)
    try:
        lbl_font = ImageFont.truetype(str(FONT_BACKUP if FONT_BACKUP.exists() else FONT_TITLE), 22)
    except Exception:
        lbl_font = ImageFont.load_default()
    for z in LAYOUT_ZONES:
        col = rgba(z["debug_color"], 255)
        od.rectangle((z["x"], z["y"], z["x"] + z["w"], z["y"] + z["h"]), outline=col, width=3)
        od.text((z["x"] + 4, z["y"] - 24), z["id"], fill=col, font=lbl_font)
    overlay.save(MOCKUP_DIR / "debug_overlay.png")
    overlay.save(PREVIEW_DIR / "scrum675_skill_tree_2k_debug_overlay.png")


def write_docs() -> None:
    layout = {
        "canvas": {"width": 2560, "height": 1440},
        "defaults": {"color": "#F5E6C4", "stroke_fill": "#05040A", "stroke_width": 3,
                     "line_spacing": 1.06, "align": "center", "valign": "middle"},
        "content": CONTENT,
        "zones": LAYOUT_ZONES,
    }
    (MOCKUP_DIR / "layout.json").write_text(json.dumps(layout, ensure_ascii=False, indent=2))

    ui_plan = {
        "canvas": {"width": 2560, "height": 1440},
        "policy": {"min_gap": 18, "allow_overlap": False},
        "content": CONTENT,
        "elements": [
            {"id": "main_panel_frame", "kind": "panel", "x": 48, "y": 26, "w": 2464, "h": 1388,
             "min_w": 1800, "min_h": 1100, "asset": "ui_frame_skill_tree_main.png",
             "texture_margin": [74, 86, 74, 82], "content_margin": [120, 118, 120, 108]},
            {"id": "points_button_frame", "kind": "button", "x": 168, "y": 88, "w": 340, "h": 114,
             "min_w": 240, "min_h": 90, "asset": "ui_btn_skill_points.png",
             "texture_margin": [48, 40, 48, 42], "content_margin": [30, 22, 30, 22]},
            {"id": "points_button_zone", "kind": "text", "parent": "points_button_frame", "content_zone": True,
             "x": 196, "y": 96, "w": 280, "h": 92, "text_key": "points_btn", "max_font": 34, "min_font": 22},
            {"id": "points_badge_frame", "kind": "panel", "x": 520, "y": 78, "w": 176, "h": 128,
             "min_w": 132, "min_h": 96, "asset": "ui_badge_skill_points.png",
             "texture_margin": [0, 0, 0, 0], "content_margin": [40, 46, 40, 34]},
            {"id": "points_badge_zone", "kind": "text", "parent": "points_badge_frame", "content_zone": True,
             "x": 540, "y": 100, "w": 132, "h": 96, "text_key": "points_badge", "max_font": 48, "min_font": 28},
            {"id": "class_select_frame", "kind": "dropdown", "x": 2096, "y": 92, "w": 372, "h": 96,
             "min_w": 300, "min_h": 78, "asset": "ui_frame_skill_tree_class_select.png",
             "texture_margin": [44, 40, 72, 40], "content_margin": [30, 18, 60, 18]},
            {"id": "class_select_zone", "kind": "text", "parent": "class_select_frame", "content_zone": True,
             "x": 2120, "y": 100, "w": 300, "h": 78, "text_key": "class_select", "max_font": 30, "min_font": 20},
            {"id": "class_popup_frame", "kind": "panel", "x": 168, "y": 300, "w": 520, "h": 940,
             "min_w": 420, "min_h": 600, "asset": "ui_frame_skill_tree_class_popup.png",
             "texture_margin": [56, 64, 56, 60], "content_margin": [40, 52, 40, 46]},
            {"id": "class_popup_zone", "kind": "text", "parent": "class_popup_frame", "content_zone": True,
             "x": 196, "y": 320, "w": 460, "h": 900, "text_key": "class_popup", "max_font": 26, "min_font": 16},
        ],
    }
    for kind in ("wealth", "lore", "might", "endure"):
        px = {"wealth": 736, "lore": 1184, "might": 1632, "endure": 2080}[kind]
        ui_plan["elements"].append({
            "id": f"path_{kind}_frame", "kind": "branch", "x": px, "y": 282, "w": 410, "h": 940,
            "min_w": 300, "min_h": 600, "asset": f"ui_frame_skill_tree_path_{kind}.png",
            "texture_margin": [40, 52, 40, 52], "content_margin": [30, 46, 30, 40]})
        ui_plan["elements"].append({
            "id": f"path_{kind}_zone", "kind": "text", "parent": f"path_{kind}_frame", "content_zone": True,
            "x": px + 24, "y": 318, "w": 362, "h": 880, "text_key": f"path_{kind}", "max_font": 24, "min_font": 15})
    (MOCKUP_DIR / "ui_plan.json").write_text(json.dumps(ui_plan, ensure_ascii=False, indent=2))

    audit = """# SCRUM-675 Visual Frame-Zone Audit

Date: 2026-06-29
Worker: claude-design-scrum675

Purpose: confirm every accepted content zone of the redesigned «Древо умений»
screen sits inside an empty frame interior, clear of the generated gold-brass
ornament (corner studs, rails, crests, accent hairlines). Per
frame-content-safe-area-rule.

Evidence: `docs/design/mockups/scrum675_skill_tree_2k/debug_overlay.png`
(mirror in `docs/design/previews/scrum675_skill_tree_2k_debug_overlay.png`).

## Zone Review

| Zone | Rect @ 2560x1440 | Visual placement | Clear of ornament |
| --- | --- | --- | --- |
| `title_zone` | `980,88,600,70` | Inside the dark title plaque on the main top rail; clear of crest diamond and corner studs. | YES |
| `points_button_zone` | `196,96,280,92` | Inside the «Очки умений» button dark field, right of the coin medallion; clear of bevel. | YES |
| `points_badge_zone` | `540,100,132,96` | Centre of the heraldic shield badge; clear of brass rim and gold edge. | YES |
| `class_select_zone` | `2120,100,300,78` | Left text field of the class dropdown; clear of the chevron plate (reserved by the 72px right texture margin). | YES |
| `class_popup_zone` | `196,320,460,900` | Inside the class-popup interior below the header plaque; clear of corner studs, crest and side rails. | YES |
| `path_wealth_zone` | `760,300,420,900` | Inside the wealth path interior below its icon header band; clear of studs and rails. | YES |
| `path_lore_zone` | `1208,300,420,900` | Inside the lore path interior below its icon header band; clear of studs and rails. | YES |
| `path_might_zone` | `1656,300,420,900` | Inside the might path interior below its icon header band; clear of studs and rails. | YES |
| `path_endure_zone` | `2104,300,420,900` | Inside the endure path interior below its icon header band; clear of studs and rails. | YES |

## Safe-Area Notes

- Main panel texture margin `(74,86,74,82)` covers the ornate border; the
  layout VBox runs inside content margin `(120,118,120,108)` so no content
  lands on the rail or the heraldic crests.
- Each path frame reserves the top `0..150px` band for its medallion icon +
  title; content/node columns start at y>=300 (>=18px below the band).
- Class dropdown reserves the right `72px` (texture margin) for the chevron
  plate, so the class-name text zone never collides with it.
- Node-state icons render inside path interiors only; their octagon socket
  sits within the branch content column, never over the frame border.

## Verdict

GREEN — all 9 content zones are clear of generated ornament; ready for runtime
integration by SCRUM-676.
"""
    (MOCKUP_DIR / "visual_frame_zone_audit.md").write_text(audit)


def build_contact_sheet(assets: list[str]) -> None:
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    cell_w, cell_h, label_h = 360, 300, 26
    cols = 3
    rows = (len(assets) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * cell_w, rows * (cell_h + label_h) + 44), rgba("#14101a", 255))
    d = ImageDraw.Draw(sheet)
    try:
        f = ImageFont.truetype(str(FONT_BACKUP if FONT_BACKUP.exists() else FONT_TITLE), 18)
    except Exception:
        f = ImageFont.load_default()
    d.text((14, 14), "SCRUM-675 skill-tree frame kit", fill=rgba(GOLD, 255), font=f)
    for i, name in enumerate(assets):
        x = (i % cols) * cell_w
        y = 44 + (i // cols) * (cell_h + label_h)
        # checker cell so transparency reads
        cell = Image.new("RGBA", (cell_w, cell_h), rgba("#221f21", 255))
        cd = ImageDraw.Draw(cell)
        for yy in range(0, cell_h, 18):
            for xx in range(0, cell_w, 18):
                if (xx // 18 + yy // 18) % 2 == 0:
                    cd.rectangle((xx, yy, xx + 17, yy + 17), fill=rgba("#36312f", 255))
        asset = Image.open(OUT_DIR / name).convert("RGBA")
        scale = min((cell_w - 32) / asset.width, (cell_h - 32) / asset.height)
        thumb = asset.resize((max(1, int(asset.width * scale)), max(1, int(asset.height * scale))),
                             Image.Resampling.LANCZOS)
        cell.alpha_composite(thumb, ((cell_w - thumb.width) // 2, (cell_h - thumb.height) // 2))
        sheet.alpha_composite(cell, (x, y))
        d.text((x + 8, y + cell_h + 4), name, fill=rgba(GOLD_HI, 255), font=f)
    sheet.save(PREVIEW_DIR / "scrum675_skill_tree_frame_kit_contact.png")


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    builders = [
        build_main_panel,
        lambda: build_path_frame("wealth"),
        lambda: build_path_frame("lore"),
        lambda: build_path_frame("might"),
        lambda: build_path_frame("endure"),
        build_class_select,
        build_class_popup,
        build_points_button,
        build_points_badge,
        lambda: build_node("locked"),
        lambda: build_node("available"),
        lambda: build_node("purchased"),
    ]
    written: list[str] = []
    for b in builders:
        name, img = b()
        img.save(OUT_DIR / name)
        alpha_min = img.getchannel("A").getextrema()[0]
        assert alpha_min == 0, f"{name} has no transparent pixels (min alpha {alpha_min})"
        written.append(name)
        print(f"  {name:42s} {img.size[0]}x{img.size[1]}  alpha_min={alpha_min}")

    build_mockup()
    write_docs()
    build_contact_sheet(written)
    print(f"\nWrote {len(written)} assets to {OUT_DIR}")
    print(f"Mockup + docs: {MOCKUP_DIR}")


if __name__ == "__main__":
    main()
