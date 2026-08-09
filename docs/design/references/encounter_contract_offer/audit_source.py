import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / "pixellab_encounter_contract_offer_688x384_alpha_clean.png"
RAW = ROOT / "pixellab_encounter_contract_offer_688x384_raw.png"


def audit(path: Path) -> dict:
    image = Image.open(path).convert("RGBA")
    alpha = [px[3] for px in image.getdata()]
    visible = [(x, y) for y in range(image.height) for x in range(image.width) if image.getpixel((x, y))[3] > 0]
    white_opaque = sum(
        1
        for r, g, b, a in image.getdata()
        if a == 255 and r > 245 and g > 245 and b > 245
    )
    return {
        "filename": path.name,
        "size": [image.width, image.height],
        "mode": "RGBA",
        "alpha": {
            "transparent_pixels": alpha.count(0),
            "opaque_pixels": alpha.count(255),
            "visible_bbox_xyxy": [min(x for x, _ in visible), min(y for _, y in visible), max(x for x, _ in visible), max(y for _, y in visible)],
            "white_opaque_pixels": white_opaque,
        },
    }


def main() -> None:
    report = {
        "source": audit(SOURCE),
        "raw_provenance": audit(RAW),
        "accepted_content_rects_source_px": {
            "title_inner": [190, 8, 308, 36],
            "central_empty": [232, 83, 224, 157],
            "lower_center_panel": [217, 272, 253, 48],
            "left_icon_well": [118, 82, 54, 54],
            "right_icon_well": [496, 82, 54, 54],
            "left_button_inner": [214, 347, 98, 19],
            "right_button_inner": [372, 347, 98, 19],
        },
        "postprocess": "Removed only the two PixelLab auto-labels from the declared button interiors; frame and alpha pixels outside those rectangles were preserved.",
        "no_text_baked": True,
        "new_background": False,
    }
    (ROOT / "alpha_audit.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
