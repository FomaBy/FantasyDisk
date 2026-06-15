#!/usr/bin/env python3
from __future__ import annotations

from collections import deque
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
REF_DIR = ROOT / "docs/design/references/wolfanimate"
OUT_DIR = ROOT / "assets/sprites/allies/druid_wolf"
QA_DIR = ROOT / "build/qa/druid_wolf_summon_animation"
CANVAS_SIZE = (256, 224)
BOTTOM_Y = 204
MAX_VISUAL = (236, 188)


SHEETS = {
    "move": {
        "path": REF_DIR / "Wolfmoving.png",
        "frames": 8,
        "fps": 12,
        "loop": True,
    },
    "attack": {
        "path": REF_DIR / "wolfattacking.png",
        "frames": 6,
        "fps": 14,
        "loop": False,
    },
}


def _is_bg(pixel: tuple[int, int, int, int]) -> bool:
    r, g, b, _a = pixel
    return min(r, g, b) >= 218 and (max(r, g, b) - min(r, g, b)) <= 28


def _remove_edge_background(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    w, h = rgba.size
    pix = rgba.load()
    visited = bytearray(w * h)
    queue: deque[tuple[int, int]] = deque()
    for x in range(w):
        queue.append((x, 0))
        queue.append((x, h - 1))
    for y in range(h):
        queue.append((0, y))
        queue.append((w - 1, y))

    while queue:
        x, y = queue.popleft()
        if x < 0 or y < 0 or x >= w or y >= h:
            continue
        idx = y * w + x
        if visited[idx]:
            continue
        visited[idx] = 1
        if not _is_bg(pix[x, y]):
            continue
        pix[x, y] = (255, 255, 255, 0)
        queue.append((x + 1, y))
        queue.append((x - 1, y))
        queue.append((x, y + 1))
        queue.append((x, y - 1))

    alpha = rgba.getchannel("A")
    # Remove tiny isolated checker remnants without touching the wolf silhouette.
    cleaned = alpha.point(lambda a: 0 if a < 8 else a)
    rgba.putalpha(cleaned)
    return rgba


def _trim_and_canvas(frame: Image.Image) -> Image.Image:
    bbox = frame.getchannel("A").getbbox()
    if bbox is None:
        return Image.new("RGBA", CANVAS_SIZE, (0, 0, 0, 0))
    cropped = frame.crop(bbox)
    scale = min(MAX_VISUAL[0] / cropped.width, MAX_VISUAL[1] / cropped.height)
    scaled_size = (max(1, round(cropped.width * scale)), max(1, round(cropped.height * scale)))
    cropped = cropped.resize(scaled_size, Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", CANVAS_SIZE, (0, 0, 0, 0))
    x = (CANVAS_SIZE[0] - cropped.width) // 2
    y = BOTTOM_Y - cropped.height
    canvas.alpha_composite(cropped, (x, y))
    return canvas


def _component_bboxes(image: Image.Image, min_area: int) -> list[tuple[int, int, int, int]]:
    alpha = image.getchannel("A")
    w, h = alpha.size
    pix = alpha.load()
    visited = bytearray(w * h)
    boxes: list[tuple[int, int, int, int, int]] = []
    for y in range(h):
        for x in range(w):
            idx = y * w + x
            if visited[idx] or pix[x, y] == 0:
                continue
            queue: deque[tuple[int, int]] = deque([(x, y)])
            visited[idx] = 1
            min_x = max_x = x
            min_y = max_y = y
            area = 0
            while queue:
                cx, cy = queue.popleft()
                area += 1
                min_x = min(min_x, cx)
                max_x = max(max_x, cx)
                min_y = min(min_y, cy)
                max_y = max(max_y, cy)
                for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
                    if nx < 0 or ny < 0 or nx >= w or ny >= h:
                        continue
                    nidx = ny * w + nx
                    if visited[nidx] or pix[nx, ny] == 0:
                        continue
                    visited[nidx] = 1
                    queue.append((nx, ny))
            if area >= min_area:
                boxes.append((min_x, min_y, max_x + 1, max_y + 1, area))
    boxes.sort(key=lambda box: box[0])
    return [(x0, y0, x1, y1) for x0, y0, x1, y1, _area in boxes]


def _slice_sheet(sheet: Image.Image, count: int) -> list[Image.Image]:
    transparent = _remove_edge_background(sheet)
    bboxes = _component_bboxes(transparent, 1800)
    if len(bboxes) != count:
        width, height = sheet.size
        bboxes = [
            (round(width * i / count), 0, round(width * (i + 1) / count), height)
            for i in range(count)
        ]
    frames: list[Image.Image] = []
    for bbox in bboxes:
        pad = 8
        left = max(0, bbox[0] - pad)
        top = max(0, bbox[1] - pad)
        right = min(transparent.width, bbox[2] + pad)
        bottom = min(transparent.height, bbox[3] + pad)
        frames.append(_trim_and_canvas(transparent.crop((left, top, right, bottom))))
    return frames


def _make_contact(all_frames: dict[str, list[Image.Image]]) -> Image.Image:
    cell_w, cell_h = CANVAS_SIZE
    label_h = 28
    cols = max(len(frames) for frames in all_frames.values())
    rows = len(all_frames)
    contact = Image.new("RGBA", (cols * cell_w, rows * (cell_h + label_h)), (18, 16, 14, 255))
    draw = ImageDraw.Draw(contact)
    for row, (anim, frames) in enumerate(all_frames.items()):
        y0 = row * (cell_h + label_h)
        draw.text((8, y0 + 6), f"{anim} ({len(frames)} frames)", fill=(235, 220, 172, 255))
        for col, frame in enumerate(frames):
            x = col * cell_w
            y = y0 + label_h
            checker = Image.new("RGBA", CANVAS_SIZE, (42, 42, 42, 255))
            cd = ImageDraw.Draw(checker)
            for yy in range(0, cell_h, 16):
                for xx in range(0, cell_w, 16):
                    if ((xx // 16) + (yy // 16)) % 2 == 0:
                        cd.rectangle((xx, yy, xx + 15, yy + 15), fill=(58, 58, 58, 255))
            checker.alpha_composite(frame)
            contact.alpha_composite(checker, (x, y))
            draw.rectangle((x, y, x + cell_w - 1, y + cell_h - 1), outline=(96, 82, 56, 255))
    return contact


def _write_gif(path: Path, frames: list[Image.Image], duration_ms: int) -> None:
    bg = Image.new("RGBA", CANVAS_SIZE, (24, 22, 20, 255))
    composited = []
    for frame in frames:
        canvas = bg.copy()
        canvas.alpha_composite(frame)
        composited.append(canvas.convert("P", palette=Image.Palette.ADAPTIVE))
    composited[0].save(path, save_all=True, append_images=composited[1:], duration=duration_ms, loop=0, disposal=2)


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    QA_DIR.mkdir(parents=True, exist_ok=True)
    all_frames: dict[str, list[Image.Image]] = {}
    for anim, info in SHEETS.items():
        sheet = Image.open(info["path"]).convert("RGBA")
        frames = _slice_sheet(sheet, int(info["frames"]))
        all_frames[anim] = frames
        for index, frame in enumerate(frames):
            frame.save(OUT_DIR / f"ally_druid_wolf_{anim}_{index:02d}.png")
        _write_gif(QA_DIR / f"ally_druid_wolf_{anim}.gif", frames, round(1000 / int(info["fps"])))

    _make_contact(all_frames).save(QA_DIR / "ally_druid_wolf_frames_contact.png")
    manifest_lines = [
        "# Druid Wolf Animation Frames",
        "",
        f"- Canvas: `{CANVAS_SIZE[0]}x{CANVAS_SIZE[1]}`",
        f"- Pivot handoff: bottom-center at `(128, {BOTTOM_Y})`",
        f"- Runtime scale recommendation: `0.34` on `AnimatedSprite2D`",
    ]
    for anim, frames in all_frames.items():
        info = SHEETS[anim]
        manifest_lines.append(f"- `{anim}`: {len(frames)} frames, fps={info['fps']}, loop={info['loop']}")
    (QA_DIR / "ally_druid_wolf_manifest.md").write_text("\n".join(manifest_lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
