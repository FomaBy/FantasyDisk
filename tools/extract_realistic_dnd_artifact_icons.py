#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageFilter


PROJECT_ROOT = Path(__file__).resolve().parents[1]
GENERATED_ROOT = Path(
    "/Users/sergeyfomin/.codex/generated_images/019eabf1-6d54-7561-8af9-ce25cdf483a9"
)
ARTIFACT_DIR = PROJECT_ROOT / "assets/sprites/ui/icons/artifacts"
PREVIEW_PATH = PROJECT_ROOT / "assets/sprites/ui/icons/artifact_realistic_dnd_preview.png"


SHEET_GROUPS = [
    [
        "warrior_charm",
        "fox_boots",
        "glass_orb",
        "hawk_lens",
        "ember_core",
        "old_codex",
    ],
    [
        "stone_heart",
        "banner_seed",
        "red_whetstone",
        "star_compass",
        "living_root",
        "captains_coin",
    ],
    [
        "quickstring",
        "heavy_totem",
        "splinter_gloves",
        "wide_sigil",
        "swift_ink",
        "summoners_bell",
    ],
    [
        "blood_sigil",
        "void_ink",
        "echo_pick",
        "sturdy_amulet",
        "fast_boots",
        "magnetic_buckle",
    ],
    [
        "silver_coin",
        "survival_manual",
        "cracked_shield",
        "sharp_talisman",
        "jagged_blade",
        "heavy_grip",
    ],
    [
        "war_belt",
        "warriors_rage",
        "dark_crystal",
        "ash_page",
        "skull_resonator",
        "ink_candle",
    ],
    [
        "copper_string",
        "broken_pick",
        "loud_amp",
        "bass_cable",
        "cursed_crown",
        "fragile_heart",
    ],
    [
        "greedy_purse",
        "burning_shard",
        "golden_route_mark",
        "glass_edge",
        "echo_core",
        "split_core",
    ],
    [
        "blood_pact",
        "leech_heart",
        "thorn_pact",
        "phantom_step",
        "leech_fang",
    ],
]


def latest_source_sheets() -> list[Path]:
    sheets = sorted(GENERATED_ROOT.glob("*.png"), key=lambda p: p.stat().st_mtime, reverse=True)[:9]
    if len(sheets) != 9:
        raise RuntimeError(f"Expected 9 generated source sheets, found {len(sheets)}")
    return list(reversed(sheets))


def remove_green_screen(cell: Image.Image) -> Image.Image:
    rgba = cell.convert("RGBA")
    pix = rgba.load()
    width, height = rgba.size
    for y in range(height):
        for x in range(width):
            r, g, b, a = pix[x, y]
            if g > 135 and r < 115 and b < 115 and g > r * 1.35 and g > b * 1.35:
                pix[x, y] = (r, g, b, 0)
            elif g > 105 and r < 150 and b < 150 and g > r * 1.12 and g > b * 1.12:
                softness = min(255, int((g - max(r, b)) * 2.4))
                pix[x, y] = (r, g, b, max(0, a - softness))

    alpha = rgba.getchannel("A").filter(ImageFilter.MedianFilter(3))
    rgba.putalpha(alpha)
    return rgba


def trim_and_fit(item: Image.Image) -> Image.Image:
    bbox = item.getchannel("A").getbbox()
    if bbox is None:
        raise RuntimeError("Empty crop after chroma key")

    item = item.crop(bbox)
    pad = 14
    canvas = Image.new("RGBA", (item.width + pad * 2, item.height + pad * 2), (0, 0, 0, 0))
    canvas.alpha_composite(item, (pad, pad))

    scale = min(224 / canvas.width, 224 / canvas.height)
    new_size = (max(1, round(canvas.width * scale)), max(1, round(canvas.height * scale)))
    item = canvas.resize(new_size, Image.Resampling.LANCZOS)

    out = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    out.alpha_composite(item, ((256 - item.width) // 2, (256 - item.height) // 2))
    return out


def extract_icons() -> list[str]:
    ARTIFACT_DIR.mkdir(parents=True, exist_ok=True)
    sheet_paths = latest_source_sheets()
    written: list[str] = []

    for sheet_path, artifact_ids in zip(sheet_paths, SHEET_GROUPS):
        sheet = Image.open(sheet_path).convert("RGB")
        cell_w = sheet.width // 3
        cell_h = sheet.height // 2
        for index, artifact_id in enumerate(artifact_ids):
            col = index % 3
            row = index // 3
            cell = sheet.crop((col * cell_w, row * cell_h, (col + 1) * cell_w, (row + 1) * cell_h))
            icon = trim_and_fit(remove_green_screen(cell))
            out_path = ARTIFACT_DIR / f"artifact_{artifact_id}.png"
            icon.save(out_path)
            written.append(artifact_id)

    return written


def build_preview(artifact_ids: list[str]) -> None:
    cols = 8
    tile = 160
    rows = (len(artifact_ids) + cols - 1) // cols
    preview = Image.new("RGBA", (cols * tile, rows * tile), (18, 16, 18, 255))
    draw = ImageDraw.Draw(preview)
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 12)
    except OSError:
        font = ImageFont.load_default()

    for index, artifact_id in enumerate(artifact_ids):
        x = (index % cols) * tile
        y = (index // cols) * tile
        icon = Image.open(ARTIFACT_DIR / f"artifact_{artifact_id}.png").convert("RGBA")
        large = icon.resize((112, 112), Image.Resampling.LANCZOS)
        small = icon.resize((40, 40), Image.Resampling.LANCZOS)
        draw.rounded_rectangle((x + 8, y + 8, x + tile - 8, y + tile - 8), radius=12, fill=(33, 29, 34, 255), outline=(95, 72, 48, 255), width=2)
        preview.alpha_composite(large, (x + 24, y + 10))
        preview.alpha_composite(small, (x + 10, y + 104))
        draw.text((x + 54, y + 108), artifact_id.replace("_", " "), fill=(226, 210, 174, 255), font=font)

    preview.save(PREVIEW_PATH)


def validate(artifact_ids: list[str]) -> None:
    problems = []
    for artifact_id in artifact_ids:
        path = ARTIFACT_DIR / f"artifact_{artifact_id}.png"
        im = Image.open(path).convert("RGBA")
        alpha_bbox = im.getchannel("A").getbbox()
        if im.size != (256, 256):
            problems.append(f"{path.name}: size {im.size}")
        if alpha_bbox is None:
            problems.append(f"{path.name}: empty alpha")
        else:
            left, top, right, bottom = alpha_bbox
            if right - left < 42 or bottom - top < 42:
                problems.append(f"{path.name}: item too small {alpha_bbox}")
        tiny = im.resize((40, 40), Image.Resampling.LANCZOS)
        if tiny.getchannel("A").getbbox() is None:
            problems.append(f"{path.name}: unreadable at 40px")

    if problems:
        raise RuntimeError("\n".join(problems))


def main() -> None:
    artifact_ids = extract_icons()
    build_preview(artifact_ids)
    validate(artifact_ids)
    print(f"Extracted {len(artifact_ids)} realistic DnD raster artifact icons")
    print(PREVIEW_PATH)


if __name__ == "__main__":
    main()
