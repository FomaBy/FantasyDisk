#!/usr/bin/env python3
"""Pixel/geometry oracle for the SCRUM-1033 Settings title safe-zone fix."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from PIL import Image, ImageChops, ImageDraw


ROOT = Path(__file__).resolve().parent
PREVIEWS = ROOT.parents[1] / "previews" / "scrum975_settings_game_tab"
EXPECTED = {
    2560: {
        "canvas": (2560, 1440),
        "rect": (352, 132, 392, 72),
        "plate_roi": (150, 50, 930, 245),
        "font": 48,
        "base": "pixellab_settings_four_tab_layout_2560x1440.png",
        "final": "settings_game_2560x1440.png",
        "report": "render_2560x1440.report.json",
        "forbidden": {"left_x": 339, "right_x": 773, "top_y": 125, "bottom_y": 212},
        "minimum_reserve": {"left": 13, "right": 29, "top": 6, "bottom": 8},
    },
    1920: {
        "canvas": (1920, 1080),
        "rect": (264, 99, 294, 54),
        "plate_roi": (112, 38, 698, 184),
        "font": 36,
        "base": "pixellab_settings_four_tab_layout_1920x1080.png",
        "final": "settings_game_1920x1080.png",
        "report": "render_1920x1080.report.json",
        "forbidden": {"left_x": 254, "right_x": 580, "top_y": 94, "bottom_y": 159},
        "minimum_reserve": {"left": 10, "right": 22, "top": 4, "bottom": 6},
    },
}


def load_json(name: str) -> dict[str, Any]:
    return json.loads((ROOT / name).read_text(encoding="utf-8"))


def zone(data: dict[str, Any], zone_id: str, key: str) -> dict[str, Any]:
    return next(item for item in data[key] if item["id"] == zone_id)


def rect(item: dict[str, Any]) -> tuple[int, int, int, int]:
    return tuple(int(item[key]) for key in ("x", "y", "w", "h"))  # type: ignore[return-value]


def inside(inner: tuple[int, int, int, int], outer: tuple[int, int, int, int]) -> bool:
    ix, iy, iw, ih = inner
    ox, oy, ow, oh = outer
    return ix >= ox and iy >= oy and ix + iw <= ox + ow and iy + ih <= oy + oh


def forbidden_pixel_count(
    diff: Image.Image,
    title_rect: tuple[int, int, int, int],
    plate_roi: tuple[int, int, int, int],
    bounds: dict[str, int],
) -> tuple[int, int, tuple[int, int, int, int] | None]:
    rgba = diff.convert("RGBA")
    alpha = rgba.getchannel("A")
    # ImageChops difference of two opaque composites has alpha=0 everywhere;
    # promote any RGB difference into a binary pixel mask.
    rgb = rgba.convert("RGB")
    channels = rgb.split()
    changed = channels[0].point(lambda v: 255 if v else 0)
    changed = ImageChops.lighter(changed, channels[1].point(lambda v: 255 if v else 0))
    changed = ImageChops.lighter(changed, channels[2].point(lambda v: 255 if v else 0))
    if alpha.getbbox():
        changed = ImageChops.lighter(changed, alpha.point(lambda v: 255 if v else 0))
    title_changed = Image.new("L", changed.size, 0)
    rx0, ry0, rx1, ry1 = plate_roi
    title_changed.paste(changed.crop(plate_roi), (rx0, ry0))
    forbidden = Image.new("L", changed.size, 0)
    draw = ImageDraw.Draw(forbidden)
    draw.rectangle((0, 0, bounds["left_x"], changed.height - 1), fill=255)
    draw.rectangle((bounds["right_x"], 0, changed.width - 1, changed.height - 1), fill=255)
    draw.rectangle((0, 0, changed.width - 1, bounds["top_y"]), fill=255)
    draw.rectangle((0, bounds["bottom_y"], changed.width - 1, changed.height - 1), fill=255)
    overlap = ImageChops.multiply(title_changed, forbidden)
    return sum(1 for value in title_changed.getdata() if value), sum(1 for value in overlap.getdata() if value), title_changed.getbbox()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--report", default=str(ROOT / "scrum1033_title_safe.report.json"))
    args = parser.parse_args()
    plan = load_json("ui_plan.json")
    layout_2k = load_json("layout.json")
    layout_1080 = load_json("layout_1920x1080.json")
    errors: list[str] = []
    results: list[dict[str, Any]] = []

    planned = rect(zone(plan, "settings_title", "elements"))
    if planned != EXPECTED[2560]["rect"]:
        errors.append(f"ui_plan title {planned} != {EXPECTED[2560]['rect']}")
    if rect(zone(layout_2k, "settings_title", "zones")) != EXPECTED[2560]["rect"]:
        errors.append("2K layout title does not match ui_plan")
    if rect(zone(layout_1080, "settings_title", "zones")) != EXPECTED[1920]["rect"]:
        errors.append("1080 layout title is not the exact 0.75 derivative")

    compact_files = (
        "ui_plan_1280x720.json",
        "layout_1280x720.json",
        "layout_1280x720_scroll_bottom.json",
        "render_1280x720.report.json",
        "render_1280x720_scroll_bottom.report.json",
    )
    compact_hashes = {name: __import__("hashlib").sha256((ROOT / name).read_bytes()).hexdigest() for name in compact_files}

    for width, expected in EXPECTED.items():
        layout = layout_2k if width == 2560 else layout_1080
        title_zone = zone(layout, "settings_title", "zones")
        title_rect = rect(title_zone)
        report = load_json(str(expected["report"]))
        rendered = zone(report, "settings_title", "zones")
        text_bbox = tuple(int(value) for value in rendered["text_bbox"])
        if int(rendered["font_size"]) != expected["font"]:
            errors.append(f"{width}: font {rendered['font_size']} != {expected['font']}")
        if not inside(text_bbox, title_rect):
            errors.append(f"{width}: rendered title bbox {text_bbox} leaves title safe rect {title_rect}")
        bounds = expected["forbidden"]
        x, y, w, h = title_rect
        actual_reserve = {
            "left": x - bounds["left_x"],
            "right": bounds["right_x"] - (x + w),
            "top": y - bounds["top_y"],
            "bottom": bounds["bottom_y"] - (y + h),
        }
        for side, minimum in expected["minimum_reserve"].items():
            if actual_reserve[side] < minimum:
                errors.append(f"{width}: {side} reserve {actual_reserve[side]} < {minimum}")
        base = Image.open(ROOT / str(expected["base"])).convert("RGBA")
        final = Image.open(PREVIEWS / str(expected["final"])).convert("RGBA")
        if base.size != expected["canvas"] or final.size != expected["canvas"]:
            errors.append(f"{width}: unexpected base/final dimensions")
            continue
        changed_count, overlap_count, changed_bbox = forbidden_pixel_count(
            ImageChops.difference(final, base), title_rect, expected["plate_roi"], bounds
        )
        if changed_count <= 0:
            errors.append(f"{width}: no rendered title pixels detected")
        if changed_bbox and not inside(
            (changed_bbox[0], changed_bbox[1], changed_bbox[2] - changed_bbox[0], changed_bbox[3] - changed_bbox[1]),
            title_rect,
        ):
            errors.append(f"{width}: actual changed-title pixel bbox {changed_bbox} leaves title safe rect")
        if overlap_count:
            errors.append(f"{width}: {overlap_count} rendered title pixels intersect the ornament/frame mask")
        results.append({
            "canvas": list(expected["canvas"]),
            "title_rect": list(title_rect),
            "text_bbox": list(text_bbox),
            "font_size": rendered["font_size"],
            "forbidden_bounds": bounds,
            "actual_reserve": actual_reserve,
            "changed_title_pixels": changed_count,
            "changed_title_bbox": list(changed_bbox) if changed_bbox else None,
            "forbidden_overlap_pixels": overlap_count,
        })

    output = {
        "ok": not errors,
        "ticket": "SCRUM-1033",
        "errors": errors,
        "source_reuse": "accepted PixelLab art unchanged; content geometry/composites only",
        "compact_contract_hashes": compact_hashes,
        "results": results,
    }
    Path(args.report).write_text(json.dumps(output, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(output, ensure_ascii=False, indent=2))
    return 0 if not errors else 2


if __name__ == "__main__":
    raise SystemExit(main())
