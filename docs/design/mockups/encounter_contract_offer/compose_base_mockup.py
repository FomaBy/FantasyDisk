from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[4]
OUT = Path(__file__).resolve().parent


def font(size: int):
    path = "/System/Library/Fonts/Supplemental/Arial Unicode.ttf"
    return ImageFont.truetype(path, size) if Path(path).exists() else ImageFont.load_default()


def cover(source: Image.Image, size: tuple[int, int]) -> Image.Image:
    scale = max(size[0] / source.width, size[1] / source.height)
    resized = source.resize((round(source.width * scale), round(source.height * scale)), Image.Resampling.LANCZOS)
    left = (resized.width - size[0]) // 2
    top = (resized.height - size[1]) // 2
    return resized.crop((left, top, left + size[0], top + size[1]))


def paste_scaled(canvas: Image.Image, path: Path, box: tuple[int, int, int, int]) -> None:
    x, y, w, h = box
    layer = Image.open(path).convert("RGBA").resize((w, h), Image.Resampling.LANCZOS)
    canvas.alpha_composite(layer, (x, y))


def main() -> None:
    canvas = cover(Image.open(ROOT / "assets/backgrounds/field_ruined_courtyard.png").convert("RGB"), (1920, 1080)).convert("RGBA")
    canvas.alpha_composite(Image.new("RGBA", canvas.size, (8, 7, 12, 116)))

    # Existing gameplay HUD assets keep the critical combat information visible above the dim layer.
    paste_scaled(canvas, ROOT / "assets/sprites/ui/frames/combat_hud/ui_frame_combat_hud_resource_panel.png", (14, 14, 768, 108))
    paste_scaled(canvas, ROOT / "assets/sprites/ui/frames/combat_hud/ui_frame_combat_hud_timer.png", (852, 10, 288, 96))
    paste_scaled(canvas, ROOT / "assets/sprites/ui/hud/combat_hud_v2/ui_hud_v2_cluster_bg.png", (1510, 12, 288, 96))
    paste_scaled(canvas, ROOT / "assets/sprites/ui/frames/combat_hud/ui_btn_combat_level_up_plus.png", (1827, 987, 93, 93))
    hud = ImageDraw.Draw(canvas)
    hud.text((48, 39), "HP 78/100    XP 42%    126 зол.", fill=(238, 218, 170, 235), font=font(18))
    hud.text((943, 40), "01:24", fill=(244, 231, 196, 240), font=font(22))
    hud.text((1536, 40), "АРТЕФАКТЫ", fill=(216, 196, 145, 220), font=font(14))

    source = Image.open(ROOT / "docs/design/references/encounter_contract_offer/pixellab_encounter_contract_offer_688x384_alpha_clean.png").convert("RGBA")
    modal = source.resize((1360, 760), Image.Resampling.LANCZOS)
    canvas.alpha_composite(modal, (280, 160))
    canvas.save(OUT / "encounter_contract_offer_base.png")


if __name__ == "__main__":
    main()
