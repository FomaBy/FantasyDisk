#!/usr/bin/env python3
"""SCRUM-821: mute yellow button borders and level-up gold accents into dark brass.

Same selective HSV remap as SCRUM-819 (tools/recolor_settings_brass.py): yellow-gold
pixels (hue 25..70deg, saturated, bright) move to the approved dark-brass band; state
separation survives because the value map is monotonic (hover stays lighter than
normal, pressed darker). Sizes/names/alpha stay 1:1 so margins and .import hold.

level_up_scrum682-цели сняты: кит удалён при зачистке атлас-миграции
(SCRUM-879..888), level-up рисуется атлас-чипами.
"""
from __future__ import annotations

import colorsys
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
TARGETS = [
    # FAB «⬆» докачки (4 стейта)
    "assets/sprites/ui/frames/minimal_metal_buttons/ui_btn_minimal_metal_fab.png",
    "assets/sprites/ui/frames/minimal_metal_buttons/ui_btn_minimal_metal_fab_hover.png",
    "assets/sprites/ui/frames/minimal_metal_buttons/ui_btn_minimal_metal_fab_focus.png",
    "assets/sprites/ui/frames/minimal_metal_buttons/ui_btn_minimal_metal_fab_pressed.png",
    # Мелкие utility-кнопки (зум скилл-три и фоллбеки, 4 стейта)
    "assets/sprites/ui/frames/minimal_metal_buttons/ui_btn_minimal_metal_utility.png",
    "assets/sprites/ui/frames/minimal_metal_buttons/ui_btn_minimal_metal_utility_hover.png",
    "assets/sprites/ui/frames/minimal_metal_buttons/ui_btn_minimal_metal_utility_focus.png",
    "assets/sprites/ui/frames/minimal_metal_buttons/ui_btn_minimal_metal_utility_pressed.png",
    # Кнопка «+» уровня в боевом HUD (тонкий золотой кант, приглушаем для единообразия)
    "assets/sprites/ui/frames/combat_hud/ui_btn_combat_level_up_plus.png",
    "assets/sprites/ui/frames/combat_hud/ui_btn_combat_level_up_plus_hover.png",
    "assets/sprites/ui/frames/combat_hud/ui_btn_combat_level_up_plus_pressed.png",
    "assets/sprites/ui/frames/combat_hud/ui_btn_combat_level_up_plus_disabled.png",
]

BRASS_HUE = 34.0 / 360.0
# V_HIGH держим под порогом bright-скана (val>=0.52): у fab/utility hover почти белый
# бордюр, при 0.58 верх мапа сам оставался «ярко-жёлтым» по метрике аудита.
V_LOW, V_HIGH = 0.16, 0.50


def is_gold(h: float, s: float, v: float) -> bool:
    return 25.0 / 360.0 <= h <= 70.0 / 360.0 and s >= 0.25 and v >= 0.30


def recolor(path: Path) -> tuple[int, int]:
    im = Image.open(path).convert("RGBA")
    px = im.load()
    w, hgt = im.size
    changed = 0
    for y in range(hgt):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
            if not is_gold(h, s, v):
                continue
            nv = V_LOW + (V_HIGH - V_LOW) * ((v - 0.30) / 0.70)
            ns = min(1.0, s * 0.80)
            nr, ng, nb = colorsys.hsv_to_rgb(BRASS_HUE, ns, max(V_LOW, min(V_HIGH, nv)))
            px[x, y] = (int(nr * 255), int(ng * 255), int(nb * 255), a)
            changed += 1
    im.save(path)
    return changed, w * hgt


def main() -> int:
    for rel in TARGETS:
        path = ROOT / rel
        changed, total = recolor(path)
        print(f"{rel.split('/')[-1]}: {changed}/{total} px")
    return 0


if __name__ == "__main__":
    sys.exit(main())
