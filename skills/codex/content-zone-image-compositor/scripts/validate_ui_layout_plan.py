#!/usr/bin/env python3
"""Validate a pre-generation UI layout plan.

This is a planning gate for AI-generated UI art. It checks whether the requested
content can fit in exact rectangles before image generation starts, including
scrollbar decisions for overflowing content.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from typing import Any

from PIL import Image, ImageDraw, ImageFont


DEFAULT_FONTS = [
    "/System/Library/Fonts/Supplemental/Arial Unicode.ttf",
    "/System/Library/Fonts/Supplemental/Arial.ttf",
    "/Library/Fonts/Arial Unicode.ttf",
    "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
]


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser()
    p.add_argument("--plan", required=True, help="UI plan JSON")
    p.add_argument("--report", help="Output JSON report")
    p.add_argument("--guide-output", help="PNG guide with planned rectangles")
    return p.parse_args()


def load_json(path: str) -> dict[str, Any]:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def ensure_parent(path: str | None) -> None:
    if path:
        parent = os.path.dirname(os.path.abspath(path))
        if parent:
            os.makedirs(parent, exist_ok=True)


def font_path(preferred: str | None = None) -> str | None:
    for candidate in [preferred, *DEFAULT_FONTS]:
        if candidate and os.path.exists(candidate):
            return candidate
    return None


def load_font(size: int, preferred: str | None = None) -> ImageFont.ImageFont:
    path = font_path(preferred)
    if path:
        return ImageFont.truetype(path, size=size)
    return ImageFont.load_default()


def rect(e: dict[str, Any]) -> tuple[int, int, int, int]:
    return tuple(int(e[k]) for k in ("x", "y", "w", "h"))  # type: ignore[return-value]


def intersects(a: tuple[int, int, int, int], b: tuple[int, int, int, int]) -> bool:
    ax, ay, aw, ah = a
    bx, by, bw, bh = b
    return ax < bx + bw and ax + aw > bx and ay < by + bh and ay + ah > by


def inside(inner: tuple[int, int, int, int], outer: tuple[int, int, int, int]) -> bool:
    ix, iy, iw, ih = inner
    ox, oy, ow, oh = outer
    return ix >= ox and iy >= oy and ix + iw <= ox + ow and iy + ih <= oy + oh


def expanded(r: tuple[int, int, int, int], amount: int) -> tuple[int, int, int, int]:
    x, y, w, h = r
    return x - amount, y - amount, w + amount * 2, h + amount * 2


def text_value(e: dict[str, Any], content: dict[str, Any]) -> str:
    if "text" in e:
        return str(e["text"])
    if e.get("text_key"):
        return str(content.get(e["text_key"], ""))
    return ""


def text_fits(e: dict[str, Any], content: dict[str, Any]) -> tuple[bool, int | None, str | None]:
    text = text_value(e, content)
    if not text:
        return True, None, None
    x, y, w, h = rect(e)
    max_font = int(e.get("max_font", 32))
    min_font = int(e.get("min_font", 14))
    stroke_width = int(e.get("stroke_width", 0) or 0)
    line_spacing = float(e.get("line_spacing", 1.08))
    probe = Image.new("RGB", (max(w, 1), max(h, 1)), "black")
    draw = ImageDraw.Draw(probe)

    for size in range(max_font, min_font - 1, -1):
        font = load_font(size, e.get("font"))
        avg_char_w = max(1, size * 0.54)
        max_chars = max(1, int(w / avg_char_w))
        words = text.split()
        lines: list[str] = []
        cur = ""
        for word in words or [""]:
            trial = word if not cur else f"{cur} {word}"
            if len(trial) > max_chars and cur:
                lines.append(cur)
                cur = word
            else:
                cur = trial
        if cur:
            lines.append(cur)
        body = "\n".join(lines)
        spacing = max(0, int(size * (line_spacing - 1.0) + 2))
        bbox = draw.multiline_textbbox((0, 0), body, font=font, spacing=spacing, stroke_width=stroke_width)
        if bbox[2] - bbox[0] <= w and bbox[3] - bbox[1] <= h:
            return True, size, None
    return False, None, f"text does not fit at min_font={min_font}"


def scroll_content_height(e: dict[str, Any]) -> int | None:
    if "content_h" in e:
        return int(e["content_h"])
    if "item_count" in e and "item_h" in e:
        count = int(e["item_count"])
        item_h = int(e["item_h"])
        gap = int(e.get("item_gap", 0))
        pad_top = int(e.get("pad_top", e.get("padding", 0)))
        pad_bottom = int(e.get("pad_bottom", e.get("padding", 0)))
        return pad_top + pad_bottom + max(0, count * item_h + max(0, count - 1) * gap)
    return None


def validate(plan: dict[str, Any]) -> dict[str, Any]:
    canvas = plan.get("canvas", {})
    width = int(canvas.get("width", 0))
    height = int(canvas.get("height", 0))
    if width <= 0 or height <= 0:
        return {"ok": False, "decision": "revise_task", "errors": ["canvas.width/height must be positive"], "warnings": [], "elements": []}

    policy = plan.get("policy", {})
    min_gap = int(policy.get("min_gap", 0))
    allow_overlap = bool(policy.get("allow_overlap", False))
    content = plan.get("content", {})
    elements = plan.get("elements", [])
    by_id = {e.get("id"): e for e in elements}
    errors: list[str] = []
    warnings: list[str] = []
    reports: list[dict[str, Any]] = []

    seen: set[str] = set()
    for e in elements:
        eid = str(e.get("id", ""))
        if not eid:
            errors.append("element missing id")
            continue
        if eid in seen:
            errors.append(f"duplicate element id: {eid}")
        seen.add(eid)
        try:
            x, y, w, h = rect(e)
        except KeyError as exc:
            errors.append(f"{eid}: missing rect field {exc}")
            continue

        status = {"id": eid, "kind": e.get("kind", "zone"), "rect": [x, y, w, h], "ok": True, "warnings": []}
        if w <= 0 or h <= 0:
            status["ok"] = False
            errors.append(f"{eid}: width/height must be positive")
        if x < 0 or y < 0 or x + w > width or y + h > height:
            status["ok"] = False
            errors.append(f"{eid}: rect outside canvas")
        if "min_w" in e and w < int(e["min_w"]):
            status["ok"] = False
            errors.append(f"{eid}: width {w} below min_w {e['min_w']}")
        if "min_h" in e and h < int(e["min_h"]):
            status["ok"] = False
            errors.append(f"{eid}: height {h} below min_h {e['min_h']}")

        parent_id = e.get("parent")
        if parent_id:
            parent = by_id.get(parent_id)
            if not parent:
                status["ok"] = False
                errors.append(f"{eid}: missing parent {parent_id}")
            elif not e.get("allow_outside_parent") and not inside((x, y, w, h), rect(parent)):
                status["ok"] = False
                errors.append(f"{eid}: not inside parent {parent_id}")

        fits, font_size, reason = text_fits(e, content)
        if not fits:
            status["ok"] = False
            errors.append(f"{eid}: {reason}")
        if font_size:
            status["fit_font_size"] = font_size

        scroll_mode = e.get("scroll", "never")
        content_h = scroll_content_height(e)
        if content_h is not None:
            needs_scroll = content_h > h
            status["content_h"] = content_h
            status["scrollbar_required"] = needs_scroll
            if needs_scroll and scroll_mode == "never":
                status["ok"] = False
                errors.append(f"{eid}: content_h {content_h} exceeds h {h}, but scroll=never")
            if needs_scroll and scroll_mode in ("auto", "required"):
                scrollbar_w = int(e.get("scrollbar_w", 16))
                if w - scrollbar_w < int(e.get("min_content_w", 64)):
                    status["ok"] = False
                    errors.append(f"{eid}: scrollbar leaves too little content width")
                status["scrollbar_rect"] = [x + w - scrollbar_w, y, scrollbar_w, h]
            if not needs_scroll and scroll_mode == "required":
                warnings.append(f"{eid}: scroll=required but content fits without scrolling")
                status["warnings"].append("scroll required but not needed")

        reports.append(status)

    if not allow_overlap:
        colliders = [e for e in elements if e.get("collision", e.get("parent") is None)]
        for i, a in enumerate(colliders):
            for b in colliders[i + 1:]:
                if a.get("id") == b.get("parent") or b.get("id") == a.get("parent"):
                    continue
                ar = expanded(rect(a), min_gap)
                br = expanded(rect(b), min_gap)
                if intersects(ar, br):
                    errors.append(f"{a.get('id')} overlaps or violates min_gap with {b.get('id')}")

    ok = not errors
    return {
        "ok": ok,
        "decision": "ready_for_image" if ok else "revise_task",
        "errors": errors,
        "warnings": warnings,
        "elements": reports,
    }


def draw_guide(plan: dict[str, Any], report: dict[str, Any], path: str) -> None:
    canvas = plan["canvas"]
    width = int(canvas["width"])
    height = int(canvas["height"])
    img = Image.new("RGBA", (width, height), (17, 15, 20, 255))
    draw = ImageDraw.Draw(img)
    by_id = {e["id"]: e for e in report.get("elements", [])}
    font = load_font(16)

    for e in plan.get("elements", []):
        eid = str(e.get("id", ""))
        x, y, w, h = rect(e)
        status = by_id.get(eid, {})
        ok = bool(status.get("ok", True))
        needs_scroll = bool(status.get("scrollbar_required", False))
        outline = (54, 211, 153, 235) if ok else (255, 51, 102, 235)
        if needs_scroll:
            outline = (245, 184, 72, 245)
        fill = (outline[0], outline[1], outline[2], 34)
        draw.rectangle([x, y, x + w, y + h], fill=fill, outline=outline, width=3)
        if status.get("scrollbar_rect"):
            sx, sy, sw, sh = status["scrollbar_rect"]
            draw.rectangle([sx, sy, sx + sw, sy + sh], fill=(245, 184, 72, 80), outline=(245, 184, 72, 245), width=2)
        label = f"{eid} ({e.get('kind', 'zone')})"
        bbox = draw.textbbox((0, 0), label, font=font, stroke_width=2)
        lx = max(0, min(x + 6, width - (bbox[2] - bbox[0]) - 8))
        ly = y - (bbox[3] - bbox[1]) - 8 if y > 28 else y + 5
        lb = draw.textbbox((lx, ly), label, font=font, stroke_width=2)
        draw.rectangle(lb, fill=(0, 0, 0, 160))
        draw.text((lx, ly), label, font=font, fill=outline, stroke_width=2, stroke_fill=(0, 0, 0, 255))

    decision = report.get("decision", "unknown")
    summary = f"{decision} | errors={len(report.get('errors', []))} warnings={len(report.get('warnings', []))}"
    draw.rectangle([16, height - 42, width - 16, height - 12], fill=(0, 0, 0, 175))
    draw.text((26, height - 36), summary, font=font, fill=(247, 231, 189, 255))
    ensure_parent(path)
    img.convert("RGB").save(path)


def main() -> int:
    args = parse_args()
    plan = load_json(args.plan)
    report = validate(plan)
    if args.report:
        ensure_parent(args.report)
        with open(args.report, "w", encoding="utf-8") as f:
            json.dump(report, f, ensure_ascii=False, indent=2)
    if args.guide_output:
        draw_guide(plan, report, args.guide_output)
    if report["ok"]:
        return 0
    sys.stderr.write("UI plan requires revision before image generation.\n")
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
