#!/usr/bin/env python3
"""Generate the proportional 1920x1080 content-zone layout from the 2K contract."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent
SCALE = 0.75


def scaled_int(value: int | float) -> int:
    return int(round(float(value) * SCALE))


layout = json.loads((ROOT / "layout.json").read_text(encoding="utf-8"))
layout["canvas"] = {"width": 1920, "height": 1080}
layout["defaults"]["stroke_width"] = max(1, scaled_int(layout["defaults"]["stroke_width"]))
for zone in layout["zones"]:
    for key in ("x", "y", "w", "h"):
        zone[key] = scaled_int(zone[key])
    if "max_font" in zone:
        zone["max_font"] = max(14, scaled_int(zone["max_font"]))
    if "min_font" in zone:
        zone["min_font"] = max(13, scaled_int(zone["min_font"]))
    if "stroke_width" in zone:
        zone["stroke_width"] = max(1, scaled_int(zone["stroke_width"]))
(ROOT / "layout_1920x1080.json").write_text(
    json.dumps(layout, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
)
