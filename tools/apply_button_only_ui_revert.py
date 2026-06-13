#!/usr/bin/env python3
"""Apply the SCRUM-147 user correction: wax-seal buttons only, legacy panels.

The full parchment frame rebuild looked sliced/odd in real UI. This pass keeps
the successful Parchment & Wax Seal buttons, makes them taller so the seal has
breathing room, and restores every non-button UI frame to the pre-SCRUM-147
legacy interface look.
"""

from __future__ import annotations

import io
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

from build_parchment_wax_ui_kit import (
    BUTTON_REF,
    DARK_DIR,
    ESCAPE_DIR,
    GLOBAL_DIR,
    PREVIEW_DIR,
    SHOP_DIR,
    SliceMargins,
    build_button_states,
    fit_on_canvas,
    load_rgba,
    nine_slice,
    render_button,
    save,
    validate_pngs,
)


ROOT = Path(__file__).resolve().parents[1]
LEGACY_REF = "b465bcd4^"


LIVE_NON_BUTTON_RESTORE = [
    "assets/sprites/ui/frames/global/ui_panel_frame.png",
    "assets/sprites/ui/frames/global/ui_card_frame.png",
    "assets/sprites/ui/frames/global/ui_hud_card_frame.png",
    "assets/sprites/ui/frames/global/ui_hud_panel_frame.png",
    "assets/sprites/ui/frames/global/ui_level_panel_frame.png",
    "assets/sprites/ui/frames/global/ui_tooltip_frame.png",
    "assets/sprites/ui/frames/escape/escape_stats_visual_kit_preview.png",
    "assets/sprites/ui/frames/escape/ui_escape_panel_frame.png",
    "assets/sprites/ui/frames/escape/ui_stat_basic_row_frame.png",
    "assets/sprites/ui/frames/escape/ui_stat_chip_frame.png",
    "assets/sprites/ui/frames/escape/ui_stat_group_frame.png",
    "assets/sprites/ui/frames/escape/ui_stat_section_divider.png",
    "assets/sprites/ui/frames/escape/ui_stat_tooltip_frame.png",
    "assets/sprites/ui/frames/escape/ui_stat_value_state_swatches.png",
    "assets/sprites/ui/shop/ui_shop_artifact_slot_frame.png",
    "assets/sprites/ui/shop/ui_shop_artifact_slot_hover.png",
    "assets/sprites/ui/shop/ui_shop_price_badge.png",
    "assets/sprites/ui/shop/ui_shop_purchased_overlay.png",
    "assets/sprites/ui/shop/ui_shop_tooltip_frame.png",
]


def legacy_image(path: str) -> Image.Image:
    data = subprocess.check_output(["git", "show", f"{LEGACY_REF}:{path}"])
    return Image.open(io.BytesIO(data)).convert("RGBA")


def restore_live_legacy_frames() -> list[Path]:
    restored: list[Path] = []
    for rel_path in LIVE_NON_BUTTON_RESTORE:
        path = ROOT / rel_path
        save(path, legacy_image(rel_path))
        restored.append(path)
    return restored


def scaled_legacy_frame(src: Image.Image, size: tuple[int, int], margin: int) -> Image.Image:
    return nine_slice(
        src,
        size,
        SliceMargins(margin, margin, margin, margin),
        SliceMargins(
            min(margin, max(6, size[0] // 4)),
            min(margin, max(6, size[1] // 4)),
            min(margin, max(6, size[0] // 4)),
            min(margin, max(6, size[1] // 4)),
        ),
    )


def restore_dark_fantasy_non_button_frames() -> list[Path]:
    sources = {
        "panel": legacy_image("assets/sprites/ui/frames/global/ui_panel_frame.png"),
        "card": legacy_image("assets/sprites/ui/frames/global/ui_card_frame.png"),
        "level": legacy_image("assets/sprites/ui/frames/global/ui_level_panel_frame.png"),
        "hud_panel": legacy_image("assets/sprites/ui/frames/global/ui_hud_panel_frame.png"),
        "hud_card": legacy_image("assets/sprites/ui/frames/global/ui_hud_card_frame.png"),
        "tooltip": legacy_image("assets/sprites/ui/frames/global/ui_tooltip_frame.png"),
        "row": legacy_image("assets/sprites/ui/frames/escape/ui_stat_basic_row_frame.png"),
        "chip": legacy_image("assets/sprites/ui/frames/escape/ui_stat_chip_frame.png"),
        "group": legacy_image("assets/sprites/ui/frames/escape/ui_stat_group_frame.png"),
        "divider": legacy_image("assets/sprites/ui/frames/escape/ui_stat_section_divider.png"),
        "swatches": legacy_image("assets/sprites/ui/frames/escape/ui_stat_value_state_swatches.png"),
        "shop": legacy_image("assets/sprites/ui/shop/ui_shop_tooltip_frame.png"),
    }
    outputs = {
        DARK_DIR / "ui_df_panel_frame.png": scaled_legacy_frame(sources["panel"], (768, 512), 32),
        DARK_DIR / "ui_df_card_frame.png": scaled_legacy_frame(sources["card"], (384, 256), 32),
        DARK_DIR / "ui_df_level_panel_frame.png": scaled_legacy_frame(sources["level"], (640, 384), 38),
        DARK_DIR / "ui_df_hud_panel_frame.png": scaled_legacy_frame(sources["hud_panel"], (512, 128), 26),
        DARK_DIR / "ui_df_hud_card_frame.png": scaled_legacy_frame(sources["hud_card"], (256, 96), 22),
        DARK_DIR / "ui_df_tooltip_frame.png": scaled_legacy_frame(sources["tooltip"], (512, 256), 28),
        DARK_DIR / "ui_df_stat_row_frame.png": scaled_legacy_frame(sources["row"], (512, 80), 18),
        DARK_DIR / "ui_df_stat_chip_frame.png": scaled_legacy_frame(sources["chip"], (384, 80), 18),
        DARK_DIR / "ui_df_shop_frame.png": scaled_legacy_frame(sources["shop"], (640, 320), 34),
        DARK_DIR / "ui_df_section_divider.png": sources["divider"].resize((640, 24), Image.Resampling.LANCZOS),
        DARK_DIR / "ui_df_stat_value_state_swatches.png": scaled_legacy_frame(sources["swatches"], (640, 144), 24),
    }
    for path, image in outputs.items():
        save(path, image)
    return list(outputs.keys())


def build_taller_buttons() -> list[Path]:
    button_ref = Image.open(BUTTON_REF).convert("RGBA")
    states = build_button_states(button_ref)
    generated: list[Path] = []
    for role in ("primary", "secondary", "danger"):
        for state in ("idle", "hover", "pressed", "disabled"):
            path = DARK_DIR / f"ui_df_button_{role}_{state}.png"
            save(path, render_button(states, state, (384, 120)))
            generated.append(path)
    save(GLOBAL_DIR / "ui_button_frame.png", render_button(states, "idle", (160, 88)))
    save(ESCAPE_DIR / "ui_escape_button_frame.png", render_button(states, "idle", (384, 144)))
    generated.extend([
        GLOBAL_DIR / "ui_button_frame.png",
        ESCAPE_DIR / "ui_escape_button_frame.png",
    ])
    return generated


def make_preview(paths: list[Path]) -> Path:
    font = ImageFont.load_default()
    button_ref = Image.open(BUTTON_REF).convert("RGBA")
    ref = button_ref.crop((188, 150, 1162, 1198)).resize((390, 420), Image.Resampling.LANCZOS)
    entries = [
        DARK_DIR / "ui_df_button_primary_idle.png",
        DARK_DIR / "ui_df_button_primary_hover.png",
        DARK_DIR / "ui_df_button_primary_pressed.png",
        DARK_DIR / "ui_df_button_primary_disabled.png",
        DARK_DIR / "ui_df_panel_frame.png",
        DARK_DIR / "ui_df_card_frame.png",
        DARK_DIR / "ui_df_hud_panel_frame.png",
        DARK_DIR / "ui_df_tooltip_frame.png",
        GLOBAL_DIR / "ui_button_frame.png",
        GLOBAL_DIR / "ui_panel_frame.png",
        ESCAPE_DIR / "ui_escape_button_frame.png",
        ESCAPE_DIR / "ui_escape_panel_frame.png",
        SHOP_DIR / "ui_shop_artifact_slot_frame.png",
        SHOP_DIR / "ui_shop_tooltip_frame.png",
    ]
    width = 1100
    sheet = Image.new("RGBA", (width, 980), (18, 13, 10, 255))
    draw = ImageDraw.Draw(sheet)
    draw.text((16, 12), "SCRUM-147 correction: keep taller wax-seal buttons, restore legacy panels", fill=(240, 215, 164), font=font)
    sheet.alpha_composite(ref, (16, 42))
    draw.text((430, 58), "Reference kept for buttons only. Non-button frames are restored to the old interface style.", fill=(225, 196, 143), font=font)
    x, y = 430, 90
    for path in entries:
        im = load_rgba(path)
        canvas = Image.new("RGBA", (210, 140), (22, 18, 15, 255))
        for yy in range(canvas.height):
            for xx in range(canvas.width):
                c = 31 if ((xx // 12 + yy // 12) % 2) else 19
                canvas.putpixel((xx, yy), (c, c, c, 255))
        thumb = fit_on_canvas(im, (196, 104), 0.96)
        canvas.alpha_composite(thumb, (7, 24))
        ImageDraw.Draw(canvas).text((6, 5), path.name[:32], fill=(236, 207, 149), font=font)
        sheet.alpha_composite(canvas, (x, y))
        x += 220
        if x + 210 > width:
            x = 16
            y += 154
    out = PREVIEW_DIR / "ui_button_only_legacy_panels_contact.png"
    save(out, sheet)
    return out


def main() -> None:
    generated = []
    generated.extend(restore_live_legacy_frames())
    generated.extend(restore_dark_fantasy_non_button_frames())
    generated.extend(build_taller_buttons())
    preview = make_preview(generated)
    generated.append(preview)
    validate_pngs(generated)
    print(f"Applied button-only UI correction to {len(generated)} PNGs")
    for path in generated:
        print(path.relative_to(ROOT))


if __name__ == "__main__":
    main()
