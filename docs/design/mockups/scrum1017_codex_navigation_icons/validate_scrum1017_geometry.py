#!/usr/bin/env python3
"""Deterministic geometry checks for the SCRUM-1017 Design contract."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[4]
HERE = Path(__file__).resolve().parent
TARGETS = [(1280, 720), (1920, 1080), (2560, 1440)]


def rect(item: dict) -> tuple[int, int, int, int]:
    return tuple(int(item[key]) for key in ("x", "y", "w", "h"))


def inside(inner: tuple[int, int, int, int], outer: tuple[int, int, int, int]) -> bool:
    ix, iy, iw, ih = inner
    ox, oy, ow, oh = outer
    return ix >= ox and iy >= oy and ix + iw <= ox + ow and iy + ih <= oy + oh


def intersects(a: tuple[int, int, int, int], b: tuple[int, int, int, int]) -> bool:
    ax, ay, aw, ah = a
    bx, by, bw, bh = b
    return ax < bx + bw and bx < ax + aw and ay < by + bh and by < ay + ah


def gap(a: tuple[int, int, int, int], b: tuple[int, int, int, int]) -> int:
    ax, ay, aw, ah = a
    bx, by, bw, bh = b
    horizontal = max(bx - (ax + aw), ax - (bx + bw), 0)
    vertical = max(by - (ay + ah), ay - (by + bh), 0)
    return max(horizontal, vertical)


def main() -> None:
    plan = json.loads((HERE / "ui_plan.json").read_text())
    plan_report = json.loads((HERE / "ui_plan.report.json").read_text())
    elements = {item["id"]: item for item in plan["elements"]}
    errors: list[str] = []

    if not plan_report.get("ok") or plan_report.get("decision") != "ready_for_image":
        errors.append("planning gate is not ready_for_image")

    nav_ids = [
        "tab_characters_frame", "tab_monsters_frame", "tab_artifacts_frame",
        "tab_characteristics_frame", "tab_attributes_frame", "tab_ascension_frame",
    ]
    row_ids = [f"row_{index}_frame" for index in range(1, 5)]
    for group_name, ids, required_gap in (("nav", nav_ids, 14), ("rows", row_ids, 16)):
        for left, right in zip(ids, ids[1:]):
            actual = gap(rect(elements[left]), rect(elements[right]))
            if actual < required_gap:
                errors.append(f"{group_name} gap {left}->{right} is {actual}, expected {required_gap}")

    center_lane = rect(elements["center_scrollbar_lane"])
    detail_lane = rect(elements["detail_scrollbar_lane"])
    for index in range(1, 5):
        frame = rect(elements[f"row_{index}_frame"])
        image = rect(elements[f"row_{index}_image"])
        name = rect(elements[f"row_{index}_name"])
        if not inside(image, frame) or not inside(name, frame):
            errors.append(f"row {index} content escapes row frame")
        if intersects(image, name):
            errors.append(f"row {index} image overlaps name")
        if intersects(frame, center_lane):
            errors.append(f"row {index} enters center scrollbar lane")

    detail_panel = rect(elements["detail_panel"])
    detail_parts = [
        "detail_title", "detail_preview_well", "detail_chip_1_frame",
        "detail_chip_2_frame", "detail_scroll",
    ]
    for part in detail_parts:
        if not inside(rect(elements[part]), detail_panel):
            errors.append(f"{part} escapes detail panel")
    for part in ("detail_title", "detail_preview_image", "detail_chip_1", "detail_chip_2", "detail_body"):
        if intersects(rect(elements[part]), detail_lane):
            errors.append(f"{part} enters detail scrollbar lane")
    if intersects(rect(elements["detail_preview_well"]), rect(elements["detail_scroll"])):
        errors.append("preview well overlaps detail scroll")

    layout_paths = [HERE / "layout.json", HERE / "layout_monsters.json", HERE / "layout_artifacts.json"]
    layouts = [json.loads(path.read_text()) for path in layout_paths]
    base_rects = {zone["id"]: rect(zone) for zone in layouts[0]["zones"]}
    state_reports = []
    for path, layout in zip(layout_paths, layouts):
        zone_rects = {zone["id"]: rect(zone) for zone in layout["zones"]}
        if zone_rects != base_rects:
            errors.append(f"state geometry differs: {path.name}")
        images = [zone["image_path"] for zone in layout["zones"] if "image_path" in zone]
        missing = [image for image in images if not (ROOT / image).exists()]
        generic = [image for image in images if "codex_pl_icon_" in image or "category" in image]
        if missing:
            errors.append(f"{path.name} missing images: {missing}")
        if generic:
            errors.append(f"{path.name} generic/category images: {generic}")
        state_reports.append({"layout": path.name, "zones": len(layout["zones"]), "images": images})

    responsive = []
    row_image_rect = rect(elements["row_1_image"])
    detail_preview_rect = rect(elements["detail_preview_image"])
    nav_button_rect = rect(elements["tab_characters_frame"])
    for width, height in TARGETS:
        scale = min(width / 1920.0, height / 1080.0)
        panels = {}
        for panel_id in ("title_frame", "back_frame", "nav_panel", "center_panel", "detail_panel"):
            x, y, w, h = rect(elements[panel_id])
            scaled = [round(value * scale, 2) for value in (x, y, w, h)]
            if scaled[0] < 0 or scaled[1] < 0 or scaled[0] + scaled[2] > width or scaled[1] + scaled[3] > height:
                errors.append(f"{panel_id} escapes {width}x{height}")
            panels[panel_id] = scaled
        responsive.append({
            "viewport": [width, height],
            "scale": round(scale, 6),
            "panels": panels,
            "row_image_zone": [round(row_image_rect[2] * scale, 2), round(row_image_rect[3] * scale, 2)],
            "detail_preview_zone": [round(detail_preview_rect[2] * scale, 2), round(detail_preview_rect[3] * scale, 2)],
            "nav_button": [round(nav_button_rect[2] * scale, 2), round(nav_button_rect[3] * scale, 2)],
            "panel_gaps": [round(24 * scale, 2), round(24 * scale, 2)],
        })

    report = {
        "ok": not errors,
        "errors": errors,
        "planning_gate": plan_report.get("decision"),
        "element_count": len(elements),
        "state_reports": state_reports,
        "responsive": responsive,
        "scrollbar_lanes_1920": {
            "center": list(center_lane),
            "detail": list(detail_lane),
        },
        "frame_rule": "content zones remain inside empty frame interiors",
    }
    (HERE / "geometry.report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    if errors:
        raise SystemExit("\n".join(errors))
    print("SCRUM-1017 geometry validation passed")


if __name__ == "__main__":
    main()
