#!/usr/bin/env python3
from __future__ import annotations

from collections import deque
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "docs/design/references/UiFrame/frame_kit_ornate_dark_sheet_b_spec.png"
OUT_DIR = ROOT / "assets/sprites/ui/frames/ornate"
PREVIEW = ROOT / "docs/design/previews/ornate_dark_frame_kit_contact.png"
BACKUP_DIR = ROOT / "build/cleanup_backup_ornate_frames_2026_06_14"


FRAMES = {
    "global_panel": {
        "box": (18, 104, 350, 414),
        "texture": (34, 34, 34, 34),
        "content": (28, 26, 28, 26),
        "label": "Global Panel",
    },
    "level_panel": {
        "box": (370, 104, 692, 414),
        "texture": (46, 46, 46, 46),
        "content": (34, 30, 34, 30),
        "label": "Level Panel",
    },
    "card_frame": {
        "box": (744, 104, 938, 414),
        "texture": (28, 28, 28, 28),
        "content": (7, 7, 7, 7),
        "label": "List/Card",
    },
    "hero_card": {
        "box": (994, 104, 1208, 416),
        "texture": (28, 28, 28, 28),
        "content": (8, 8, 8, 8),
        "label": "Hero/Card",
    },
    "card_hover": {
        "box": (1272, 112, 1512, 416),
        "texture": (30, 30, 30, 30),
        "content": (16, 14, 16, 14),
        "label": "Card Hover",
    },
    "tooltip": {
        "box": (26, 542, 324, 704),
        "texture": (26, 26, 26, 26),
        "content": (14, 12, 14, 12),
        "label": "Tooltip",
    },
    "hud_panel": {
        "box": (326, 542, 672, 704),
        "texture": (28, 22, 28, 24),
        "content": (10, 9, 10, 9),
        "label": "HUD Panel",
    },
    "hud_card": {
        "box": (694, 550, 934, 694),
        "texture": (22, 18, 22, 20),
        "content": (8, 7, 8, 7),
        "label": "HUD Card",
    },
    "timer_panel": {
        "box": (972, 546, 1218, 694),
        "texture": (34, 24, 34, 24),
        "content": (14, 4, 14, 4),
        "label": "Timer",
    },
    "pause_main": {
        "box": (1222, 528, 1510, 730),
        "texture": (40, 40, 40, 40),
        "content": (24, 24, 24, 24),
        "label": "Pause Main",
    },
    "pause_stat_group": {
        "box": (160, 872, 474, 994),
        "texture": (34, 30, 34, 34),
        "content": (14, 12, 14, 14),
        "label": "Pause Group",
    },
    "pause_stat_chip": {
        "box": (622, 876, 966, 974),
        "texture": (20, 12, 20, 14),
        "content": (8, 4, 8, 4),
        "label": "Stat Chip",
    },
    "pause_stat_tooltip": {
        "box": (1048, 868, 1378, 996),
        "texture": (34, 30, 34, 34),
        "content": (18, 16, 18, 16),
        "label": "Stat Tooltip",
    },
}


def flood_alpha(crop: Image.Image) -> Image.Image:
    rgba = crop.convert("RGBA")
    px = rgba.load()
    width, height = rgba.size
    bg_samples = [
        crop.convert("RGB").getpixel((0, 0)),
        crop.convert("RGB").getpixel((width - 1, 0)),
        crop.convert("RGB").getpixel((0, height - 1)),
        crop.convert("RGB").getpixel((width - 1, height - 1)),
    ]
    bg = tuple(sum(sample[i] for sample in bg_samples) // len(bg_samples) for i in range(3))

    def removable(color: tuple[int, int, int, int]) -> bool:
        r, g, b, _a = color
        dist = abs(r - bg[0]) + abs(g - bg[1]) + abs(b - bg[2])
        return dist < 54 and max(r, g, b) < 82

    queue: deque[tuple[int, int]] = deque()
    seen: set[tuple[int, int]] = set()
    for x in range(width):
        queue.append((x, 0))
        queue.append((x, height - 1))
    for y in range(height):
        queue.append((0, y))
        queue.append((width - 1, y))

    while queue:
        x, y = queue.popleft()
        if (x, y) in seen or x < 0 or y < 0 or x >= width or y >= height:
            continue
        seen.add((x, y))
        if not removable(px[x, y]):
            continue
        px[x, y] = (0, 0, 0, 0)
        queue.append((x + 1, y))
        queue.append((x - 1, y))
        queue.append((x, y + 1))
        queue.append((x, y - 1))

    return rgba


def backup_old_panels() -> None:
    BACKUP_DIR.mkdir(parents=True, exist_ok=True)
    old_paths = [
        ROOT / "assets/sprites/ui/frames/leather_gold",
        ROOT / "assets/sprites/ui/frames/dark_fantasy/ui_df_panel_frame.png",
        ROOT / "assets/sprites/ui/frames/dark_fantasy/ui_df_card_frame.png",
        ROOT / "assets/sprites/ui/frames/dark_fantasy/ui_df_level_panel_frame.png",
        ROOT / "assets/sprites/ui/frames/dark_fantasy/ui_df_hud_panel_frame.png",
        ROOT / "assets/sprites/ui/frames/dark_fantasy/ui_df_hud_card_frame.png",
        ROOT / "assets/sprites/ui/frames/dark_fantasy/ui_df_tooltip_frame.png",
        ROOT / "assets/sprites/ui/frames/escape/ui_escape_panel_frame.png",
        ROOT / "assets/sprites/ui/frames/escape/ui_stat_basic_row_frame.png",
        ROOT / "assets/sprites/ui/frames/escape/ui_stat_group_frame.png",
        ROOT / "assets/sprites/ui/frames/escape/ui_stat_chip_frame.png",
        ROOT / "assets/sprites/ui/frames/escape/ui_stat_tooltip_frame.png",
    ]
    for path in old_paths:
        if path.is_dir():
            for child in path.iterdir():
                if child.is_file():
                    (BACKUP_DIR / f"leather_gold_{child.name}").write_bytes(child.read_bytes())
        elif path.exists():
            (BACKUP_DIR / path.name).write_bytes(path.read_bytes())


def build_preview(paths: list[Path]) -> None:
    cell_w, cell_h = 380, 220
    columns = 3
    rows = (len(paths) + columns - 1) // columns
    preview = Image.new("RGBA", (columns * cell_w, rows * cell_h), (12, 10, 10, 255))
    draw = ImageDraw.Draw(preview)
    for idx, path in enumerate(paths):
        frame = Image.open(path).convert("RGBA")
        thumb = frame.copy()
        thumb.thumbnail((cell_w - 40, cell_h - 58), Image.Resampling.LANCZOS)
        x = (idx % columns) * cell_w + (cell_w - thumb.width) // 2
        y = (idx // columns) * cell_h + 34
        preview.alpha_composite(thumb, (x, y))
        draw.text(((idx % columns) * cell_w + 16, (idx // columns) * cell_h + 10), path.stem, fill=(245, 205, 130, 255))
    PREVIEW.parent.mkdir(parents=True, exist_ok=True)
    preview.save(PREVIEW)


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    backup_old_panels()
    source = Image.open(SOURCE).convert("RGB")
    written: list[Path] = []
    for frame_id, spec in FRAMES.items():
        crop = source.crop(spec["box"])
        rgba = flood_alpha(crop)
        out = OUT_DIR / f"ui_frame_ornate_{frame_id}.png"
        rgba.save(out)
        written.append(out)
    build_preview(written)
    print(f"Built {len(written)} ornate frames into {OUT_DIR}")
    print(f"Preview: {PREVIEW}")
    print(f"Old panel backup: {BACKUP_DIR}")


if __name__ == "__main__":
    main()
