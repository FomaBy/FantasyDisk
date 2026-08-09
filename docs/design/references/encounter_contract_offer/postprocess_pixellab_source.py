from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parent
RAW = ROOT / "pixellab_encounter_contract_offer_688x384_raw.png"
OUT = ROOT / "pixellab_encounter_contract_offer_688x384_alpha_clean.png"


def clean_button_label(image: Image.Image, box: tuple[int, int, int, int]) -> None:
    # PixelLab's UI scaffold auto-rendered labels despite the no-text prompt.
    # Replace only the inner label well with its sampled flat surface; frame art
    # and transparent alpha remain untouched.
    x, y, w, h = box
    fill = image.getpixel((x - 3, y + h // 2))
    ImageDraw.Draw(image).rectangle((x, y, x + w - 1, y + h - 1), fill=fill)


def main() -> None:
    image = Image.open(RAW).convert("RGBA")
    clean_button_label(image, (220, 347, 90, 19))
    clean_button_label(image, (379, 347, 90, 19))
    image.save(OUT)


if __name__ == "__main__":
    main()
