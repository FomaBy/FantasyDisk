#!/usr/bin/env python3
"""SCRUM-819: mute bright gold settings frames into dark brass (leather/brass course).

Selectively remaps yellow-gold pixels (hue 25..70deg, saturated, bright) toward the
approved dark-brass band of ui_hud_v2_cluster_bg.png, preserving ornament shading.
Sizes/names/alpha stay 1:1, so .import sidecars and StyleBox margins remain valid.
"""
from __future__ import annotations

import colorsys
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
TARGETS = [
    "assets/sprites/ui/frames/settings_v4/ui_frame_settings_v4_field.png",
    "assets/sprites/ui/frames/settings_v4/ui_frame_settings_v4_action_button.png",
    "assets/sprites/ui/frames/settings_v3/ui_frame_settings_v3_tab_switcher.png",
]

# Итоговая латунь: hue ~34deg, приглушённая; value сжимается в тёмную полосу.
BRASS_HUE = 34.0 / 360.0
V_LOW, V_HIGH = 0.16, 0.58   # тёмная латунь: света рамки не ярче ~0.58


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
        print(f"{rel}: recolored {changed}/{total} px")
    return 0


if __name__ == "__main__":
    sys.exit(main())
