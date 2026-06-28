"""SCRUM-485: рисующий скрипт UI-рамок @2K по координатной спеке.

Пайплайн `координаты-константы → скрипт → ассеты → верификация`:
читает слотовые `*_2K`-координаты (`Rect2(x,y,w,h)`) из `scripts/ui_screens.gd`
и `scripts/pause_stats_menu.gd`, и для КАЖДОГО панельного/кнопочного слота рисует
9-slice-safe frame-ассет РОВНО в пиксельный размер слота @2560×1440. Орнамент
(бордюр, угловые L-скобки, акценты) рисуется ТОЛЬКО внутри margin-band (нативные
9-slice бордюры из `UIThemePaths`), плоская середина — ровный вертикальный градиент,
поэтому при рантайм-9-slice тянется только центр, а орнамент не искажается.

Размерная политика: рисуем ассет ровно в `w×h` слота @2K с НАТИВНЫМИ 9-slice
бордюрами → ratio бордюр/размер корректен по построению; рантайм потом юниформ-
скейлит ассет целиком под 1080p/4K (`stretch=keep`), aspect сохраняется.

Источник правды — координаты в `.gd`. Слоты прописаны плоским словарём в этом
скрипте, но перед генерацией сверяются с `.gd`-константами (ANTI-DRIFT GUARD):
при расхождении размеров/маргинов скрипт падает с понятной ошибкой, а не молча
генерит устаревшее. Детерминирован (без `random`).

Запуск из корня репо:
  python3 tools/build_ui_2k_frame_kit.py            # генерация ассетов + контактный лист
  python3 tools/build_ui_2k_frame_kit.py --verify   # рендер-верификатор (exit!=0 при FAIL)
  python3 tools/build_ui_2k_frame_kit.py --all       # сгенерить и сразу верифицировать
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
UI_SCREENS = ROOT / "scripts/ui_screens.gd"
PAUSE_STATS = ROOT / "scripts/pause_stats_menu.gd"
THEME_PATHS = ROOT / "scripts/ui/ui_theme_paths.gd"
OUT_DIR = ROOT / "assets/sprites/ui/frames/overhaul_2k"
CONTACT_SHEET = ROOT / "docs/design/previews/ui_2k_frame_kit_contact.png"

# --- стиль (тот же bright-минимал, что в tools/render_bright_frames.py) --------
AMBER = (228, 170, 52)
ACCENT = (245, 196, 96)
FILL_TOP = (34, 31, 27)
FILL_BOT = (24, 22, 19)
FILL_ALPHA = 214

# Шаблонная высота для слотов с динамической высотой (h=0 в .gd — h по контенту).
DYNAMIC_TEMPLATE_HEIGHT = {"st_panel": 220}

# --- слотовая спека: slug → источник координат + тип рамки --------------------
# kind: тип рамки (для frame-маргинов) или "button" (button-маргины).
# margin_key: ключ в MINIMAL_METAL_FRAME_TEXTURE_MARGINS / MINIMAL_METAL_BUTTON_MARGINS.
# expect_w/h: ожидаемый размер слота (сверяется с .gd; h=None → динамическая высота).
SLOTS = [
    # панели/модалки/тултипы (frame-маргины)
    {"slug": "qc_panel", "file": "ui_screens", "const": "QC_PANEL_2K", "kind": "frame", "margin_key": "panel", "w": 600, "h": 340},
    {"slug": "cr_panel", "file": "ui_screens", "const": "CR_PANEL_2K", "kind": "frame", "margin_key": "panel", "w": 680, "h": 380},
    {"slug": "pm_panel", "file": "ui_screens", "const": "PM_PANEL_2K", "kind": "frame", "margin_key": "panel", "w": 898, "h": 820},
    {"slug": "fb_panel", "file": "ui_screens", "const": "FB_PANEL_2K", "kind": "frame", "margin_key": "panel", "w": 940, "h": 780},
    {"slug": "pd_panel", "file": "pause_stats", "const": "PD_PANEL_2K", "kind": "frame", "margin_key": "modal", "w": 2520, "h": 1404},
    {"slug": "gt_panel", "file": "ui_screens", "const": "GT_PANEL_2K", "kind": "frame", "margin_key": "tooltip", "w": 460, "h": 140},
    {"slug": "st_panel", "file": "pause_stats", "const": "ST_PANEL_2K", "kind": "frame", "margin_key": "tooltip", "w": 430, "h": None},
    # SCRUM-565 (Событие): панель события (economy-panel слот) + карточка выбора.
    # Hover переиспользует evt_card с нейтральным рантайм-тинтом (как economy-карты
    # переиспользуют base card-арт под hover) — отдельный идентичный PNG не нужен.
    {"slug": "evt_panel", "file": "ui_screens", "const": "EVT_PANEL_2K", "kind": "frame", "margin_key": "panel", "w": 1720, "h": 780},
    {"slug": "evt_card", "file": "ui_screens", "const": "EVT_CARD_2K", "kind": "frame", "margin_key": "card", "w": 480, "h": 340},
    # SCRUM-573 (Улучшение): per-слот @2K-рамка панели улучшения (economy-panel "upgrade").
    # Карточки выбора переиспользуют общий economy-choice-арт (как остальные economy-экраны).
    {"slug": "upgrade_panel", "file": "ui_screens", "const": "UPGRADE_PANEL_2K", "kind": "frame", "margin_key": "panel", "w": 1720, "h": 730},
    # SCRUM-578 (Смерть): per-слот @2K-рамка end-модалки результата (RESULT_PANEL_2K 898×820,
    # pause-end-модалка). Геометрия общая с победой; здесь редизайнится только путь смерти.
    {"slug": "result_panel", "file": "ui_screens", "const": "RESULT_PANEL_2K", "kind": "frame", "margin_key": "modal", "w": 898, "h": 820},
    # SCRUM-581 (Подтверждение выхода): свежий @2K-фрейм модалки с modal-профилем (более
    # ornate бордюр, befitting confirm-диалога) поверх QC_PANEL_2K 600×340. SCRUM-486
    # держал qc_panel на panel-профиле (общий с меню/нав) — qc_modal даёт диалогу свою рамку.
    {"slug": "qc_modal", "file": "ui_screens", "const": "QC_PANEL_2K", "kind": "frame", "margin_key": "modal", "w": 600, "h": 340},
    # боевой HUD-блок (SCRUM-564, эпик SCRUM-481): per-слот @2K-рамки из CHUD_*_2K.
    # Тонкие горизонтальные стрипы → margin-профили hud_resource/hud_timer/hud_artifact.
    {"slug": "chud_resource_panel", "file": "ui_screens", "const": "CHUD_RESOURCE_PANEL_2K", "kind": "frame", "margin_key": "hud_resource", "w": 820, "h": 84},
    {"slug": "chud_timer", "file": "ui_screens", "const": "CHUD_TIMER_2K", "kind": "frame", "margin_key": "hud_timer", "w": 288, "h": 96},
    {"slug": "chud_artifact_row", "file": "ui_screens", "const": "CHUD_ARTIFACT_ROW_2K", "kind": "frame", "margin_key": "hud_artifact", "w": 402, "h": 104},
    # SCRUM-589: combat title banner, with narrow frame margins so runtime text stays in the safe zone.
    {"slug": "ctb_big", "file": "ui_screens", "const": "CTB_BIG_2K", "kind": "frame", "margin_key": "combat_title_big", "w": 2360, "h": 90},
    {"slug": "ctb_small", "file": "ui_screens", "const": "CTB_SMALL_2K", "kind": "frame", "margin_key": "combat_title_small", "w": 2360, "h": 56},
    {"slug": "hs4_portrait_panel", "file": "ui_screens", "const": "HS4_PORTRAIT_FRAME_2K", "kind": "frame", "margin_key": "panel", "w": 661, "h": 959},
    {"slug": "hs4_dossier_panel", "file": "ui_screens", "const": "HS4_DOSSIER_2K", "kind": "frame", "margin_key": "panel", "w": 1091, "h": 959},
    {"slug": "hs4_radar_panel", "file": "ui_screens", "const": "HS4_RADAR_2K", "kind": "frame", "margin_key": "panel", "w": 624, "h": 959},
    {"slug": "hs4_carousel_panel", "file": "ui_screens", "const": "HS4_CAROUSEL_2K", "kind": "frame", "margin_key": "hud_strip", "w": 2448, "h": 245},
    # SCRUM-568 (Докача/атрибут-шоп): высокая панель full-height. Карточки опций
    # (ATTR_OFFER_2K 480×340) переиспользуют evt_card-рамку (тот же размер/тип card).
    {"slug": "attr_panel", "file": "ui_screens", "const": "ATTR_PANEL_2K", "kind": "frame", "margin_key": "panel", "w": 1124, "h": 1384},
    # SCRUM-576 (Что нового/патч-ноуты): полноэкранная панель-фрейм (как skill-tree main).
    {"slug": "pn_panel", "file": "ui_screens", "const": "PN_PANEL_2K", "kind": "frame", "margin_key": "panel", "w": 2464, "h": 1388},
    # кнопки (button-маргины)
    {"slug": "hs4_choose_btn", "file": "ui_screens", "const": "HS4_CHOOSE_BTN_2K", "kind": "button", "margin_key": "hero_confirm", "w": 512, "h": 89},
    {"slug": "hs4_asc_btn", "file": "ui_screens", "const": "HS4_ASC_BTN_2K", "kind": "button", "margin_key": "utility", "w": 102, "h": 72},
    {"slug": "mm_btn", "file": "ui_screens", "const": "MM_BTN_START_2K", "kind": "button", "margin_key": "main_menu", "w": 380, "h": 104},
    {"slug": "qc_btn", "file": "ui_screens", "const": "QC_BTN_EXIT_2K", "kind": "button", "margin_key": "standard", "w": 220, "h": 72},
    {"slug": "cr_btn", "file": "ui_screens", "const": "CR_BTN_CONTINUE_2K", "kind": "button", "margin_key": "standard", "w": 240, "h": 72},
    {"slug": "pm_btn", "file": "ui_screens", "const": "PM_BTN_CONTINUE_2K", "kind": "button", "margin_key": "pause", "w": 280, "h": 60},
    {"slug": "fb_btn_send", "file": "ui_screens", "const": "FB_BTN_SEND_2K", "kind": "button", "margin_key": "standard", "w": 260, "h": 64},
    {"slug": "fb_btn_cancel", "file": "ui_screens", "const": "FB_BTN_CANCEL_2K", "kind": "button", "margin_key": "standard", "w": 220, "h": 64},
    {"slug": "pd_btn", "file": "pause_stats", "const": "PD_BTN_2K", "kind": "button", "margin_key": "pause", "w": 280, "h": 60},
]

GD_FILE = {"ui_screens": UI_SCREENS, "pause_stats": PAUSE_STATS}


# --- парсеры .gd (источник правды) --------------------------------------------
def parse_rect2(gd_file: Path, const_name: str):
    """Вернуть (x,y,w,h) для `const <name> := Rect2(...)` из .gd; None если нет."""
    text = gd_file.read_text(encoding="utf-8")
    m = re.search(r"const\s+" + re.escape(const_name) + r"\s*:=\s*Rect2\(([-\d.,\s]+)\)", text)
    if not m:
        return None
    nums = [float(p) for p in m.group(1).split(",")]
    return tuple(nums[:4])


def parse_vector4_dict(gd_file: Path, dict_name: str):
    """Вернуть {key: (l,t,r,b)} для `const <dict> := { "k": Vector4(...), ... }`."""
    text = gd_file.read_text(encoding="utf-8")
    m = re.search(r"const\s+" + re.escape(dict_name) + r"\s*:=\s*\{(.*?)\n\}", text, re.S)
    if not m:
        return {}
    out = {}
    for key, vals in re.findall(r'"(\w+)"\s*:\s*Vector4\(([-\d.,\s]+)\)', m.group(1)):
        nums = [float(p) for p in vals.split(",")]
        out[key] = tuple(int(round(n)) for n in nums[:4])
    return out


def load_margins():
    """9-slice бордюры (l,t,r,b) из ui_theme_paths.gd для frame и button типов."""
    frame = parse_vector4_dict(THEME_PATHS, "MINIMAL_METAL_FRAME_TEXTURE_MARGINS")
    button = parse_vector4_dict(THEME_PATHS, "MINIMAL_METAL_BUTTON_MARGINS")
    if not frame or not button:
        raise SystemExit("ANTI-DRIFT: не удалось распарсить маргины из ui_theme_paths.gd")
    return frame, button


def resolve_slot(slot, frame_margins, button_margins):
    """Сверить размер слота с .gd (anti-drift) и вернуть (w, h, margins)."""
    rect = parse_rect2(GD_FILE[slot["file"]], slot["const"])
    if rect is None:
        raise SystemExit(f"ANTI-DRIFT: константа {slot['const']} не найдена в {slot['file']}.gd")
    _, _, gd_w, gd_h = rect
    if int(gd_w) != int(slot["w"]):
        raise SystemExit(
            f"ANTI-DRIFT: ширина {slot['const']} в .gd ({int(gd_w)}) != спеке скрипта ({slot['w']}). "
            f"Слот переехал — обнови SLOTS в build_ui_2k_frame_kit.py.")
    if slot["h"] is not None and int(gd_h) != int(slot["h"]):
        raise SystemExit(
            f"ANTI-DRIFT: высота {slot['const']} в .gd ({int(gd_h)}) != спеке скрипта ({slot['h']}).")
    # высота: динамическая (h=None) → шаблонная
    h = slot["h"] if slot["h"] is not None else DYNAMIC_TEMPLATE_HEIGHT[slot["slug"]]
    margins = (button_margins if slot["kind"] == "button" else frame_margins).get(slot["margin_key"])
    if margins is None:
        raise SystemExit(f"ANTI-DRIFT: margin_key '{slot['margin_key']}' нет в ui_theme_paths.gd")
    w = slot["w"]
    if margins[0] + margins[2] >= w or margins[1] + margins[3] >= h:
        raise SystemExit(f"9-slice невалиден для {slot['slug']}: бордюры {margins} не влезают в {w}x{h}.")
    return w, h, margins


# --- рисующее ядро ------------------------------------------------------------
def _lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def render(w: int, h: int, margins) -> Image.Image:
    """9-slice-safe рамка w×h. ВЕСЬ орнамент держится внутри margin-band, центр —
    ровный вертикальный градиент (горизонтально однородный) → тайл центра не плывёт."""
    left, top, right, bottom = margins
    band = max(2, min(left, top, right, bottom))  # самая узкая полоса орнамента
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))

    pad = 2
    border_w = max(2, min(4, band // 4))
    rad = max(4, min(band - 2, h // 12, 22))
    x0, y0, x1, y1 = pad, pad, w - pad - 1, h - pad - 1

    # ровный вертикальный градиент-заливка внутри скруглённого прямоугольника
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle((x0, y0, x1, y1), radius=rad, fill=255)
    grad = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    gp = grad.load()
    span = max(1, y1 - y0)
    for yy in range(h):
        t = min(1.0, max(0.0, (yy - y0) / span))
        c = _lerp(FILL_TOP, FILL_BOT, t) + (FILL_ALPHA,)
        for xx in range(w):
            gp[xx, yy] = c
    img = Image.composite(grad, img, mask)

    d = ImageDraw.Draw(img)
    d.rounded_rectangle((x0, y0, x1, y1), radius=rad, outline=AMBER + (255,), width=border_w)
    inner = pad + border_w
    d.rounded_rectangle((inner, inner, w - inner - 1, h - inner - 1),
                        radius=max(2, rad - border_w),
                        outline=_lerp(FILL_TOP, AMBER, 0.4) + (110,), width=1)

    # угловые L-скобки строго внутри margin-band (не дальше самой узкой полосы)
    off = pad + border_w + 2
    leg = max(6, band - off - 2)
    if leg >= 4:
        for cx, cy, sx, sy in ((x0 + off, y0 + off, 1, 1), (x1 - off, y0 + off, -1, 1),
                               (x0 + off, y1 - off, 1, -1), (x1 - off, y1 - off, -1, -1)):
            d.line([(cx, cy), (cx + sx * leg, cy)], fill=ACCENT + (255,), width=2)
            d.line([(cx, cy), (cx, cy + sy * leg)], fill=ACCENT + (255,), width=2)
    return img


# --- 9-slice симуляция (для верификатора) -------------------------------------
def slice9(img, margins):
    w, h = img.size
    l, t, r, b = margins
    xs = [0, l, w - r, w]
    ys = [0, t, h - b, h]
    cells = {}
    for cy in range(3):
        for cx in range(3):
            cells[(cx, cy)] = img.crop((xs[cx], ys[cy], xs[cx + 1], ys[cy + 1]))
    return cells, (l, t, r, b)


def assemble9(img, margins, W, H):
    cells, (l, t, r, b) = slice9(img, margins)
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    cw, ch = max(1, W - l - r), max(1, H - t - b)

    def put(cell, x, y, tw, th):
        out.paste(cell if (cell.size == (tw, th)) else cell.resize((tw, th), Image.NEAREST), (x, y))
    # углы — без масштаба
    put(cells[(0, 0)], 0, 0, l, t)
    put(cells[(2, 0)], W - r, 0, r, t)
    put(cells[(0, 2)], 0, H - b, l, b)
    put(cells[(2, 2)], W - r, H - b, r, b)
    # рёбра
    put(cells[(1, 0)], l, 0, cw, t)
    put(cells[(1, 2)], l, H - b, cw, b)
    put(cells[(0, 1)], 0, t, l, ch)
    put(cells[(2, 1)], W - r, t, r, ch)
    # центр
    put(cells[(1, 1)], l, t, cw, ch)
    return out


def _corners(img, margins):
    w, h = img.size
    l, t, r, b = margins
    return [img.crop((0, 0, l, t)), img.crop((w - r, 0, w, t)),
            img.crop((0, h - b, l, h)), img.crop((w - r, h - b, w, h))]


def _identical(a, b):
    if a.size != b.size:
        return False
    return ImageChops.difference(a.convert("RGBA"), b.convert("RGBA")).getbbox() is None


# --- верификатор --------------------------------------------------------------
def verify_asset(path: Path, exp_w: int, exp_h: int, margins) -> list[str]:
    notes = []
    img = Image.open(path).convert("RGBA")
    w, h = img.size
    if (w, h) != (exp_w, exp_h):
        notes.append(f"размер {w}x{h} != ожидаемого {exp_w}x{exp_h}")
        return notes  # дальше нет смысла
    l, t, r, b = margins
    if l + r >= w or t + b >= h:
        notes.append(f"9-slice невалиден: бордюры {margins} не оставляют центр в {w}x{h}")
        return notes
    # симуляция 9-slice под несколько целевых размеров: углы обязаны совпадать попиксельно
    src_corners = _corners(img, margins)
    for (tw, th) in [(w, h), (w * 2, h * 2), (max(l + r + 8, w // 2), max(t + b + 8, h // 2)),
                     (int(w * 1.6), int(h * 1.6))]:
        asm = assemble9(img, margins, tw, th)
        for sc, ac in zip(src_corners, _corners(asm, margins)):
            if not _identical(sc, ac):
                notes.append(f"орнамент искажается при 9-slice→{tw}x{th}: угол не совпадает")
                break
    # центр (внутри бордюров) обязан быть горизонтально однородным (только верт. градиент)
    inset = 3
    cx0, cy0, cx1, cy1 = l + inset, t + inset, w - r - inset, h - b - inset
    if cx1 - cx0 >= 6 and cy1 - cy0 >= 6:
        px = img.load()
        max_row_spread = 0
        for yy in range(cy0, cy1):
            row = [px[xx, yy] for xx in range(cx0, cx1)]
            for ch_i in range(3):
                vals = [p[ch_i] for p in row]
                max_row_spread = max(max_row_spread, max(vals) - min(vals))
        if max_row_spread > 6:
            notes.append(f"центр не плоский (орнамент протёк в safe-зону): row spread {max_row_spread}")
    # артефакты: stray-острова / спеки / гало — переиспользуем sprite_quality_audit
    try:
        sys.path.insert(0, str(ROOT / "tools"))
        import sprite_quality_audit as sqa  # noqa: E402
        notes.extend(sqa.audit_file(path, fix=False))
    except Exception as exc:  # pragma: no cover - аудит опционален
        notes.append(f"(аудит артефактов пропущен: {exc})")
    return notes


# --- сборка пайплайна ---------------------------------------------------------
def asset_path(slug: str) -> Path:
    return OUT_DIR / f"ui_frame_2k_{slug}.png"


def build():
    frame_margins, button_margins = load_margins()
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    built = []
    for slot in SLOTS:
        w, h, margins = resolve_slot(slot, frame_margins, button_margins)
        img = render(w, h, margins)
        out = asset_path(slot["slug"])
        img.save(out)
        built.append((slot, w, h, margins))
        print(f"  {slot['slug']:<14} {w}x{h:<5} kind={slot['kind']:<6} margins={margins} -> {out.relative_to(ROOT)}")
    _contact_sheet(built)
    print(f"built {len(built)} assets in {OUT_DIR.relative_to(ROOT)}; contact: {CONTACT_SHEET.relative_to(ROOT)}")
    return built


def _contact_sheet(built):
    cols = 4
    cell_w, cell_h, pad, label_h = 240, 200, 16, 26
    rows = (len(built) + cols - 1) // cols
    sheet_w = cols * (cell_w + pad) + pad
    sheet_h = rows * (cell_h + label_h + pad) + pad
    sheet = Image.new("RGBA", (sheet_w, sheet_h), (18, 16, 14, 255))
    draw = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 14)
    except Exception:
        font = ImageFont.load_default()
    for i, (slot, w, h, _margins) in enumerate(built):
        cx = pad + (i % cols) * (cell_w + pad)
        cy = pad + (i // cols) * (cell_h + label_h + pad)
        thumb = Image.open(asset_path(slot["slug"])).convert("RGBA")
        scale = min(cell_w / thumb.width, cell_h / thumb.height, 1.0)
        tw, th = max(1, int(thumb.width * scale)), max(1, int(thumb.height * scale))
        thumb = thumb.resize((tw, th), Image.LANCZOS)
        # шахматка под полупрозрачным ассетом для глазной проверки
        checker = Image.new("RGBA", (tw, th), (44, 40, 36, 255))
        cd = ImageDraw.Draw(checker)
        for yy in range(0, th, 12):
            for xx in range(0, tw, 12):
                if (xx // 12 + yy // 12) % 2 == 0:
                    cd.rectangle((xx, yy, xx + 11, yy + 11), fill=(56, 51, 46, 255))
        checker.alpha_composite(thumb)
        sheet.alpha_composite(checker, (cx + (cell_w - tw) // 2, cy + (cell_h - th) // 2))
        draw.text((cx + 4, cy + cell_h + 4), f"{slot['slug']}  {w}x{h}", fill=(232, 206, 150, 255), font=font)
    CONTACT_SHEET.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(CONTACT_SHEET)


def verify():
    frame_margins, button_margins = load_margins()
    all_ok = True
    print("RENDER-VERIFIER (--verify):")
    for slot in SLOTS:
        w, h, margins = resolve_slot(slot, frame_margins, button_margins)
        path = asset_path(slot["slug"])
        if not path.exists():
            print(f"  FAIL {slot['slug']:<14} — ассет не сгенерён ({path.relative_to(ROOT)})")
            all_ok = False
            continue
        notes = verify_asset(path, w, h, margins)
        status = "PASS" if not notes else "FAIL"
        all_ok = all_ok and not notes
        print(f"  {status} {slot['slug']:<14} {w}x{h}" + ("" if not notes else "  | " + "; ".join(notes)))
    print("VERDICT:", "PASS — все ассеты валидны" if all_ok else "FAIL — есть нарушения")
    return all_ok


def main():
    ap = argparse.ArgumentParser(description="SCRUM-485 UI 2K frame kit builder/verifier")
    ap.add_argument("--verify", action="store_true", help="только рендер-верификатор (exit!=0 при FAIL)")
    ap.add_argument("--all", action="store_true", help="сгенерить и сразу верифицировать")
    args = ap.parse_args()
    if args.verify:
        sys.exit(0 if verify() else 1)
    build()
    if args.all:
        sys.exit(0 if verify() else 1)


if __name__ == "__main__":
    main()
