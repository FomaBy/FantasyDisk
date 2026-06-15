#!/usr/bin/env python3
"""Cut SCRUM-332 economy UI frames from the generated source sheet."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "docs/design/references/ui_overhaul_shop_economy/scrum332_economy_frame_asset_sheet.png"
OUT_DIR = ROOT / "assets/sprites/ui/frames/economy"
REF_DIR = ROOT / "docs/design/references/ui_overhaul_shop_economy/runtime_assets"
PREVIEW = ROOT / "docs/design/previews/scrum332_shop_economy_frame_kit_contact.png"


ASSETS = [
    {
        "id": "economy_panel",
        "crop": (52, 48, 974, 620),
        "size": (1024, 640),
        "file": "ui_frame_economy_panel.png",
    },
    {
        "id": "economy_choice_card",
        "crop": (1019, 51, 1338, 648),
        "size": (512, 768),
        "file": "ui_frame_economy_choice_card.png",
    },
    {
        "id": "economy_choice_card_hover",
        "crop": (1372, 48, 1687, 649),
        "size": (512, 768),
        "file": "ui_frame_economy_choice_card_hover.png",
    },
    {
        "id": "economy_dragon_panel",
        "crop": (74, 678, 678, 996),
        "size": (1024, 512),
        "file": "ui_frame_economy_dragon_panel.png",
    },
    {
        "id": "economy_price_badge",
        "crop": (708, 740, 1100, 910),
        "size": (256, 96),
        "file": "ui_frame_economy_price_badge.png",
    },
    {
        "id": "economy_tooltip",
        "crop": (1144, 731, 1732, 963),
        "size": (640, 320),
        "file": "ui_frame_economy_tooltip.png",
    },
]


def checker_to_alpha(image: Image.Image) -> Image.Image:
    image = image.convert("RGBA")
    pixels = image.load()
    for y in range(image.height):
        for x in range(image.width):
            r, g, b, a = pixels[x, y]
            low_sat = max(r, g, b) - min(r, g, b) <= 10
            if low_sat and r > 185 and g > 185 and b > 185:
                pixels[x, y] = (0, 0, 0, 0)
            else:
                pixels[x, y] = (r, g, b, a)
    return image


def trim(image: Image.Image) -> Image.Image:
    alpha = image.getchannel("A")
    bbox = alpha.point(lambda px: 255 if px > 6 else 0).getbbox()
    if bbox is None:
        return image
    pad = 4
    box = (
        max(0, bbox[0] - pad),
        max(0, bbox[1] - pad),
        min(image.width, bbox[2] + pad),
        min(image.height, bbox[3] + pad),
    )
    return image.crop(box)


def fit(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    image = trim(image)
    target_w, target_h = size
    scale = min(target_w / image.width, target_h / image.height)
    new_size = (max(1, int(image.width * scale)), max(1, int(image.height * scale)))
    resized = image.resize(new_size, Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", size, (0, 0, 0, 0))
    canvas.alpha_composite(resized, ((target_w - new_size[0]) // 2, (target_h - new_size[1]) // 2))
    return canvas


def checker(size: tuple[int, int], block: int = 16) -> Image.Image:
    image = Image.new("RGBA", size, (34, 31, 33, 255))
    draw = ImageDraw.Draw(image)
    for y in range(0, size[1], block):
        for x in range(0, size[0], block):
            if (x // block + y // block) % 2 == 0:
                draw.rectangle((x, y, x + block - 1, y + block - 1), fill=(54, 49, 51, 255))
    return image


def make_contact(outputs: list[Path]) -> None:
    PREVIEW.parent.mkdir(parents=True, exist_ok=True)
    cell = (360, 250)
    label_h = 28
    cols = 3
    rows = 2
    sheet = Image.new("RGBA", (cols * cell[0], rows * (cell[1] + label_h) + 42), (18, 16, 18, 255))
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default()
    draw.text((12, 12), "SCRUM-332 economy frame kit (alpha-cleaned)", fill=(232, 220, 190, 255), font=font)
    for index, path in enumerate(outputs):
        x = (index % cols) * cell[0]
        y = 42 + (index // cols) * (cell[1] + label_h)
        bg = checker(cell)
        asset = Image.open(path).convert("RGBA")
        scale = min((cell[0] - 28) / asset.width, (cell[1] - 28) / asset.height)
        resized = asset.resize((int(asset.width * scale), int(asset.height * scale)), Image.Resampling.LANCZOS)
        bg.alpha_composite(resized, ((cell[0] - resized.width) // 2, (cell[1] - resized.height) // 2))
        sheet.alpha_composite(bg, (x, y))
        draw.text((x + 10, y + cell[1] + 6), path.name, fill=(230, 220, 196, 255), font=font)
    sheet.save(PREVIEW)


def main() -> None:
    source = Image.open(SOURCE).convert("RGBA")
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    REF_DIR.mkdir(parents=True, exist_ok=True)
    outputs: list[Path] = []
    for asset in ASSETS:
        crop = source.crop(asset["crop"])
        cleaned = checker_to_alpha(crop)
        final = fit(cleaned, asset["size"])
        for base in (OUT_DIR, REF_DIR):
            path = base / asset["file"]
            final.save(path)
        outputs.append(OUT_DIR / asset["file"])
    make_contact(outputs)
    print(f"wrote {len(outputs)} economy frame assets")
    print(f"preview: {PREVIEW.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
