#!/usr/bin/env python3
"""Compose the SCRUM-1050 reference board from accepted PixelLab sources only."""

from pathlib import Path
from typing import Optional, Tuple

from PIL import Image, ImageDraw, ImageEnhance, ImageOps


ROOT = Path(__file__).resolve().parents[4]
OUT_DIR = ROOT / "docs/design/references/scrum1050_ui_unification"
PREVIEW_DIR = ROOT / "docs/design/previews"


def load_rgba(path: str, crop: Optional[Tuple[int, int, int, int]] = None, remove_white: bool = False) -> Image.Image:
    image = Image.open(ROOT / path).convert("RGBA")
    if crop is not None:
        image = image.crop(crop)
    if remove_white:
        pixels = image.load()
        for y in range(image.height):
            for x in range(image.width):
                red, green, blue, alpha = pixels[x, y]
                if alpha and red >= 238 and green >= 238 and blue >= 238:
                    pixels[x, y] = (red, green, blue, 0)
    bbox = image.getbbox()
    return image.crop(bbox) if bbox else image


def contain(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    return ImageOps.contain(image, size, Image.Resampling.LANCZOS)


def paste_center(canvas: Image.Image, image: Image.Image, rect: tuple[int, int, int, int]) -> None:
    x, y, width, height = rect
    fitted = contain(image, (width, height))
    destination = (x + (width - fitted.width) // 2, y + (height - fitted.height) // 2)
    canvas.alpha_composite(fitted, destination)


def state_variant(source: Image.Image, state: str) -> Image.Image:
    if state == "normal":
        return source.copy()
    if state == "hover":
        return ImageEnhance.Contrast(ImageEnhance.Brightness(source).enhance(1.13)).enhance(1.06)
    if state == "pressed":
        return ImageEnhance.Contrast(ImageEnhance.Brightness(source).enhance(0.72)).enhance(1.08)
    if state == "focus":
        bright = ImageEnhance.Brightness(source).enhance(1.18)
        return ImageEnhance.Color(bright).enhance(0.92)
    if state == "disabled":
        alpha = source.getchannel("A")
        gray = ImageOps.grayscale(source).convert("RGBA")
        gray = ImageEnhance.Brightness(gray).enhance(0.62)
        gray.putalpha(alpha.point(lambda value: int(value * 0.68)))
        return gray
    raise ValueError(state)


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    canvas = Image.new("RGBA", (688, 384), (0, 0, 0, 0))

    button = load_rgba("docs/design/references/settings_v3_full_redraw/ui_frame_settings_v3_action_button.png")
    for state, rect in zip(
        ("normal", "hover", "pressed", "focus", "disabled"),
        ((24, 24, 120, 52), (154, 24, 120, 52), (284, 24, 120, 52), (414, 24, 120, 52), (544, 24, 120, 52)),
    ):
        paste_center(canvas, state_variant(button, state), rect)

    panels = [
        (
            load_rgba(
                "docs/design/references/scrum981_gold_menu_shell/pixellab_main_menu_gold_shell_reference_688x384.png",
                crop=(10, 15, 678, 370),
            ),
            (24, 96, 148, 118),
        ),
        (load_rgba("assets/sprites/ui/frames/hero_select_pixellab/frame_dossier.png"), (188, 96, 148, 118)),
        (load_rgba("docs/design/references/settings_v3_full_redraw/ui_frame_settings_v3_main_modal.png"), (352, 96, 148, 118)),
        (
            load_rgba("docs/design/references/codex_redesign_2026_06/pixellab_sources/scrum725_codex_detail_panel.png"),
            (516, 96, 148, 118),
        ),
        (load_rgba("docs/design/references/settings_v3_full_redraw/ui_frame_settings_v3_content_panel.png"), (24, 230, 148, 130)),
        (
            load_rgba(
                "docs/design/references/scrum990_991_artifact_reward/pixellab_artifact_reward_gold_hall_688x384.png",
                crop=(228, 55, 460, 145),
                remove_white=True,
            ),
            (188, 230, 148, 130),
        ),
        (
            load_rgba(
                "docs/design/references/scrum990_991_artifact_reward/pixellab_artifact_reward_gold_hall_688x384.png",
                crop=(282, 150, 410, 324),
                remove_white=True,
            ),
            (352, 230, 148, 130),
        ),
        (
            load_rgba(
                "docs/design/references/scrum983_escape_dossier/pixellab_escape_dossier_v1_688x384.png",
                crop=(425, 96, 610, 188),
            ),
            (516, 230, 148, 130),
        ),
    ]
    for panel, rect in panels:
        paste_center(canvas, panel, rect)

    output = OUT_DIR / "scrum1050_unified_ui_reference_sheet_688x384.png"
    canvas.save(output)
    canvas.save(PREVIEW_DIR / "scrum1050_ui_unification_reference_sheet_688x384.png")

    debug = canvas.copy()
    draw = ImageDraw.Draw(debug, "RGBA")
    safe_rects = [
        (40, 36, 128, 64), (170, 36, 258, 64), (300, 36, 388, 64),
        (430, 36, 518, 64), (560, 36, 648, 64),
        (104, 118, 154, 178), (214, 122, 310, 188), (375, 122, 477, 190), (563, 122, 617, 186),
        (38, 276, 158, 312), (210, 280, 314, 308), (393, 268, 459, 340), (536, 271, 644, 313),
    ]
    for rect in safe_rects:
        draw.rectangle(rect, fill=(0, 220, 190, 36), outline=(0, 255, 220, 230), width=2)
    debug.save(PREVIEW_DIR / "scrum1050_ui_unification_reference_sheet_688x384_debug.png")


if __name__ == "__main__":
    main()
