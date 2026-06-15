#!/usr/bin/env python3
"""Build SCRUM-355 thinner Hero Select dossier and carousel frames.

This is a deterministic local recomposition pass over the already accepted
Hero Select reference pipelines. It does not call image generation APIs. The
goal is to preserve the approved D&D dark-fantasy ornaments while reducing
visual weight and documenting strict empty content zones for runtime layout.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile

from PIL import Image, ImageDraw, ImageFilter, ImageFont

import build_hero_select_carousel_frame
import build_hero_select_dossier_frame


ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "assets/sprites/ui/frames/hero_select"
QA_DIR = ROOT / "build/qa/scrum355"
PREVIEW = ROOT / "docs/design/previews/hero_select_thin_frames_content_zones.png"

DOSSIER_OUT = OUT_DIR / "ui_frame_hero_select_dossier.png"
CAROUSEL_OUT = OUT_DIR / "ui_frame_hero_select_thumbnail_strip.png"
BACKUP_ZIP = QA_DIR / "hero_select_pre_scrum355_frame_assets.zip"


@dataclass(frozen=True)
class FrameSpec:
    frame_id: str
    size: tuple[int, int]
    plate_rect: tuple[int, int, int, int]
    safe_margins: tuple[int, int, int, int]
    border_opacity: float
    plate_radius: int
    plate_fill: tuple[int, int, int, int]
    outline: tuple[int, int, int, int]


DOSSIER_SPEC = FrameSpec(
    frame_id="dossier",
    size=(1120, 1140),
    plate_rect=(100, 132, 1020, 1010),
    safe_margins=(126, 160, 126, 172),
    border_opacity=0.90,
    plate_radius=48,
    plate_fill=(13, 12, 12, 226),
    outline=(126, 67, 52, 80),
)

CAROUSEL_SPEC = FrameSpec(
    frame_id="thumbnail_strip",
    size=(1536, 255),
    plate_rect=(118, 48, 1418, 207),
    safe_margins=(132, 62, 132, 62),
    border_opacity=0.88,
    plate_radius=44,
    plate_fill=(14, 13, 13, 224),
    outline=(122, 62, 50, 84),
)

RUNTIME_TARGETS = {
    "dossier": (
        ("1280x720", (387, 394)),
        ("1920x1080", (581, 591)),
        ("2560x1440", (774, 788)),
    ),
    "thumbnail_strip": (
        ("1280x720", (1024, 170)),
        ("1920x1080", (1536, 255)),
        ("2560x1440", (2048, 340)),
    ),
}


def _save_pre_backup() -> None:
    QA_DIR.mkdir(parents=True, exist_ok=True)
    if BACKUP_ZIP.exists():
        return
    with ZipFile(BACKUP_ZIP, "w", ZIP_DEFLATED) as archive:
        for path in (DOSSIER_OUT, CAROUSEL_OUT):
            if path.exists():
                archive.write(path, path.relative_to(ROOT))


def _alpha_scaled(image: Image.Image, factor: float) -> Image.Image:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A").point(lambda value: int(round(value * factor)))
    rgba.putalpha(alpha)
    return rgba


def _clear_center(ornament: Image.Image, spec: FrameSpec) -> Image.Image:
    alpha = ornament.getchannel("A")
    clear = Image.new("L", spec.size, 0)
    draw = ImageDraw.Draw(clear)
    draw.rounded_rectangle(spec.plate_rect, radius=spec.plate_radius, fill=255)
    clear = clear.filter(ImageFilter.GaussianBlur(2.2))
    alpha = Image.composite(Image.new("L", spec.size, 0), alpha, clear)
    ornament.putalpha(alpha)
    return ornament


def _build_plate(spec: FrameSpec) -> Image.Image:
    plate = Image.new("RGBA", spec.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(plate)
    draw.rounded_rectangle(
        spec.plate_rect,
        radius=spec.plate_radius,
        fill=spec.plate_fill,
        outline=spec.outline,
        width=3,
    )
    inner = (
        spec.plate_rect[0] + 18,
        spec.plate_rect[1] + 18,
        spec.plate_rect[2] - 18,
        spec.plate_rect[3] - 18,
    )
    draw.rounded_rectangle(inner, radius=max(spec.plate_radius - 18, 12), outline=(40, 31, 28, 74), width=2)
    return plate


def _thin_frame(base: Image.Image, spec: FrameSpec) -> Image.Image:
    if base.size != spec.size:
        base = base.resize(spec.size, Image.Resampling.LANCZOS)
    ornament = _alpha_scaled(base, spec.border_opacity)
    ornament = _clear_center(ornament, spec)
    plate = _build_plate(spec)
    return Image.alpha_composite(plate, ornament)


def _runtime_scaled_margins(spec: FrameSpec) -> list[str]:
    result: list[str] = []
    source_width, source_height = spec.size
    left, top, right, bottom = spec.safe_margins
    for label, target_size in RUNTIME_TARGETS[spec.frame_id]:
        scale = target_size[0] / float(source_width)
        result.append(
            "- `%s`: frame `%dx%d`, safe margins `Vector4(%d, %d, %d, %d)`, content rect `%dx%d`"
            % (
                label,
                target_size[0],
                target_size[1],
                round(left * scale),
                round(top * scale),
                round(right * scale),
                round(bottom * scale),
                round(target_size[0] - (left + right) * scale),
                round(target_size[1] - (top + bottom) * scale),
            )
        )
    return result


def _write_qa_summary() -> None:
    lines = [
        "# SCRUM-355 Hero Select Thin Frame QA",
        "",
        "Generated by `tools/build_hero_select_thin_frames.py` from accepted DescriptionHS and Carusel reference pipelines.",
        "",
        "## Runtime Assets",
        "- `assets/sprites/ui/frames/hero_select/ui_frame_hero_select_dossier.png`: `1120x1140`, RGBA, source `docs/design/references/DescriptionHS/` via `tools/build_hero_select_dossier_frame.py`.",
        "- `assets/sprites/ui/frames/hero_select/ui_frame_hero_select_thumbnail_strip.png`: `1536x255`, RGBA, source `docs/design/references/carusel/` via `tools/build_hero_select_carousel_frame.py`.",
        "",
        "## Strict Content Zones",
        "",
        "Dossier source margins: `Vector4(%d, %d, %d, %d)`; visible thin plate rect: `%s`." % (*DOSSIER_SPEC.safe_margins, DOSSIER_SPEC.plate_rect),
        *_runtime_scaled_margins(DOSSIER_SPEC),
        "",
        "Thumbnail strip source margins: `Vector4(%d, %d, %d, %d)`; visible thin plate rect: `%s`." % (*CAROUSEL_SPEC.safe_margins, CAROUSEL_SPEC.plate_rect),
        *_runtime_scaled_margins(CAROUSEL_SPEC),
        "",
        "## Back-end Handoff",
        "- `HeroSelectDossierContent` must use the dossier strict margins above; the old `Vector4(96, 66, 96, 54)` is not safe for the top crest/bottom ornament.",
        "- `HeroThumbnailStripContent` must use the thumbnail strip strict margins above; the old compact `Vector4(72, 36, 72, 36)` is visually too close to metal/side gems.",
        "- Keep both frame arts rendered as whole proportional `TextureRect`s. Do not 9-slice or stretch on one axis.",
        "- The description/carousel visual overlap still requires SCRUM-354 layout work: preserve at least a 16px runtime vertical gap between `HeroSelectDossierFrame` and `HeroThumbnailStripFrame`, then keep content inside these strict safe zones.",
    ]
    (QA_DIR / "hero_select_thin_frames_qa.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def _draw_safe_overlay(draw: ImageDraw.ImageDraw, spec: FrameSpec, offset: tuple[int, int], scale: float) -> None:
    ox, oy = offset
    left, top, right, bottom = spec.safe_margins
    rect = (
        ox + round(left * scale),
        oy + round(top * scale),
        ox + round((spec.size[0] - right) * scale),
        oy + round((spec.size[1] - bottom) * scale),
    )
    draw.rectangle(rect, outline=(75, 255, 139, 235), width=max(2, round(4 * scale)))


def _write_preview(dossier: Image.Image, carousel: Image.Image) -> None:
    PREVIEW.parent.mkdir(parents=True, exist_ok=True)
    width, height = 1760, 1220
    canvas = Image.new("RGBA", (width, height), (20, 16, 14, 255))
    draw = ImageDraw.Draw(canvas)
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 24)
    except OSError:
        font = ImageFont.load_default()

    draw.text((40, 28), "SCRUM-355 thinner Hero Select frames: green = strict empty content-zone", fill=(235, 221, 190, 255), font=font)

    dossier_scale = 0.62
    dossier_preview = dossier.resize((round(dossier.width * dossier_scale), round(dossier.height * dossier_scale)), Image.Resampling.LANCZOS)
    dossier_pos = (52, 92)
    canvas.alpha_composite(dossier_preview, dossier_pos)
    _draw_safe_overlay(draw, DOSSIER_SPEC, dossier_pos, dossier_scale)
    draw.text((dossier_pos[0], dossier_pos[1] + dossier_preview.height + 16), "dossier: content starts below crest and above bottom ornament", fill=(220, 210, 180, 255), font=font)

    carousel_scale = 0.95
    carousel_preview = carousel.resize((round(carousel.width * carousel_scale), round(carousel.height * carousel_scale)), Image.Resampling.LANCZOS)
    carousel_pos = (52, 940)
    canvas.alpha_composite(carousel_preview, carousel_pos)
    _draw_safe_overlay(draw, CAROUSEL_SPEC, carousel_pos, carousel_scale)
    draw.text((carousel_pos[0], carousel_pos[1] + carousel_preview.height + 16), "thumbnail strip: thumbnails/hover/select stay inside green zone", fill=(220, 210, 180, 255), font=font)

    PREVIEW.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(PREVIEW)


def main() -> None:
    _save_pre_backup()
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    dossier_base = build_hero_select_dossier_frame.build_asset()
    carousel_base = build_hero_select_carousel_frame._transparent_frame(build_hero_select_carousel_frame.SOURCE)

    dossier = _thin_frame(dossier_base, DOSSIER_SPEC)
    carousel = _thin_frame(carousel_base, CAROUSEL_SPEC)

    dossier.save(DOSSIER_OUT)
    carousel.save(CAROUSEL_OUT)
    _write_preview(dossier, carousel)
    _write_qa_summary()

    print(f"Wrote {DOSSIER_OUT.relative_to(ROOT)} {dossier.size[0]}x{dossier.size[1]}")
    print(f"Wrote {CAROUSEL_OUT.relative_to(ROOT)} {carousel.size[0]}x{carousel.size[1]}")
    print(f"Wrote {PREVIEW.relative_to(ROOT)}")
    print(f"Wrote {QA_DIR.relative_to(ROOT) / 'hero_select_thin_frames_qa.md'}")
    print(f"Backup {BACKUP_ZIP.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
