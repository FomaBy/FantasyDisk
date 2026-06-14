"""Turn a generated character source sheet into a game-ready normalized sheet.

The fantasydisk-asset-generator (gpt-image-2) produces a 1920x1152, 5x3 sheet
(idle / walk / attack_primary, 5 frames each) but on a WHITE background (the
model ignores transparent/chroma requests). This tool:

1. Removes the background with a border flood-fill (keeps light details inside
   the character, unlike a global white key).
2. Per cell: autocrops the figure, scales tall figures down to fit, and anchors
   it to the canonical pivot (192, 348) in a clean 384 cell — feet centered at
   the bottom so the walk/attack cycles do not jitter.
3. Writes `assets/sprites/characters/<class_id>_sheet.png` (auto-loaded by
   player.gd `_character_sheet_sprite_frames`) plus a scaled contact preview.

Usage:
    python3 tools/build_character_sheet.py <class_id> [source_png]

Default source: docs/design/references/characters/<class_id>/<class_id>_sheet_source.png
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
CELL = 384
COLS = 5
PIVOT = (192, 348)
MAX_BODY_H = 320
KEY = (0, 255, 1)


def remove_background(im: Image.Image) -> Image.Image:
    im = im.convert("RGB")
    W, H = im.size
    seeds = [(1, 1), (W - 2, 1), (1, H - 2), (W - 2, H - 2),
             (W // 2, 1), (W // 2, H - 2), (1, H // 2), (W - 2, H // 2)]
    for s in seeds:
        try:
            ImageDraw.floodfill(im, s, KEY, thresh=36)
        except Exception:
            pass
    rgba = im.convert("RGBA")
    px = rgba.load()
    for y in range(H):
        for x in range(W):
            if px[x, y][:3] == KEY:
                px[x, y] = (0, 0, 0, 0)
    return rgba


def normalize(src: Image.Image) -> Image.Image:
    W, H = src.size
    rows = H // CELL
    out = Image.new("RGBA", (COLS * CELL, rows * CELL), (0, 0, 0, 0))
    for ry in range(rows):
        for cx in range(COLS):
            cell = src.crop((cx * CELL, ry * CELL, (cx + 1) * CELL, (ry + 1) * CELL))
            bb = cell.getbbox()
            if not bb:
                continue
            fig = cell.crop(bb)
            fw, fh = fig.size
            if fh > MAX_BODY_H:
                s = MAX_BODY_H / fh
                fig = fig.resize((max(1, int(fw * s)), MAX_BODY_H), Image.LANCZOS)
                fw, fh = fig.size
            x = PIVOT[0] - fw // 2
            y = PIVOT[1] - fh
            x = max(8, min(x, CELL - fw - 8))
            cell_out = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
            cell_out.alpha_composite(fig, (x, max(8, y)))
            out.alpha_composite(cell_out, (cx * CELL, ry * CELL))
    return out


ROW_ANIMS = {0: "idle", 1: "walk", 2: "attack_primary"}


def slice_frames(class_id: str, sheet: Image.Image) -> list[Path]:
    """Cut the normalized sheet into the canonical full_frame/<class>/ frames."""
    out_dir = ROOT / "assets/sprites/characters/full_frame" / class_id
    out_dir.mkdir(parents=True, exist_ok=True)
    written: list[Path] = []
    rows = sheet.height // CELL
    for ry in range(min(rows, 3)):
        anim = ROW_ANIMS[ry]
        for cx in range(COLS):
            frame = sheet.crop((cx * CELL, ry * CELL, (cx + 1) * CELL, (ry + 1) * CELL))
            fp = out_dir / f"{class_id}_{anim}_{cx:02d}.png"
            frame.save(fp)
            written.append(fp)
    return written


def write_tres(class_id: str) -> Path | None:
    """Author a SpriteFrames .tres referencing the sliced frames, if absent."""
    tres = ROOT / "assets/sprites/characters" / f"{class_id}_spriteframes.tres"
    if tres.exists():
        return None  # owned elsewhere; never clobber
    rel = f"res://assets/sprites/characters/full_frame/{class_id}"
    order = [("idle", True, 5.0), ("walk", True, 10.0), ("attack_primary", False, 14.0), ("attack", False, 14.0)]
    ext, idx = [], {}
    counter = 1
    for anim, _loop, _fps in [("idle", 0, 0), ("walk", 0, 0), ("attack_primary", 0, 0)]:
        for i in range(5):
            rid = f"{counter}_{class_id[:3]}{counter}"
            ext.append(f'[ext_resource type="Texture2D" path="{rel}/{class_id}_{anim}_{i:02d}.png" id="{rid}"]')
            idx[(anim, i)] = rid
            counter += 1
    lines = ['[gd_resource type="SpriteFrames" format=3]', ""] + ext + ["", "[resource]", "animations = ["]
    for anim, loop, fps in order:
        src_anim = "attack_primary" if anim == "attack" else anim
        lines.append("{")
        lines.append('"frames": [')
        for i in range(5):
            lines += ["{", '"duration": 1.0,', f'"texture": ExtResource("{idx[(src_anim, i)]}")', "}" + ("," if i < 4 else "")]
        lines.append("],")
        lines.append(f'"loop": {"true" if loop else "false"},')
        lines.append(f'"name": &"{anim}",')
        lines.append(f'"speed": {fps}')
        lines.append("}," if anim != order[-1][0] else "}")
    lines.append("]")
    tres.write_text("\n".join(lines) + "\n")
    return tres


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: build_character_sheet.py <class_id> [source_png]", file=sys.stderr)
        return 2
    class_id = sys.argv[1]
    src_path = Path(sys.argv[2]) if len(sys.argv) > 2 else (
        ROOT / "docs/design/references/characters" / class_id / f"{class_id}_sheet_source.png")
    if not src_path.exists():
        print(f"error: source not found: {src_path}", file=sys.stderr)
        return 1

    keyed = remove_background(Image.open(src_path))
    keyed.save(src_path.with_name(f"{class_id}_sheet_keyed.png"))
    sheet = normalize(keyed)
    frames = slice_frames(class_id, sheet)
    tres = write_tres(class_id)
    prev = sheet.resize((sheet.width // 2, sheet.height // 2), Image.LANCZOS)
    prev_dir = ROOT / "docs/design/previews"
    prev_dir.mkdir(parents=True, exist_ok=True)
    prev.convert("RGB").save(prev_dir / f"{class_id}_sheet_normalized.png")
    tres_note = f"+ wrote {tres.name}" if tres else "(.tres exists, kept)"
    print(f"{class_id}: {len(frames)} frames {tres_note}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
