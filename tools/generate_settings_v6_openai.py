#!/usr/bin/env python3
"""Settings v6 UI kit (SCRUM-847) — OpenAI bases + PIL state derivatives.

Стиль — экран «Атлас Персонажа» (meta40): тёмное фэнтези, латунь/золото,
глубокий полуночно-синий акцент, 16-bit pixel art. Каждый элемент генерится
под целевой слот (аспект канваса → crop → LANCZOS в размер слота), состояния
hover/pressed/disabled/inactive — детерминированные PIL-деривативы от базы,
чтобы геометрия состояний совпадала пиксель-в-пиксель.

PixelLab-части (иконки табов, эмблема, розетка чекбокса, звезда, гем, стрелка)
кладутся заранее в docs/design/references/settings_v6/pixellab/ и собираются
шагом --derive (alpha-cleanup + композиция checkbox_on = розетка + звезда).

Usage:
  python3 tools/generate_settings_v6_openai.py --dry-run
  python3 tools/generate_settings_v6_openai.py [--only key1,key2] [--quality high]
  python3 tools/generate_settings_v6_openai.py --derive   # только деривативы/сборка
  python3 tools/generate_settings_v6_openai.py --sheet-only
"""

from __future__ import annotations

import argparse
import base64
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageEnhance

sys.path.insert(0, str(Path(__file__).resolve().parent))
from generate_meta40_ui_openai import (  # noqa: E402
    MODEL, _key_mask, clean_alpha, crop_to_aspect, erode_alpha, require_client)

ROOT = Path(__file__).resolve().parents[1]
ASSET_DIR = ROOT / "assets/sprites/ui/frames/settings_v6"
REF_DIR = ROOT / "docs/design/references/settings_v6"
PIXELLAB_DIR = REF_DIR / "pixellab"
PREVIEW_DIR = ROOT / "docs/design/previews"

STYLE = ("dark fantasy roguelite RPG user interface chrome, 16-bit pixel art, "
         "antique gold and dark bronze metalwork, dark tooled leather, deep "
         "midnight-blue accents, matches an ornate hero-atlas screen, crisp "
         "readable silhouette, no text, no letters, no watermark")

WIDE = ("; the element is ONE wide horizontal bar spanning the FULL image "
        "width edge to edge, vertically centered, uniform along its length")

# key -> (filename, gen_canvas, target_size, prompt)
SPEC: dict[str, tuple[str, str, tuple[int, int], str]] = {
    "modal_frame": (
        "ui_settings_v6_modal_frame.png", "1536x1024", (1420, 1060),
        f"{STYLE}; grand ornate settings modal panel filling the ENTIRE image "
        "edge to edge: border band of embossed antique gold filigree over "
        "dark bronze with corner rosettes and a small arched pediment crest "
        "at the top center, interior is a very dark quiet leather-and-stone "
        "field (near-black warm brown, subtle vignette, faint arcane "
        "constellation etchings) kept EMPTY and uncluttered so UI content "
        "stays readable on top; nothing outside the panel"),
    "content_inset": (
        "ui_settings_v6_content_inset.png", "1536x1024", (512, 256),
        f"{STYLE}; ONE wide recessed rectangular inset well panel filling "
        "the ENTIRE image edge to edge (all four edges of the panel rim "
        "visible), thin dark bronze beveled rim with tiny corner studs, "
        "interior an even darker flat recessed field (near-black, faint "
        "inner shadow at the top), center kept EMPTY and uniform for "
        "settings rows; nothing outside the panel"),
    "tab_active": (
        "ui_settings_v6_tab_active.png", "1536x1024", (340, 84),
        f"{STYLE}; lit bookmark tab plate: warm amber-gold glowing plaque "
        "with an embossed brass border and small flame-gem chips at the "
        "left and right ends, radiant and clearly SELECTED{WIDE}"),
    "btn_primary_normal": (
        "ui_settings_v6_btn_primary_normal.png", "1536x1024", (320, 80),
        f"{STYLE}; hero action button plate: polished antique gold surface "
        "with dragon-scale engraving, bold ornate brass border, warm inner "
        "glow, clearly the PRIMARY confirm button{WIDE}"),
    "btn_neutral_normal": (
        "ui_settings_v6_btn_neutral_normal.png", "1536x1024", (320, 80),
        f"{STYLE}; secondary action button plate: dark bronze and tooled "
        "leather surface, slim brass border with corner rivets, calm and "
        "muted; the middle of the plate is a PLAIN EMPTY flat leather field "
        "reserved for a text label — NO central medallion, NO emblem, NO "
        "circle, NO ornament in the center{WIDE}"),
    "field_normal": (
        "ui_settings_v6_field_normal.png", "1536x1024", (560, 56),
        f"{STYLE}; recessed value socket bar for a dropdown field: very dark "
        "sunken channel with a thin brass rim and small ornamental end "
        "caps, quiet flat center for text{WIDE}"),
    "slider_track": (
        "ui_settings_v6_slider_track.png", "1536x1024", (420, 18),
        f"{STYLE}; very thin empty slider groove rail: dark recessed channel "
        "with a fine brass edge line and tiny rounded end caps{WIDE}"),
    "value_chip": (
        "ui_settings_v6_value_chip.png", "1024x1024", (96, 48),
        f"{STYLE}; small value plaque chip filling the ENTIRE image: dark "
        "recessed center with a neat brass border and tiny corner studs, "
        "made to hold a short number"),
}

# PixelLab-сырцы: имя файла в PIXELLAB_DIR -> (final filename, target_size)
PIXELLAB_PASS: dict[str, tuple[str, tuple[int, int]]] = {
    "medallion.png": ("ui_settings_v6_medallion.png", (180, 72)),
    "icon_screen.png": ("ui_settings_v6_icon_screen.png", (44, 44)),
    "icon_sound.png": ("ui_settings_v6_icon_sound.png", (44, 44)),
    "icon_controls.png": ("ui_settings_v6_icon_controls.png", (44, 44)),
    "slider_gem.png": ("ui_settings_v6_slider_gem.png", (36, 36)),
    "arrow_socket.png": ("ui_settings_v6_arrow_socket.png", (36, 36)),
}


def _adjust(img: Image.Image, brightness: float = 1.0, saturation: float = 1.0,
            contrast: float = 1.0) -> Image.Image:
    """Тональный дериватив с сохранением альфы (геометрия неизменна)."""
    rgba = img.convert("RGBA")
    alpha = rgba.getchannel("A")
    rgb = rgba.convert("RGB")
    if saturation != 1.0:
        rgb = ImageEnhance.Color(rgb).enhance(saturation)
    if brightness != 1.0:
        rgb = ImageEnhance.Brightness(rgb).enhance(brightness)
    if contrast != 1.0:
        rgb = ImageEnhance.Contrast(rgb).enhance(contrast)
    out = rgb.convert("RGBA")
    out.putalpha(alpha)
    return out


def _load_asset(name: str) -> Image.Image:
    return Image.open(ASSET_DIR / name).convert("RGBA")


def _save(img: Image.Image, name: str) -> None:
    img.save(ASSET_DIR / name)
    print(f"  wrote {name} {img.size[0]}x{img.size[1]}", flush=True)


def _clean_pixellab(img: Image.Image) -> Image.Image:
    """PixelLab иногда запекает checkerboard/серый фон — border flood-fill
    по фактическому угловому цвету, затем 1px erode (см. memory alpha-fix)."""
    rgba = img.convert("RGBA")
    a = np.array(rgba, dtype=np.uint8)
    if (a[:, :, 3] < 8).mean() > 0.05:  # фон уже прозрачный
        return rgba
    corner = tuple(int(v) for v in a[0, 0, :3])
    cleaned = clean_alpha(rgba, thr=40, key=corner)
    arr = np.array(cleaned, dtype=np.uint8)
    if (arr[:, :, 3] == 0).mean() < 0.02:  # ключ не сработал — оставляем как есть
        return rgba
    return erode_alpha(cleaned)


def _fit(img: Image.Image, target: tuple[int, int]) -> Image.Image:
    if img.size == target:
        return img
    img = crop_to_aspect(img, *target)
    return img.resize(target, Image.LANCZOS)


def derive_states() -> None:
    """Собрать все производные состояния и PixelLab-финалы."""
    ASSET_DIR.mkdir(parents=True, exist_ok=True)
    print("derive: tabs", flush=True)
    tab = _load_asset("ui_settings_v6_tab_active.png")
    _save(_adjust(tab, brightness=0.66, saturation=0.42), "ui_settings_v6_tab_inactive.png")
    # hover заметно тусклее active: фокус-стиль невыбранных табов носит hover-арт,
    # и слишком золотой hover читался как вторая активная вкладка.
    _save(_adjust(tab, brightness=0.76, saturation=0.52), "ui_settings_v6_tab_hover.png")

    print("derive: buttons", flush=True)
    for kind in ("primary", "neutral"):
        base = _load_asset(f"ui_settings_v6_btn_{kind}_normal.png")
        _save(_adjust(base, brightness=1.12, saturation=1.08), f"ui_settings_v6_btn_{kind}_hover.png")
        _save(_adjust(base, brightness=0.80, contrast=1.04), f"ui_settings_v6_btn_{kind}_pressed.png")
        # primary — очень яркое золото: тусклый desat оставляет его светлее
        # neutral-normal, поэтому глушим сильнее (честный greyed-out).
        if kind == "primary":
            _save(_adjust(base, brightness=0.48, saturation=0.28), f"ui_settings_v6_btn_{kind}_disabled.png")
        else:
            _save(_adjust(base, brightness=0.72, saturation=0.30), f"ui_settings_v6_btn_{kind}_disabled.png")

    print("derive: fields", flush=True)
    field = _load_asset("ui_settings_v6_field_normal.png")
    _save(_adjust(field, brightness=1.16, saturation=1.06), "ui_settings_v6_field_hover.png")
    _save(_adjust(field, brightness=0.82), "ui_settings_v6_field_pressed.png")

    print("derive: slider fill", flush=True)
    fill = Image.new("RGBA", (416, 12), (0, 0, 0, 0))
    dr = ImageDraw.Draw(fill)
    # Золотая капсула-заливка в палитре Атласа (#F0CC75 → #C7A870 по вертикали).
    top, bottom = (240, 204, 117), (156, 122, 62)
    for y in range(12):
        t = y / 11.0
        col = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        dr.line([(0, y), (415, y)], fill=col + (255,))
    mask = Image.new("L", (416, 12), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, 415, 11], radius=6, fill=255)
    fill.putalpha(mask)
    dr = ImageDraw.Draw(fill)
    dr.rounded_rectangle([0, 0, 415, 11], radius=6, outline=(94, 68, 24, 255), width=1)
    dr.line([(6, 2), (409, 2)], fill=(255, 238, 180, 190))
    _save(fill, "ui_settings_v6_slider_fill.png")

    print("derive: pixellab passthrough", flush=True)
    missing = []
    for src_name, (final_name, target) in PIXELLAB_PASS.items():
        src = PIXELLAB_DIR / src_name
        if not src.exists():
            missing.append(src_name)
            continue
        img = _clean_pixellab(Image.open(src))
        _save(_fit(img, target), final_name)

    print("derive: checkbox composite", flush=True)
    rosette_src = PIXELLAB_DIR / "checkbox_rosette.png"
    star_src = PIXELLAB_DIR / "star.png"
    if rosette_src.exists():
        rosette = _fit(_clean_pixellab(Image.open(rosette_src)), (52, 52))
        _save(_adjust(rosette, brightness=0.92, saturation=0.85), "ui_settings_v6_checkbox_off.png")
        if star_src.exists():
            on = rosette.copy()
            star = _fit(_clean_pixellab(Image.open(star_src)), (34, 34))
            on.alpha_composite(star, ((52 - 34) // 2, (52 - 34) // 2))
            _save(_adjust(on, brightness=1.06, saturation=1.05), "ui_settings_v6_checkbox_on.png")
        else:
            missing.append("star.png")
    else:
        missing.append("checkbox_rosette.png")
    if missing:
        print(f"derive: MISSING pixellab sources: {missing}", flush=True)


def generate(client, key: str, quality: str) -> Path:
    fname, canvas, target, prompt = SPEC[key]
    prompt = (prompt + "; entire background is one solid uniform bright "
              "magenta color #FF00FF, flat with no gradient, nothing else "
              "touches the background")
    result = client.images.generate(model=MODEL, prompt=prompt, size=canvas,
                                    quality=quality, output_format="png", n=1)
    raw = base64.b64decode(result.data[0].b64_json)
    (REF_DIR / "openai").mkdir(parents=True, exist_ok=True)
    raw_path = REF_DIR / "openai" / f"raw_{key}.png"
    raw_path.write_bytes(raw)
    img = Image.open(raw_path).convert("RGBA")
    img = clean_alpha(img)
    img = erode_alpha(img)
    img = _fit(img, target)
    out = ASSET_DIR / fname
    img.save(out)
    return out


def contact_sheet() -> Path:
    from PIL import ImageFont
    paths = sorted(ASSET_DIR.glob("ui_settings_v6_*.png"))
    cols = 6
    cell = 260
    rows = (len(paths) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * cell, rows * cell + 20), (16, 14, 20, 255))
    dr = ImageDraw.Draw(sheet)
    font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 12)
    for i, p in enumerate(paths):
        img = Image.open(p).convert("RGBA")
        img.thumbnail((cell - 20, cell - 40), Image.LANCZOS)
        x = (i % cols) * cell
        y = (i // cols) * cell
        sheet.alpha_composite(img, (x + (cell - img.width) // 2,
                                    y + 8 + (cell - 40 - img.height) // 2))
        name = p.stem.replace("ui_settings_v6_", "")
        dr.text((x + cell // 2, y + cell - 14), name, font=font,
                fill=(220, 205, 160, 255), anchor="mm")
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    out = PREVIEW_DIR / "settings_v6_contact.png"
    sheet.save(out)
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", help="comma-separated SPEC keys")
    ap.add_argument("--quality", default="medium", choices=["low", "medium", "high"])
    ap.add_argument("--derive", action="store_true", help="только деривативы/сборка")
    ap.add_argument("--sheet-only", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    if args.sheet_only:
        print(f"contact sheet: {contact_sheet().relative_to(ROOT)}")
        return
    if args.derive:
        derive_states()
        print(f"contact sheet: {contact_sheet().relative_to(ROOT)}")
        return
    keys = list(SPEC) if not args.only else [k.strip() for k in args.only.split(",")]
    unknown = [k for k in keys if k not in SPEC]
    if unknown:
        raise SystemExit(f"unknown keys: {unknown}")
    if args.dry_run:
        for k in keys:
            fname, canvas, target, _ = SPEC[k]
            print(f"{k:20s} {canvas:9s} -> {target} ({fname})")
        return
    ASSET_DIR.mkdir(parents=True, exist_ok=True)
    client = require_client()
    for i, k in enumerate(keys, 1):
        q = "high" if k == "modal_frame" else args.quality
        try:
            out = generate(client, k, q)
        except Exception as exc:  # noqa: BLE001 — биллинг/квота важны, падаем громко
            print(f"[{i}/{len(keys)}] {k}: FAILED — {exc}", flush=True)
            sys.exit(2)
        print(f"[{i}/{len(keys)}] {k}: {out.relative_to(ROOT)}", flush=True)


if __name__ == "__main__":
    main()
