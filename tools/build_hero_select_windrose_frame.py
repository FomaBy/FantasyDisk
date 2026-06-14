#!/usr/bin/env python3
"""Build the SCRUM-322 Hero Select windrose radar frame.

The approved reference has a baked light checkerboard background. This script
extracts the dark fantasy frame into an alpha-ready runtime PNG and writes a
safe-area preview for Design/QA.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
REFERENCE = ROOT / "docs/design/references/windrose/ChatGPT Image Jun 14, 2026, 11_07_47 AM.png"
OUTPUT = ROOT / "assets/sprites/ui/frames/hero_select/ui_frame_hero_select_radar.png"
PREVIEW = ROOT / "docs/design/previews/hero_select_windrose_radar_content_zone.png"
CANVAS_SIZE = 1024
SAFE_MARGINS = (245, 245, 245, 235)  # left, top, right, bottom in 1024px source space.


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
            # The baked checkerboard is very bright and nearly neutral; the
            # frame is dark metal/red gemstone. Keep saturated highlights.
            if luma < 238.0 or (chroma > 18 and luma < 252.0):
                mask_pixels[x, y] = 255
    mask = mask.filter(ImageFilter.MaxFilter(7))
    mask = mask.filter(ImageFilter.MinFilter(3))
    mask = mask.filter(ImageFilter.GaussianBlur(1.2))
    return mask


def crop_to_square(image: Image.Image, mask: Image.Image) -> tuple[Image.Image, Image.Image]:
    bbox = mask.point(lambda value: 255 if value > 20 else 0).getbbox()
    if bbox is None:
        raise RuntimeError("Could not find foreground in windrose reference")
    left, top, right, bottom = bbox
    pad = 28
    left = max(0, left - pad)
    top = max(0, top - pad)
    right = min(image.width, right + pad)
    bottom = min(image.height, bottom + pad)
    side = max(right - left, bottom - top)
    center_x = (left + right) // 2
    center_y = (top + bottom) // 2
    left = max(0, min(image.width - side, center_x - side // 2))
    top = max(0, min(image.height - side, center_y - side // 2))
    box = (left, top, left + side, top + side)
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
            if alpha < 220:
                factor = 0.42 + 0.58 * (alpha / 255.0)
                pixels[x, y] = (int(red * factor), int(green * factor), int(blue * factor), alpha)
    return rgba


def build_asset() -> Image.Image:
    image = Image.open(REFERENCE).convert("RGBA")
    mask = foreground_mask(image)
    cropped, cropped_mask = crop_to_square(image, mask)
    cropped = cropped.resize((CANVAS_SIZE, CANVAS_SIZE), Image.Resampling.LANCZOS)
    cropped_mask = cropped_mask.resize((CANVAS_SIZE, CANVAS_SIZE), Image.Resampling.LANCZOS)
    cropped.putalpha(cropped_mask)
    asset = defringe(cropped)

    # Reinforce the inner tabletop surface so runtime labels/graph have a stable
    # dark field while the outer windrose ornament remains untouched.
    center_plate = Image.new("RGBA", asset.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(center_plate)
    draw.ellipse((164, 172, 860, 852), fill=(10, 9, 8, 214), outline=(177, 127, 76, 92), width=3)
    draw.ellipse((255, 260, 769, 764), outline=(177, 127, 76, 46), width=2)
    draw.ellipse((350, 354, 674, 670), outline=(177, 127, 76, 34), width=1)
    draw.line((512, 204, 512, 820), fill=(169, 128, 82, 50), width=2)
    draw.line((204, 512, 820, 512), fill=(169, 128, 82, 50), width=2)
    draw.line((294, 300, 730, 724), fill=(169, 128, 82, 32), width=1)
    draw.line((730, 300, 294, 724), fill=(169, 128, 82, 32), width=1)
    asset = Image.alpha_composite(asset, center_plate)
    return asset


def write_preview(asset: Image.Image) -> None:
    background = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (12, 10, 9, 255))
    preview = Image.alpha_composite(background, asset)
    draw = ImageDraw.Draw(preview)
    left, top, right, bottom = SAFE_MARGINS
    safe_rect = (left, top, CANVAS_SIZE - right, CANVAS_SIZE - bottom)
    draw.rectangle(safe_rect, outline=(60, 255, 120, 235), width=5)
    draw.ellipse(safe_rect, outline=(60, 255, 120, 140), width=3)
    draw.text((left + 12, top + 10), "runtime content safe area", fill=(190, 255, 200, 230))
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
