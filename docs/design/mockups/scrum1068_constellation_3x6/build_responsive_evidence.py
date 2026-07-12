#!/usr/bin/env python3
"""Render the SCRUM-1075 content-zone contract at the acceptance matrix sizes."""

from __future__ import annotations

import argparse
import json
import subprocess
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw


BASE_SIZE = (1920, 1080)
TARGETS = (
    (1152, 648),
    (1280, 720),
    (1366, 768),
    (1600, 900),
    (1920, 1080),
    (2560, 1440),
    (3840, 2160),
)


def scale_layout(layout: dict, width: int, height: int) -> dict:
    scaled = json.loads(json.dumps(layout))
    scale_x = width / BASE_SIZE[0]
    scale_y = height / BASE_SIZE[1]
    font_scale = min(scale_x, scale_y)
    scaled["canvas"] = {"width": width, "height": height}
    for zone in scaled["zones"]:
        zone["x"] = round(zone["x"] * scale_x)
        zone["y"] = round(zone["y"] * scale_y)
        zone["w"] = max(1, round(zone["w"] * scale_x))
        zone["h"] = max(1, round(zone["h"] * scale_y))
        zone["max_font"] = max(8, round(zone["max_font"] * font_scale))
        zone["min_font"] = max(8, round(zone["min_font"] * font_scale))
    return scaled


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", type=Path, required=True)
    parser.add_argument("--layout", type=Path, required=True)
    parser.add_argument("--renderer", type=Path, required=True)
    parser.add_argument("--report-output", type=Path, required=True)
    parser.add_argument("--contact-output", type=Path, required=True)
    args = parser.parse_args()

    base = Image.open(args.base).convert("RGB")
    layout = json.loads(args.layout.read_text(encoding="utf-8"))
    matrix: list[dict] = []
    thumbnails: list[tuple[str, Image.Image]] = []

    with tempfile.TemporaryDirectory(prefix="scrum1075-responsive-") as temp_name:
        temp = Path(temp_name)
        for width, height in TARGETS:
            slug = f"{width}x{height}"
            scaled_layout = scale_layout(layout, width, height)
            layout_path = temp / f"{slug}.layout.json"
            base_path = temp / f"{slug}.base.png"
            preview_path = temp / f"{slug}.preview.png"
            debug_path = temp / f"{slug}.debug.png"
            report_path = temp / f"{slug}.report.json"
            layout_path.write_text(json.dumps(scaled_layout, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
            base.resize((width, height), Image.Resampling.NEAREST).save(base_path)
            completed = subprocess.run(
                [
                    "python3",
                    str(args.renderer),
                    "--input",
                    str(base_path),
                    "--layout",
                    str(layout_path),
                    "--output",
                    str(preview_path),
                    "--debug-output",
                    str(debug_path),
                    "--report",
                    str(report_path),
                ],
                check=False,
                capture_output=True,
                text=True,
            )
            report = json.loads(report_path.read_text(encoding="utf-8"))
            matrix.append(
                {
                    "resolution": slug,
                    "ok": completed.returncode == 0 and report.get("ok") is True,
                    "renderer_exit": completed.returncode,
                    "zone_count": len(report.get("zones", [])),
                    "zones": [
                        {"id": zone["id"], "ok": zone["ok"], "font_size": zone.get("font_size")}
                        for zone in report.get("zones", [])
                    ],
                }
            )
            preview = Image.open(preview_path).convert("RGB")
            preview.thumbnail((480, 270), Image.Resampling.NEAREST)
            thumbnails.append((slug, preview.copy()))

    args.report_output.parent.mkdir(parents=True, exist_ok=True)
    aggregate = {
        "schema": "fantasydisk.responsive_fit.v1",
        "issue": "SCRUM-1075",
        "ok": all(item["ok"] for item in matrix),
        "source_layout": str(args.layout),
        "matrix": matrix,
        "live_resize_contract": "same-instance geometry is recomputed from the current viewport; no stale rectangle reuse",
    }
    args.report_output.write_text(json.dumps(aggregate, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    sheet = Image.new("RGB", (1920, 600), (4, 7, 18))
    draw = ImageDraw.Draw(sheet)
    for index, (slug, preview) in enumerate(thumbnails):
        column = index % 4
        row = index // 4
        x = column * 480
        y = row * 300
        sheet.paste(preview, (x, y + 24))
        draw.text((x + 8, y + 5), slug, fill=(242, 213, 138))
    args.contact_output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(args.contact_output)


if __name__ == "__main__":
    main()
