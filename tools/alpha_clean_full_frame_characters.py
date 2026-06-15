"""Clean white matte backgrounds from full-frame character PNGs.

SCRUM-412: generated character frames can have a transparent outer canvas while
still carrying an opaque white/near-white rectangle inside the visible alpha
bounds. This tool removes only edge-connected near-white matte pixels and their
halo, preserving isolated light costume/effect details whenever they are not
connected to the background.

Usage:
    python3 tools/alpha_clean_full_frame_characters.py --write --check
"""
from __future__ import annotations

import argparse
import json
import shutil
from collections import deque
from pathlib import Path
from typing import Iterable

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_ROOT = ROOT / "assets/sprites/characters/full_frame"
DEFAULT_QA = ROOT / "build/qa/scrum412_character_alpha"


def _is_background_candidate(pixel: tuple[int, int, int, int]) -> bool:
    r, g, b, a = pixel
    if a <= 8:
        return False
    hi = max(r, g, b)
    lo = min(r, g, b)
    neutral_white = hi >= 224 and lo >= 216 and hi - lo <= 42
    checker_black = a >= 220 and hi <= 20 and hi - lo <= 8
    return neutral_white or checker_black


def _is_soft_halo_candidate(pixel: tuple[int, int, int, int]) -> bool:
    r, g, b, a = pixel
    if a <= 8:
        return False
    hi = max(r, g, b)
    lo = min(r, g, b)
    return hi >= 214 and lo >= 188 and hi - lo <= 76


def _neighbors(x: int, y: int, width: int, height: int) -> Iterable[tuple[int, int]]:
    if x > 0:
        yield x - 1, y
    if x + 1 < width:
        yield x + 1, y
    if y > 0:
        yield x, y - 1
    if y + 1 < height:
        yield x, y + 1


def _visible_bbox(im: Image.Image) -> tuple[int, int, int, int] | None:
    return im.getchannel("A").point(lambda value: 255 if value > 8 else 0).getbbox()


def _seed_points(im: Image.Image, bbox: tuple[int, int, int, int]) -> list[tuple[int, int]]:
    px = im.load()
    width, height = im.size
    x0, y0, x1, y1 = bbox
    seeds: list[tuple[int, int]] = []

    for x in range(x0, x1):
        for y in (y0, y1 - 1):
            if _is_background_candidate(px[x, y]):
                seeds.append((x, y))
    for y in range(y0, y1):
        for x in (x0, x1 - 1):
            if _is_background_candidate(px[x, y]):
                seeds.append((x, y))

    # Some frames have a transparent moat around an opaque white card. Seeding
    # pixels adjacent to real transparency catches that card edge without
    # deleting isolated white details inside the character.
    for y in range(y0, y1):
        for x in range(x0, x1):
            if not _is_background_candidate(px[x, y]):
                continue
            for nx, ny in _neighbors(x, y, width, height):
                if px[nx, ny][3] <= 8:
                    seeds.append((x, y))
                    break
    return seeds


def clean_image(im: Image.Image) -> tuple[Image.Image, dict[str, int | list[int] | None]]:
    """Return an alpha-cleaned RGBA image and a small QA stat payload."""
    rgba = im.convert("RGBA")
    bbox = _visible_bbox(rgba)
    if bbox is None:
        return rgba, {
            "removed_pixels": 0,
            "halo_pixels": 0,
            "bbox_before": None,
            "bbox_after": None,
            "floodable_background_after": 0,
        }

    px = rgba.load()
    width, height = rgba.size
    mask: set[tuple[int, int]] = set()
    queue: deque[tuple[int, int]] = deque()

    for point in _seed_points(rgba, bbox):
        if point not in mask:
            mask.add(point)
            queue.append(point)

    while queue:
        x, y = queue.popleft()
        for nx, ny in _neighbors(x, y, width, height):
            point = (nx, ny)
            if point in mask:
                continue
            if _is_background_candidate(px[nx, ny]):
                mask.add(point)
                queue.append(point)

    halo: set[tuple[int, int]] = set()
    frontier = set(mask)
    for _ in range(2):
        next_frontier: set[tuple[int, int]] = set()
        for x, y in frontier:
            for nx, ny in _neighbors(x, y, width, height):
                point = (nx, ny)
                if point in mask or point in halo:
                    continue
                if _is_soft_halo_candidate(px[nx, ny]):
                    halo.add(point)
                    next_frontier.add(point)
        frontier = next_frontier

    for x, y in mask | halo:
        px[x, y] = (0, 0, 0, 0)

    after_bbox = _visible_bbox(rgba)
    return rgba, {
        "removed_pixels": len(mask),
        "halo_pixels": len(halo),
        "bbox_before": list(bbox),
        "bbox_after": list(after_bbox) if after_bbox else None,
        "floodable_background_after": count_floodable_background(rgba),
    }


def count_floodable_background(im: Image.Image) -> int:
    rgba = im.convert("RGBA")
    bbox = _visible_bbox(rgba)
    if bbox is None:
        return 0
    px = rgba.load()
    width, height = rgba.size
    seen: set[tuple[int, int]] = set()
    queue: deque[tuple[int, int]] = deque()
    for point in _seed_points(rgba, bbox):
        if point not in seen:
            seen.add(point)
            queue.append(point)
    while queue:
        x, y = queue.popleft()
        for nx, ny in _neighbors(x, y, width, height):
            point = (nx, ny)
            if point in seen:
                continue
            if _is_background_candidate(px[nx, ny]):
                seen.add(point)
                queue.append(point)
    return len(seen)


def edge_white_pixels(im: Image.Image, ring_width: int = 8) -> int:
    rgba = im.convert("RGBA")
    px = rgba.load()
    width, height = rgba.size
    total = 0
    for y in range(height):
        for x in range(width):
            if not (x < ring_width or y < ring_width or x >= width - ring_width or y >= height - ring_width):
                continue
            if _is_background_candidate(px[x, y]):
                total += 1
    return total


def iter_frames(root: Path) -> list[Path]:
    return sorted(path for path in root.glob("*/*.png") if path.is_file())


def backup_file(path: Path, backup_root: Path) -> None:
    target = backup_root / path.relative_to(ROOT)
    if target.exists():
        return
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(path, target)


def make_contact_sheet(paths: list[Path], out_path: Path) -> None:
    classes: dict[str, Path] = {}
    for path in paths:
        class_id = path.parent.name
        if class_id not in classes and path.name.endswith("_idle_00.png"):
            classes[class_id] = path
    if not classes:
        return
    tile_w, tile_h = 176, 216
    cols = 6
    rows = (len(classes) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * tile_w, rows * tile_h), (16, 13, 18, 255))
    draw = ImageDraw.Draw(sheet)
    for index, (class_id, path) in enumerate(sorted(classes.items())):
        frame = Image.open(path).convert("RGBA")
        frame.thumbnail((144, 164), Image.Resampling.LANCZOS)
        x = (index % cols) * tile_w
        y = (index // cols) * tile_h
        # Dark checker/plate exposes any remaining white matte immediately.
        draw.rectangle((x + 12, y + 10, x + tile_w - 12, y + 174), fill=(10, 9, 12, 255), outline=(71, 58, 76, 255))
        sheet.alpha_composite(frame, (x + (tile_w - frame.width) // 2, y + 22))
        draw.text((x + 14, y + 184), class_id, fill=(232, 222, 203, 255))
    out_path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out_path)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=DEFAULT_ROOT)
    parser.add_argument("--write", action="store_true", help="rewrite PNGs in place")
    parser.add_argument("--check", action="store_true", help="fail if floodable white matte remains")
    parser.add_argument("--report", type=Path, default=DEFAULT_QA / "alpha_clean_report.json")
    parser.add_argument("--preview", type=Path, default=DEFAULT_QA / "character_alpha_dark_bg_contact.png")
    parser.add_argument("--backup-dir", type=Path, default=DEFAULT_QA / "originals")
    parser.add_argument(
        "--max-floodable-background",
        type=int,
        default=1500,
        help="allowed tiny near-white detail count on the tightened alpha bbox",
    )
    args = parser.parse_args()

    root = args.root if args.root.is_absolute() else ROOT / args.root
    paths = iter_frames(root)
    report: list[dict[str, object]] = []
    failures: list[str] = []

    for path in paths:
        before = Image.open(path).convert("RGBA")
        cleaned, stats = clean_image(before)
        after_edge_white = edge_white_pixels(cleaned)
        item = {
            "path": str(path.relative_to(ROOT)),
            "size": list(cleaned.size),
            "removed_pixels": stats["removed_pixels"],
            "halo_pixels": stats["halo_pixels"],
            "bbox_before": stats["bbox_before"],
            "bbox_after": stats["bbox_after"],
            "floodable_background_after": stats["floodable_background_after"],
            "edge_white_after": after_edge_white,
        }
        report.append(item)
        if args.write and (stats["removed_pixels"] or stats["halo_pixels"]):
            backup_file(path, args.backup_dir if args.backup_dir.is_absolute() else ROOT / args.backup_dir)
            cleaned.save(path)
        if args.check and (
            after_edge_white or int(stats["floodable_background_after"]) > args.max_floodable_background
        ):
            failures.append(str(path.relative_to(ROOT)))

    args.report.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "frame_count": len(report),
        "changed_count": sum(1 for item in report if item["removed_pixels"] or item["halo_pixels"]),
        "removed_pixels": sum(int(item["removed_pixels"]) for item in report),
        "halo_pixels": sum(int(item["halo_pixels"]) for item in report),
        "max_floodable_background": args.max_floodable_background,
        "failures": failures,
        "frames": report,
    }
    args.report.write_text(json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    make_contact_sheet(paths, args.preview)

    print(
        f"frames={payload['frame_count']} changed={payload['changed_count']} "
        f"removed={payload['removed_pixels']} halo={payload['halo_pixels']} failures={len(failures)}"
    )
    print(f"report={args.report}")
    print(f"preview={args.preview}")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
