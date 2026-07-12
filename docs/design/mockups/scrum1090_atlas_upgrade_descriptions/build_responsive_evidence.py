#!/usr/bin/env python3
"""Render the SCRUM-1090 source-only mockup at the required 16:9 matrix."""

from __future__ import annotations

import argparse
import json
import subprocess
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw


BASE_SIZE = (688, 384)
TARGETS = ((1280, 720), (1920, 1080), (2560, 1440))


def contain_transform(width: int, height: int) -> tuple[float, int, int]:
    scale = min(width / BASE_SIZE[0], height / BASE_SIZE[1])
    fitted_w = round(BASE_SIZE[0] * scale)
    fitted_h = round(BASE_SIZE[1] * scale)
    return scale, round((width - fitted_w) / 2), round((height - fitted_h) / 2)


def scale_layout(layout: dict, width: int, height: int) -> dict:
    scaled = json.loads(json.dumps(layout))
    scale, offset_x, offset_y = contain_transform(width, height)
    scaled["canvas"] = {"width": width, "height": height}
    for zone in scaled["zones"]:
        zone["x"] = offset_x + round(zone["x"] * scale)
        zone["y"] = offset_y + round(zone["y"] * scale)
        zone["w"] = max(1, round(zone["w"] * scale))
        zone["h"] = max(1, round(zone["h"] * scale))
        zone["max_font"] = max(7, round(zone["max_font"] * scale))
        zone["min_font"] = max(7, round(zone["min_font"] * scale))
        zone["stroke_width"] = max(1, round(zone.get("stroke_width", 1) * scale))
    scaled["defaults"]["stroke_width"] = max(
        1, round(scaled["defaults"].get("stroke_width", 1) * scale)
    )
    return scaled


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", type=Path, required=True)
    parser.add_argument("--layout", type=Path, required=True)
    parser.add_argument("--renderer", type=Path, required=True)
    parser.add_argument("--report-output", type=Path, required=True)
    parser.add_argument("--contact-output", type=Path, required=True)
    args = parser.parse_args()

    source = Image.open(args.base).convert("RGBA")
    layout = json.loads(args.layout.read_text(encoding="utf-8"))
    matrix = []
    thumbnails = []

    with tempfile.TemporaryDirectory(prefix="scrum1090-responsive-") as temp_name:
        temp = Path(temp_name)
        for width, height in TARGETS:
            slug = f"{width}x{height}"
            scale, offset_x, offset_y = contain_transform(width, height)
            resized = source.resize(
                (round(BASE_SIZE[0] * scale), round(BASE_SIZE[1] * scale)),
                Image.Resampling.NEAREST,
            )
            base = Image.new("RGBA", (width, height), (4, 7, 18, 255))
            base.alpha_composite(resized, (offset_x, offset_y))
            base_path = temp / f"{slug}.base.png"
            layout_path = temp / f"{slug}.layout.json"
            preview_path = temp / f"{slug}.preview.png"
            debug_path = temp / f"{slug}.debug.png"
            report_path = temp / f"{slug}.report.json"
            base.save(base_path)
            layout_path.write_text(
                json.dumps(scale_layout(layout, width, height), ensure_ascii=False, indent=2) + "\n",
                encoding="utf-8",
            )
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
                    "frame_transform": {
                        "scale": round(scale, 6),
                        "offset_x": offset_x,
                        "offset_y": offset_y,
                    },
                    "zones": [
                        {"id": zone["id"], "ok": zone["ok"], "font_size": zone.get("font_size")}
                        for zone in report.get("zones", [])
                    ],
                }
            )
            preview = Image.open(preview_path).convert("RGB")
            preview.thumbnail((640, 360), Image.Resampling.NEAREST)
            thumbnails.append((slug, preview.copy()))

    args.report_output.parent.mkdir(parents=True, exist_ok=True)
    args.report_output.write_text(
        json.dumps(
            {
                "schema": "fantasydisk.responsive_fit.v1",
                "issue": "SCRUM-1090",
                "ok": all(item["ok"] for item in matrix),
                "source_layout": str(args.layout),
                "matrix": matrix,
                "runtime_note": "Source-only PixelLab reference; accepted SCRUM-1075 runtime geometry remains authoritative.",
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )

    sheet = Image.new("RGB", (1920, 390), (4, 7, 18))
    draw = ImageDraw.Draw(sheet)
    for index, (slug, preview) in enumerate(thumbnails):
        x = index * 640
        sheet.paste(preview, (x, 30))
        draw.text((x + 10, 7), slug, fill=(242, 213, 138))
    args.contact_output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(args.contact_output)


if __name__ == "__main__":
    main()
