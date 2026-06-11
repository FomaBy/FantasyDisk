#!/usr/bin/env python3
"""Slice the user's artifact concept sheet (7x7) into per-artifact icons. v2

Алгоритм на плитку:
1. Фон оценивается по рамке плитки (медианный цвет).
2. Кандидаты в фон: близкие к фону пиксели; затем BFS от границы — фоном
   считается только связанная с границей область (тёмные части предмета,
   отделённые контуром, не выедаются).
3. Мелкие островки переднего плана (брызги фона) удаляются.
4. Если после вырезки от предмета осталось < 16% плитки — предмет тёмный и
   слился с фоном; fallback: «медальон» (вся плитка под мягкой скруглённой маской).
5. Яркость/контраст/насыщенность повышаются, предмет масштабируется на 256x256.
"""
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter
from collections import deque
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHEET = os.path.join(ROOT, "assets/reference/artifact_concept_sheet.png")
OUT_DIR = os.path.join(ROOT, "assets/sprites/ui/icons/artifacts")
PREVIEW = os.path.join(ROOT, "assets/sprites/ui/icons/artifact_concept_cut_preview.png")

COLS = ROWS = 7
CANVAS = 256
MAX_SIDE = 240
INSET = 7
BG_DIST = 40          # порог близости к цвету фона
MIN_ISLAND = 140       # минимальный островок переднего плана, px
MIN_COVERAGE = 0.10   # ниже — считаем вырезку неудачной, медальон

MAPPING = {
    (1, 1): "warrior_charm",   (1, 2): "fox_boots",      (1, 3): "glass_orb",
    (1, 4): "hawk_lens",       (1, 5): "ember_core",     (1, 6): "old_codex",
    (1, 7): "stone_heart",
    (2, 1): "banner_seed",     (2, 2): "red_whetstone",  (2, 3): "star_compass",
    (2, 4): "living_root",     (2, 5): "captains_coin",  (2, 6): "quickstring",
    (2, 7): "heavy_totem",
    (3, 1): "splinter_gloves", (3, 2): "wide_sigil",     (3, 3): "swift_ink",
    (3, 4): "summoners_bell",  (3, 5): "blood_sigil",    (3, 6): "void_ink",
    (3, 7): "echo_pick",
    (4, 1): "sturdy_amulet",   (4, 2): "fast_boots",     (4, 3): "magnetic_buckle",
    (4, 4): "silver_coin",     (4, 5): "survival_manual",(4, 6): "cracked_shield",
    (4, 7): "sharp_talisman",
    (5, 1): "jagged_blade",    (5, 2): "heavy_grip",     (5, 3): "war_belt",
    (5, 4): "warriors_rage",   (5, 5): "dark_crystal",   (5, 6): "ash_page",
    (5, 7): "skull_resonator",
    (6, 1): "ink_candle",      (6, 2): "copper_string",  (6, 3): "broken_pick",
    (6, 4): "loud_amp",        (6, 5): "bass_cable",     (6, 6): "cursed_crown",
    (6, 7): "fragile_heart",
    (7, 1): "greedy_purse",    (7, 2): "burning_shard",  (7, 3): "golden_route_mark",
    (7, 4): "glass_edge",      (7, 5): "echo_core",      (7, 6): "split_core",
    (7, 7): "blood_pact",
}
FORCED_MEDALLION = {
    # тёмные/слитые с фоном предметы — авто-вырезка их разрушает (проверено визуально)
    "ink_candle", "cursed_crown", "bass_cable", "war_belt", "heavy_grip",
    "banner_seed", "quickstring", "heavy_totem", "fast_boots",
    "magnetic_buckle", "cracked_shield", "sharp_talisman", "jagged_blade",
    "splinter_gloves", "loud_amp", "greedy_purse",
}


def cut_tile(sheet, row, col):
    w, h = sheet.size
    x0 = round((col - 1) * w / COLS) + INSET
    x1 = round(col * w / COLS) - INSET
    y0 = round((row - 1) * h / ROWS) + INSET
    y1 = round(row * h / ROWS) - INSET
    return sheet.crop((x0, y0, x1, y1)).convert("RGB")


def median_border_color(px, w, h, ring=5):
    rs, gs, bs = [], [], []
    for y in range(h):
        for x in range(w):
            if x < ring or x >= w - ring or y < ring or y >= h - ring:
                r, g, b = px[x, y]
                rs.append(r); gs.append(g); bs.append(b)
    rs.sort(); gs.sort(); bs.sort()
    m = len(rs) // 2
    return rs[m], gs[m], bs[m]


def segment(tile):
    """Возвращает (alpha-маска как set фоновых пикселей, coverage)."""
    w, h = tile.size
    px = tile.load()
    br, bg_, bb = median_border_color(px, w, h)

    def is_bgish(x, y):
        r, g, b = px[x, y]
        return abs(r - br) + abs(g - bg_) + abs(b - bb) < BG_DIST * 3 // 1 and \
            max(abs(r - br), abs(g - bg_), abs(b - bb)) < BG_DIST

    # BFS фона от границы
    bg_mask = bytearray(w * h)
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if is_bgish(x, y) and not bg_mask[y * w + x]:
                bg_mask[y * w + x] = 1
                q.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if is_bgish(x, y) and not bg_mask[y * w + x]:
                bg_mask[y * w + x] = 1
                q.append((x, y))
    while q:
        x, y = q.popleft()
        for nx, ny in ((x+1, y), (x-1, y), (x, y+1), (x, y-1)):
            if 0 <= nx < w and 0 <= ny < h and not bg_mask[ny * w + nx] and is_bgish(nx, ny):
                bg_mask[ny * w + nx] = 1
                q.append((nx, ny))

    # удаляем мелкие островки переднего плана
    seen = bytearray(w * h)
    for y0 in range(h):
        for x0 in range(w):
            i0 = y0 * w + x0
            if bg_mask[i0] or seen[i0]:
                continue
            comp = [(x0, y0)]
            seen[i0] = 1
            qq = deque(comp)
            while qq:
                x, y = qq.popleft()
                for nx, ny in ((x+1, y), (x-1, y), (x, y+1), (x, y-1)):
                    j = ny * w + nx
                    if 0 <= nx < w and 0 <= ny < h and not bg_mask[j] and not seen[j]:
                        seen[j] = 1
                        comp.append((nx, ny))
                        qq.append((nx, ny))
            xs = [c[0] for c in comp]; ys = [c[1] for c in comp]
            strip = 26
            in_edge_strip = (max(ys) < strip or min(ys) >= h - strip or
                             max(xs) < strip or min(xs) >= w - strip)
            touches_edge = min(xs) <= 1 or max(xs) >= w - 2 or min(ys) <= 1 or max(ys) >= h - 2
            if len(comp) < MIN_ISLAND or in_edge_strip or (touches_edge and len(comp) < 800):
                for x, y in comp:
                    bg_mask[y * w + x] = 1

    fg = sum(1 for v in bg_mask if not v)
    return bg_mask, fg / (w * h)


def apply_alpha(tile, bg_mask):
    w, h = tile.size
    rgba = tile.convert("RGBA")
    alpha = Image.new("L", (w, h), 255)
    ap = alpha.load()
    for y in range(h):
        base = y * w
        for x in range(w):
            if bg_mask[base + x]:
                ap[x, y] = 0
    alpha = alpha.filter(ImageFilter.GaussianBlur(1.0))
    alpha = alpha.point(lambda a: 0 if a < 80 else min(255, int(a * 1.2)))
    rgba.putalpha(alpha)
    return rgba


def medallion(tile):
    """Fallback: вся плитка под скруглённой маской с мягким краем."""
    w, h = tile.size
    mask = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(mask)
    d.rounded_rectangle((2, 2, w - 3, h - 3), radius=min(w, h) // 4, fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(3))
    rgba = tile.convert("RGBA")
    rgba.putalpha(mask)
    return rgba


def enhance(rgba):
    rgb = rgba.convert("RGB")
    rgb = ImageEnhance.Brightness(rgb).enhance(1.18)
    rgb = ImageEnhance.Contrast(rgb).enhance(1.28)
    rgb = ImageEnhance.Color(rgb).enhance(1.25)
    out = rgb.convert("RGBA")
    out.putalpha(rgba.getchannel("A"))
    return out


def compose(rgba):
    bbox = rgba.getchannel("A").getbbox()
    if bbox:
        rgba = rgba.crop(bbox)
    scale = MAX_SIDE / max(rgba.size)
    rgba = rgba.resize((max(1, round(rgba.width * scale)),
                        max(1, round(rgba.height * scale))), Image.LANCZOS)
    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    canvas.paste(rgba, ((CANVAS - rgba.width) // 2, (CANVAS - rgba.height) // 2), rgba)
    return canvas


def main():
    sheet = Image.open(SHEET)
    fallbacks = []
    for (row, col), art_id in sorted(MAPPING.items()):
        tile = cut_tile(sheet, row, col)
        bg_mask, coverage = segment(tile)
        if art_id in FORCED_MEDALLION or coverage < MIN_COVERAGE:
            rgba = medallion(tile)
            fallbacks.append(f"{art_id} (coverage {coverage:.2f})")
        else:
            rgba = apply_alpha(tile, bg_mask)
        icon = compose(enhance(rgba))
        icon.save(os.path.join(OUT_DIR, f"artifact_{art_id}.png"))
    # контрольный лист на шахматном фоне
    cell = 128
    prev = Image.new("RGB", (COLS * cell, ROWS * cell), (40, 40, 48))
    checker = Image.new("RGB", (cell, cell), (60, 60, 70))
    d = ImageDraw.Draw(checker)
    for cy in range(0, cell, 16):
        for cx in range(0, cell, 16):
            if (cx // 16 + cy // 16) % 2 == 0:
                d.rectangle((cx, cy, cx + 15, cy + 15), fill=(46, 46, 56))
    for (row, col), art_id in sorted(MAPPING.items()):
        icon = Image.open(os.path.join(OUT_DIR, f"artifact_{art_id}.png")).resize((cell, cell), Image.LANCZOS)
        base = checker.copy()
        base.paste(icon, (0, 0), icon)
        prev.paste(base, ((col - 1) * cell, (row - 1) * cell))
    prev.save(PREVIEW)
    print(f"done: {len(MAPPING)}; medallion fallbacks: {len(fallbacks)}")
    for f in fallbacks:
        print("  -", f)


if __name__ == "__main__":
    main()
