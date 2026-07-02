#!/usr/bin/env python3
"""SCRUM-686 Hero Select PixelLab-first rebuild compositor.

Assembles the PixelLab production frames into the canonical 2560x1440 layout and
demonstrates live 512x512 PixelLab character placement (Berserk + Dark Mage) inside
the portrait safe box without overlapping frame ornament.

Outputs:
  docs/design/previews/scrum_hero_select_pixellab_rebuild_mockup.png   (Berserk variant, clean)
  docs/design/previews/scrum_hero_select_pixellab_rebuild_debug.png    (zones + both sprites + markers)
"""
import json
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = "/Users/sergeyfomin/Documents/AI Agent"
FR = os.path.join(ROOT, "assets/sprites/ui/frames/hero_select_pixellab")
CH = os.path.join(ROOT, "assets/sprites/characters/full_frame")
PREV = os.path.join(ROOT, "docs/design/previews")

CANVAS = (2560, 1440)

# --- Frame placements (top-left x,y) on the 2560x1440 canvas ---
FRAMES = {
    "background":     (0, 0,        "background.png"),
    "frame_title":    (360, 28,     "frame_title.png"),
    "button_back":    (48, 48,      "button_back.png"),
    "frame_portrait": (90, 240,     "frame_portrait.png"),
    "frame_dossier":  (770, 240,    "frame_dossier.png"),
    "frame_radar":    (1762, 240,   "frame_radar.png"),
    "frame_ascension":(1762, 790,   "frame_ascension.png"),
    "button_choose":  (1004, 838,   "button_choose.png"),
    "frame_carousel": (64, 1086,    "frame_carousel.png"),
    "button_carousel_left":  (174, 1169,  "button_carousel_left.png"),
    "button_carousel_right": (2254, 1169, "button_carousel_right.png"),
    "button_asc_minus": (1836, 920, "button_asc_minus.png"),
    "button_asc_plus":  (2336, 920, "button_asc_plus.png"),
}

# Interior content margins (left, top, w, h) within each frame -> screen content rect
INTERIOR = {
    "frame_title":    (120, 42, 1600, 96),
    "button_back":    (70, 38, 320, 72),
    "frame_portrait": (72, 94, 456, 620),
    "frame_dossier":  (92, 84, 796, 640),
    "frame_radar":    (98, 57, 584, 406),
    "frame_ascension":(74, 50, 632, 183),
    "frame_carousel": (110, 61, 2212, 220),
}

# Portrait sprite display rule
PORTRAIT_BOX = None  # filled below from frame_portrait interior
SPRITE_SCALE = 2.45
FEET_NX, FEET_NY = 0.50, 0.94  # feet anchor normalized in the display box


def content_rect(frame_id):
    fx, fy, _ = FRAMES[frame_id]
    il, it, iw, ih = INTERIOR[frame_id]
    return (fx + il, fy + it, iw, ih)


def place_sprite(canvas, sprite_path, box):
    """Place a 512x512 PixelLab frame in box=(x,y,w,h), feet-anchored, scaled."""
    im = Image.open(sprite_path).convert("RGBA")
    bbox = im.getbbox()
    vis = im.crop(bbox)
    vw, vh = vis.size
    dw, dh = int(round(vw * SPRITE_SCALE)), int(round(vh * SPRITE_SCALE))
    vis = vis.resize((dw, dh), Image.NEAREST)
    bx, by, bw, bh = box
    feet_x = bx + FEET_NX * bw
    feet_y = by + FEET_NY * bh
    px = int(round(feet_x - dw / 2))
    py = int(round(feet_y - dh))
    canvas.alpha_composite(vis, (px, py))
    return (px, py, dw, dh)


def main():
    base = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    for fid, (x, y, fn) in FRAMES.items():
        p = os.path.join(FR, fn)
        im = Image.open(p).convert("RGBA")
        base.alpha_composite(im, (x, y))

    global PORTRAIT_BOX
    PORTRAIT_BOX = content_rect("frame_portrait")

    # ---- Clean mockup: Berserk south in portrait ----
    mock = base.copy()
    place_sprite(mock, os.path.join(CH, "berserk_pixellab/berserk_idle_south.png"), PORTRAIT_BOX)
    mock.convert("RGB").save(os.path.join(PREV, "scrum_hero_select_pixellab_rebuild_mockup.png"))

    # ---- Debug overlay: zones + both sprites + markers ----
    dbg = base.copy()
    d_berserk = place_sprite(dbg, os.path.join(CH, "berserk_pixellab/berserk_idle_south.png"), PORTRAIT_BOX)
    draw = ImageDraw.Draw(dbg, "RGBA")
    # outline every content safe zone in cyan
    for fid in INTERIOR:
        cx, cy, cw, ch = content_rect(fid)
        draw.rectangle([cx, cy, cx + cw, cy + ch], outline=(0, 255, 255, 220), width=3)
    # portrait display box in yellow, feet anchor cross in red
    bx, by, bw, bh = PORTRAIT_BOX
    draw.rectangle([bx, by, bx + bw, by + bh], outline=(255, 220, 0, 255), width=4)
    fx_a = bx + FEET_NX * bw
    fy_a = by + FEET_NY * bh
    draw.line([fx_a - 24, fy_a, fx_a + 24, fy_a], fill=(255, 0, 0, 255), width=4)
    draw.line([fx_a, fy_a - 24, fx_a, fy_a + 24], fill=(255, 0, 0, 255), width=4)
    draw.rectangle([d_berserk[0], d_berserk[1], d_berserk[0] + d_berserk[2], d_berserk[1] + d_berserk[3]],
                   outline=(0, 255, 0, 200), width=2)
    # Dark Mage south overlaid (semi-transparent) to prove both fit the same box
    dm = Image.open(os.path.join(CH, "dark_mage_pixellab/dark_mage_idle_south.png")).convert("RGBA")
    dmb = dm.getbbox(); dmv = dm.crop(dmb)
    dvw = int(round((dmb[2]-dmb[0]) * SPRITE_SCALE)); dvh = int(round((dmb[3]-dmb[1]) * SPRITE_SCALE))
    dmv = dmv.resize((dvw, dvh), Image.NEAREST)
    a = dmv.split()[3].point(lambda v: int(v * 0.55)); dmv.putalpha(a)
    dpx = int(round(fx_a - dvw/2)); dpy = int(round(fy_a - dvh))
    dbg.alpha_composite(dmv, (dpx, dpy))
    draw.rectangle([dpx, dpy, dpx+dvw, dpy+dvh], outline=(255, 0, 255, 200), width=2)
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 26)
    except Exception:
        font = ImageFont.load_default()
    draw.text((bx, by - 34), "PORTRAIT DISPLAY BOX (yellow)  green=Berserk magenta=DarkMage  red=feet anchor",
              fill=(255, 255, 255, 255), font=font)
    dbg.convert("RGB").save(os.path.join(PREV, "scrum_hero_select_pixellab_rebuild_debug.png"))

    # ---- Emit placement summary for the spec ----
    summary = {
        "berserk_south_display": {"x": d_berserk[0], "y": d_berserk[1], "w": d_berserk[2], "h": d_berserk[3]},
        "dark_mage_south_display": {"x": dpx, "y": dpy, "w": dvw, "h": dvh},
        "portrait_box": {"x": bx, "y": by, "w": bw, "h": bh},
        "feet_anchor": {"x": int(fx_a), "y": int(fy_a)},
        "scale": SPRITE_SCALE,
    }
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
