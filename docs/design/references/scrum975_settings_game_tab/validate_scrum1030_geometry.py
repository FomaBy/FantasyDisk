#!/usr/bin/env python3
"""Focused SCRUM-1030 contract gate for Settings/Game design evidence.

The generic content-zone validator checks canvas fit and text fit. This gate
adds the scroll-specific invariants that its intentionally small schema does
not model: logical scroll-content coordinates, per-row hit areas, top/bottom
viewport transforms, the reserved scrollbar lane, and agreement between the
2K plan and compositor layout.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parent
ROW_SUFFIXES = (
    "monster_hp",
    "monster_damage",
    "player_damage",
    "player_attack_speed",
    "monster_attack_speed",
)
FIXED_LAYOUT_IDS = (
    "settings_title",
    "back",
    "tab_screen",
    "tab_sound",
    "tab_controls",
    "tab_game",
)


def load(name: str) -> dict[str, Any]:
    return json.loads((ROOT / name).read_text(encoding="utf-8"))


def rect(item: dict[str, Any]) -> tuple[int, int, int, int]:
    return tuple(int(item[key]) for key in ("x", "y", "w", "h"))  # type: ignore[return-value]


def inside(inner: tuple[int, int, int, int], outer: tuple[int, int, int, int]) -> bool:
    ix, iy, iw, ih = inner
    ox, oy, ow, oh = outer
    return ix >= ox and iy >= oy and ix + iw <= ox + ow and iy + ih <= oy + oh


def intersects(a: tuple[int, int, int, int], b: tuple[int, int, int, int]) -> bool:
    ax, ay, aw, ah = a
    bx, by, bw, bh = b
    return ax < bx + bw and ax + aw > bx and ay < by + bh and ay + ah > by


def index(items: list[dict[str, Any]]) -> dict[str, dict[str, Any]]:
    return {str(item["id"]): item for item in items}


def scaled(r: tuple[int, int, int, int], factor: float) -> tuple[int, int, int, int]:
    return tuple(int(round(value * factor)) for value in r)  # type: ignore[return-value]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--report", default=str(ROOT / "scrum1030_geometry.report.json"))
    args = parser.parse_args()

    compact = load("ui_plan_1280x720.json")
    wide = load("ui_plan.json")
    top = load("layout_1280x720.json")
    bottom = load("layout_1280x720_scroll_bottom.json")
    layout_2k = load("layout.json")
    layout_1080 = load("layout_1920x1080.json")
    compact_items = index(compact["elements"])
    wide_items = index(wide["elements"])
    top_zones = index(top["zones"])
    bottom_zones = index(bottom["zones"])
    zones_2k = index(layout_2k["zones"])
    zones_1080 = index(layout_1080["zones"])
    errors: list[str] = []
    checks: list[str] = []

    scroll = compact["scroll_contract"]
    viewport = tuple(scroll["viewport_rect"])
    lane = tuple(scroll["scrollbar_lane_rect"])
    content_canvas = rect(compact_items["scroll_content_canvas"])
    expected_content_canvas = (194, 0, 878, 520)
    if content_canvas != expected_content_canvas:
        errors.append(f"compact scroll content canvas {content_canvas} != {expected_content_canvas}")
    if rect(compact_items["game_scroll"]) != viewport:
        errors.append("compact game_scroll does not match scroll_contract.viewport_rect")
    if rect(compact_items["scrollbar_lane"]) != lane:
        errors.append("compact scrollbar_lane does not match scroll_contract.scrollbar_lane_rect")
    if not inside(lane, viewport):
        errors.append("compact scrollbar lane is outside the viewport")
    checks.append("compact viewport/content canvas/14px scrollbar lane declared")

    fixed_physical = ("settings_title", "back_button", "tab_screen", "tab_sound", "tab_controls", "tab_game")
    for element_id in fixed_physical:
        if intersects(rect(compact_items[element_id]), viewport):
            errors.append(f"fixed compact element {element_id} overlaps the scroll viewport")
    checks.append("header/back/tabs remain fixed outside the scroll viewport")

    row_rects: list[tuple[int, int, int, int]] = []
    for suffix in ROW_SUFFIXES:
        row_id = f"row_{suffix}"
        row_rect = rect(compact_items[row_id])
        row_rects.append(row_rect)
        if not inside(row_rect, content_canvas):
            errors.append(f"{row_id} outside logical scroll content canvas")
        child_rects = []
        for prefix in ("label", "slider", "value"):
            child_id = f"{prefix}_{suffix}"
            child = rect(compact_items[child_id])
            child_rects.append((child_id, child))
            if not inside(child, row_rect):
                errors.append(f"{child_id} outside {row_id}")
            if intersects(child, (lane[0], 0, lane[2], content_canvas[3])):
                errors.append(f"{child_id} intrudes into logical scrollbar x-lane")
        for i, (a_id, a_rect) in enumerate(child_rects):
            for b_id, b_rect in child_rects[i + 1:]:
                if intersects(a_rect, b_rect):
                    errors.append(f"{a_id} overlaps {b_id}")
    for first, second in zip(row_rects, row_rects[1:]):
        gap = second[1] - (first[1] + first[3])
        if gap < 8:
            errors.append(f"compact row gap {gap}px is below 8px")
    reset_rect = rect(compact_items["reset_game"])
    if not inside(reset_rect, content_canvas):
        errors.append("reset_game outside logical scroll content canvas")
    if reset_rect[1] - (row_rects[-1][1] + row_rects[-1][3]) < 8:
        errors.append("reset_game is too close to the final modifier row")
    checks.append("five compact rows each declare non-overlapping label/slider/value hitboxes plus reset")

    def screen_rect(logical: tuple[int, int, int, int], scroll_y: int) -> tuple[int, int, int, int]:
        x, y, w, h = logical
        return x, viewport[1] + y - scroll_y, w, h

    for suffix in ROW_SUFFIXES[:2]:
        for prefix in ("label", "slider", "value"):
            item_id = f"{prefix}_{suffix}"
            expected = screen_rect(rect(compact_items[item_id]), int(scroll["top_scroll_y"]))
            if rect(top_zones[item_id]) != expected:
                errors.append(f"top layout {item_id} {rect(top_zones[item_id])} != transformed {expected}")
            if not inside(expected, viewport):
                errors.append(f"top layout {item_id} not fully visible in compact viewport")
    for suffix in ROW_SUFFIXES[2:]:
        for prefix in ("label", "slider", "value"):
            item_id = f"{prefix}_{suffix}"
            expected = screen_rect(rect(compact_items[item_id]), int(scroll["bottom_scroll_y"]))
            if rect(bottom_zones[item_id]) != expected:
                errors.append(f"bottom layout {item_id} {rect(bottom_zones[item_id])} != transformed {expected}")
            if not inside(expected, viewport):
                errors.append(f"bottom layout {item_id} not fully visible in compact viewport")
    expected_reset = screen_rect(rect(compact_items["reset_label"]), int(scroll["bottom_scroll_y"]))
    if rect(bottom_zones["reset"]) != expected_reset:
        errors.append(f"bottom layout reset {rect(bottom_zones['reset'])} != transformed {expected_reset}")
    if not inside(expected_reset, viewport):
        errors.append("bottom layout reset not fully visible in compact viewport")
    checks.append("top and bottom compact evidence reproduce the declared scroll transforms")

    for fixed_id in FIXED_LAYOUT_IDS:
        if rect(top_zones[fixed_id]) != rect(bottom_zones[fixed_id]):
            errors.append(f"fixed layout zone {fixed_id} moved between top and bottom states")
    checks.append("top/bottom evidence keeps header/back/tabs pixel-identical")

    for suffix in ROW_SUFFIXES:
        for prefix in ("label", "slider", "value"):
            item_id = f"{prefix}_{suffix}"
            planned = rect(wide_items[item_id])
            if rect(zones_2k[item_id]) != planned:
                errors.append(f"2K layout {item_id} {rect(zones_2k[item_id])} != plan {planned}")
            if rect(zones_1080[item_id]) != scaled(planned, 0.75):
                errors.append(f"1080p layout {item_id} is not exact 0.75 scale of 2K")
    checks.append("2K plan/layout and generated 1080p label/slider/value rectangles agree")

    report = {"ok": not errors, "ticket": "SCRUM-1030", "errors": errors, "checks": checks}
    Path(args.report).write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0 if not errors else 2


if __name__ == "__main__":
    raise SystemExit(main())
