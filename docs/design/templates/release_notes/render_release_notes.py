#!/usr/bin/env python3
"""Render one FantasyDisk release-notes image from the reusable template."""

from __future__ import annotations

import argparse
import json
import platform
import re
import subprocess
import sys
from pathlib import Path
from typing import Any


TEMPLATE_DIR = Path(__file__).resolve().parent
REPO_ROOT = TEMPLATE_DIR.parents[3]
PROFILE_PATH = TEMPLATE_DIR / "export_profile.json"
LAYOUT_PATH = TEMPLATE_DIR / "layout.json"
PLAN_PATH = TEMPLATE_DIR / "ui_plan.json"
VALIDATOR = REPO_ROOT / "skills/codex/content-zone-image-compositor/scripts/validate_ui_layout_plan.py"
RENDERER = REPO_ROOT / "skills/codex/content-zone-image-compositor/scripts/render_content_zones.py"


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def clean_scalar(value: Any) -> str:
    return " ".join(str(value or "").split())


def bullet_items(value: Any) -> list[str]:
    raw = value if isinstance(value, list) else str(value or "").splitlines()
    items: list[str] = []
    for entry in raw:
        text = clean_scalar(entry)
        text = re.sub(r"^(?:[-*•]|\d+[.)])\s*", "", text)
        if text:
            items.append(text)
    return items


def shorten_item(text: str, limit: int) -> str:
    text = clean_scalar(text)
    if len(text) <= limit:
        return text
    cut = text[: max(1, limit - 1)].rsplit(" ", 1)[0].rstrip(" ,;:—-")
    return f"{cut}…"


def shorten_items(value: Any, max_items: int, max_chars: int) -> list[str]:
    items = bullet_items(value)
    if not items:
        raise ValueError("key_changes and fixed_bugs must contain at least one item")
    shortened = [shorten_item(item, max_chars) for item in items]
    if len(shortened) <= max_items:
        return shortened
    remaining = len(shortened) - (max_items - 1)
    summary = f"Ещё {remaining} пунктов свернуты в краткое резюме."
    return [*shortened[: max_items - 1], shorten_item(summary, max_chars)]


def normalize_content(raw: dict[str, Any], profile: dict[str, Any]) -> dict[str, str]:
    budget = profile["content_budget"]
    title = clean_scalar(raw.get("game_title")) or "FantasyDisk"
    version = clean_scalar(raw.get("version"))
    if version and not version.lower().startswith("v"):
        version = f"v{version}"
    if not version:
        raise ValueError("version is required")
    release_date = clean_scalar(raw.get("release_date"))
    if not release_date:
        raise ValueError("release_date is required")
    key_changes = shorten_items(raw.get("key_changes"), int(budget["body_max_items"]), int(budget["body_max_item_chars"]))
    fixed_bugs = shorten_items(raw.get("fixed_bugs"), int(budget["body_max_items"]), int(budget["body_max_item_chars"]))
    return {
        "game_title": title.upper(),
        "version": version,
        "release_date": release_date,
        "key_changes": "КЛЮЧЕВЫЕ ИЗМЕНЕНИЯ\n" + "\n".join(f"• {item}" for item in key_changes),
        "fixed_bugs": "ИСПРАВЛЕННЫЕ ОШИБКИ\n" + "\n".join(f"• {item}" for item in fixed_bugs),
    }


def run_gate(command: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(command, cwd=REPO_ROOT, text=True, capture_output=True, check=False)


def python_command() -> list[str]:
    """Use the architecture that matches the repository's Pillow install."""
    if sys.platform == "darwin" and platform.machine() == "x86_64":
        return ["arch", "-arm64", "/usr/bin/python3"]
    return [sys.executable]


def rect_inside(inner: list[int], outer: list[int]) -> bool:
    ix, iy, iw, ih = inner
    ox, oy, ow, oh = outer
    return ix >= ox and iy >= oy and ix + iw <= ox + ow and iy + ih <= oy + oh


def boxes_overlap(a: list[int], b: list[int]) -> bool:
    ax, ay, aw, ah = a
    bx, by, bw, bh = b
    return ax < bx + bw and bx < ax + aw and ay < by + bh and by < ay + ah


def validate_render_report(report: dict[str, Any], layout: dict[str, Any], profile: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    canvas = [0, 0, int(layout["canvas"]["width"]), int(layout["canvas"]["height"])]
    declared = {zone["id"]: zone for zone in profile["zones"]}
    actual_boxes: list[tuple[str, list[int]]] = []
    declared_boxes = [(zone["id"], zone["rect"]) for zone in profile["zones"]]
    for zone_id, zone_rect in declared_boxes:
        if not rect_inside(zone_rect, canvas):
            errors.append(f"{zone_id}: profile rect {zone_rect} escapes canvas")
    for index, (left_id, left_rect) in enumerate(declared_boxes):
        for right_id, right_rect in declared_boxes[index + 1 :]:
            if boxes_overlap(left_rect, right_rect):
                errors.append(f"declared zone rectangles overlap: {left_id} / {right_id}")
    for zone in report.get("zones", []):
        zid = str(zone.get("id"))
        if zid not in declared:
            errors.append(f"unexpected rendered zone: {zid}")
            continue
        expected = declared[zid]["rect"]
        if zone.get("rect") != expected:
            errors.append(f"{zid}: rendered rect {zone.get('rect')} differs from profile {expected}")
        if not zone.get("ok"):
            errors.append(f"{zid}: compositor reported failure: {zone.get('reason', 'unknown')}")
        max_lines = declared[zid].get("max_lines")
        if max_lines is not None and len(zone.get("lines", [])) > int(max_lines):
            errors.append(f"{zid}: rendered line count exceeds max_lines={max_lines}")
        bbox = zone.get("text_bbox")
        if bbox is not None:
            if not rect_inside(bbox, expected):
                errors.append(f"{zid}: text bbox {bbox} escapes zone {expected}")
            if not rect_inside(bbox, canvas):
                errors.append(f"{zid}: text bbox {bbox} escapes canvas")
            actual_boxes.append((zid, bbox))
    if set(declared) != {str(zone.get("id")) for zone in report.get("zones", [])}:
        errors.append("render report does not contain exactly the five declared text zones")
    for index, (left_id, left_box) in enumerate(actual_boxes):
        for right_id, right_box in actual_boxes[index + 1 :]:
            if boxes_overlap(left_box, right_box):
                errors.append(f"actual text bboxes overlap: {left_id} / {right_id}")
    return errors


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--content", required=True, type=Path, help="Raw release JSON")
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--case", default="release")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    profile = load_json(PROFILE_PATH)
    raw = load_json(args.content)
    normalized = normalize_content(raw, profile)
    output_dir = args.output_dir if args.output_dir.is_absolute() else REPO_ROOT / args.output_dir
    output_dir = output_dir.resolve()
    if output_dir.exists() and any(output_dir.iterdir()):
        raise SystemExit(f"output directory must be empty: {output_dir}")
    output_dir.mkdir(parents=True, exist_ok=True)

    plan = load_json(PLAN_PATH)
    plan["content"] = normalized
    plan_path = output_dir / "ui_plan.json"
    plan_report_path = output_dir / profile["outputs"]["planning_report"]
    plan_guide_path = output_dir / profile["outputs"]["planning_guide"]
    plan_path.write_text(json.dumps(plan, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    plan_result = run_gate(python_command() + [str(VALIDATOR), "--plan", str(plan_path), "--report", str(plan_report_path), "--guide-output", str(plan_guide_path)])
    if not plan_report_path.exists():
        raise SystemExit(f"planning gate produced no report for {args.case}: {plan_result.stderr.strip()}")
    plan_report = load_json(plan_report_path)
    if plan_result.returncode != 0 or plan_report.get("decision") != "ready_for_image":
        raise SystemExit(f"planning gate failed for {args.case}: {plan_report.get('errors', [])}")

    layout = load_json(LAYOUT_PATH)
    layout["content"] = normalized
    layout_path = output_dir / "layout.json"
    layout_path.write_text(json.dumps(layout, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    base_layer = (TEMPLATE_DIR / profile["base_layer"]).resolve()
    final_path = output_dir / profile["outputs"]["publishable"]
    debug_path = output_dir / profile["outputs"]["debug_overlay"]
    render_report_path = output_dir / profile["outputs"]["render_report"]
    render_result = run_gate([
        *python_command(),
        str(RENDERER),
        "--input",
        str(base_layer),
        "--layout",
        str(layout_path),
        "--output",
        str(final_path),
        "--debug-output",
        str(debug_path),
        "--report",
        str(render_report_path),
    ])
    if not render_report_path.exists():
        raise SystemExit(f"renderer produced no report for {args.case}: {render_result.stderr.strip()}")
    render_report = load_json(render_report_path)
    errors = validate_render_report(render_report, layout, profile)
    if render_result.returncode != 0 or not render_report.get("ok"):
        errors.append("content compositor returned a failed fit report")
    if not final_path.exists():
        errors.append("publishable final.png was not created")
    final_images = sorted(final_path.parent.glob("*.png")) if final_path.parent.exists() else []
    if len(final_images) != 1:
        errors.append(f"publishable final directory must contain exactly one PNG, found {len(final_images)}")
    fit_report = {
        "ok": not errors,
        "case": args.case,
        "source_template": profile["source_template"],
        "export_profile": profile["profile_id"],
        "planning_gate": {"decision": plan_report.get("decision"), "ok": plan_report.get("ok"), "report": profile["outputs"]["planning_report"]},
        "content": normalized,
        "render": render_report,
        "validation_errors": errors,
        "publishable_image": profile["outputs"]["publishable"],
        "publishable_image_count": len(final_images),
        "qa_artifacts": [profile["outputs"]["debug_overlay"], profile["outputs"]["planning_guide"], profile["outputs"]["planning_report"], profile["outputs"]["render_report"]],
    }
    (output_dir / profile["outputs"]["fit_report"]).write_text(json.dumps(fit_report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if errors:
        raise SystemExit(f"fit validation failed for {args.case}: {errors}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
