#!/usr/bin/env python3
"""Build the SCRUM-323 Hero Select dossier frame.

The DescriptionHS reference pack contains strong dark-fantasy frame concepts,
but the live Hero Select center slot is closer to square than to the original
wide source. This builder crops the accepted DescriptionHS frame into a
near-square production asset so Godot can render the whole ornament with one
uniform scale factor and keep runtime content inside a documented safe area.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
REFERENCE = ROOT / "docs/design/references/DescriptionHS/ChatGPT Image Jun 14, 2026, 11_12_12 AM (1).png"
OUTPUT = ROOT / "assets/sprites/ui/frames/hero_select/ui_frame_hero_select_dossier.png"
PREVIEW = ROOT / "docs/design/previews/hero_select_dossier_frame_content_zone.png"
CANVAS_SIZE = (1120, 1140)
SAFE_MARGINS = (96, 66, 96, 54)  # left, top, right, bottom in 1120x1140 source space.


def foreground_mask(image: Image.Image) -> Image.Image:
    source = image.convert("RGB")
    mask = Image.new("L", source.size, 0)
    pixels = source.load()
    mask_pixels = mask.load()
    width, height = source.size
    for y in range(height):
        for x in range(width):
            red, green, blue = pixels[x, y]
            luma = (red * 299 + green * 587 + blue * 114) / 1000.0
            chroma = max(red, green, blue) - min(red, green, blue)
            # The baked reference background is bright/neutral checkerboard;
            # the usable frame and inner stone field are dark or saturated.
            if luma < 238.0 or (chroma > 18 and luma < 252.0):
                mask_pixels[x, y] = 255
    mask = mask.filter(ImageFilter.MaxFilter(5))
    mask = mask.filter(ImageFilter.MinFilter(3))
    mask = mask.filter(ImageFilter.GaussianBlur(0.9))
    return mask


def crop_to_dossier_slot(image: Image.Image, mask: Image.Image) -> tuple[Image.Image, Image.Image]:
    target_width, target_height = CANVAS_SIZE
    target_aspect = target_width / float(target_height)
    crop_height = image.height
    crop_width = int(round(crop_height * target_aspect))
    if crop_width > image.width:
        crop_width = image.width
        crop_height = int(round(crop_width / target_aspect))
    left = max(0, (image.width - crop_width) // 2)
    top = max(0, (image.height - crop_height) // 2)
    box = (left, top, left + crop_width, top + crop_height)
    return image.crop(box), mask.crop(box)


def defringe(rgba: Image.Image) -> Image.Image:
    rgba = rgba.convert("RGBA")
    pixels = rgba.load()
    width, height = rgba.size
    for y in range(height):
        for x in range(width):
            red, green, blue, alpha = pixels[x, y]
            if alpha < 4:
                pixels[x, y] = (0, 0, 0, 0)
                continue
            if alpha < 225:
                factor = 0.40 + 0.60 * (alpha / 255.0)
                pixels[x, y] = (int(red * factor), int(green * factor), int(blue * factor), alpha)
    return rgba


def build_asset() -> Image.Image:
    image = Image.open(REFERENCE).convert("RGBA")
    mask = foreground_mask(image)
    cropped, cropped_mask = crop_to_dossier_slot(image, mask)
    cropped = cropped.resize(CANVAS_SIZE, Image.Resampling.LANCZOS)
    cropped_mask = cropped_mask.resize(CANVAS_SIZE, Image.Resampling.LANCZOS)
    cropped.putalpha(cropped_mask)
    asset = defringe(cropped)

    # Strengthen the central stone field slightly so text remains readable over
    # the cropped reference at 720p without touching the visible metal border.
    plate = Image.new("RGBA", asset.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(plate)
    draw.rounded_rectangle(
        (92, 66, CANVAS_SIZE[0] - 92, CANVAS_SIZE[1] - 58),
        radius=42,
        fill=(8, 7, 7, 56),
        outline=(156, 92, 56, 46),
        width=2,
    )
    asset = Image.alpha_composite(asset, plate)
    return asset


def write_preview(asset: Image.Image) -> None:
    background = Image.new("RGBA", asset.size, (14, 11, 10, 255))
    preview = Image.alpha_composite(background, asset)
    draw = ImageDraw.Draw(preview)
    left, top, right, bottom = SAFE_MARGINS
    safe_rect = (left, top, CANVAS_SIZE[0] - right, CANVAS_SIZE[1] - bottom)
    draw.rectangle(safe_rect, outline=(70, 255, 130, 235), width=5)
    draw.text((left + 12, top + 10), "dossier content safe area", fill=(190, 255, 205, 230))
    # Reference runtime blocks: title/description area, ascension row and choose button.
    draw.rectangle((safe_rect[0] + 18, safe_rect[1] + 70, safe_rect[2] - 18, safe_rect[1] + 230), outline=(120, 190, 255, 150), width=2)
    draw.rectangle((safe_rect[0] + 18, safe_rect[3] - 250, safe_rect[2] - 18, safe_rect[3] - 148), outline=(255, 205, 95, 150), width=2)
    draw.rectangle((safe_rect[0] + 210, safe_rect[3] - 126, safe_rect[2] - 210, safe_rect[3] - 36), outline=(255, 120, 120, 150), width=2)
    PREVIEW.parent.mkdir(parents=True, exist_ok=True)
    preview.save(PREVIEW)


def main() -> None:
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    asset = build_asset()
    asset.save(OUTPUT)
    write_preview(asset)
    print(f"Wrote {OUTPUT.relative_to(ROOT)} ({asset.size[0]}x{asset.size[1]} RGBA)")
    print(f"Wrote {PREVIEW.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
