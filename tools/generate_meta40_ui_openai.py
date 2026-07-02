#!/usr/bin/env python3
"""Meta 4.0 «Atlas of Heroes» UI kit — OpenAI image generation (gpt-image-2).

Product mandate (2026-07-02): every UI element is generated FOR its target
slot size/aspect in the 2560x1440 project window — assets are designed to the
slot, not squeezed into whatever came out. Pipeline per element:
  generate at native model canvas (aspect matching the slot) on a solid
  magenta key background -> border-connected flood-fill alpha cleanup ->
  1px alpha erode (halo) -> exact LANCZOS resize to the target slot size.

Replaces the PixelLab kit in assets/sprites/ui/meta40/ (SCRUM-826 follow-up).
Usage:
  python3 tools/generate_meta40_ui_openai.py [--only key1,key2] [--dry-run]
"""

from __future__ import annotations

import argparse
import base64
import os
import sys
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image

MODEL = "gpt-image-2"
ROOT = Path(__file__).resolve().parents[1]
ASSET_DIR = ROOT / "assets/sprites/ui/meta40"
PREVIEW_DIR = ROOT / "docs/design/previews"

STYLE = ("dark fantasy roguelite RPG user interface element, 16-bit pixel art, "
         "antique gold and dark bronze metalwork, dark leather, midnight-blue "
         "accents, crisp thick silhouette, ISOLATED sprite with nothing behind "
         "it — no frame, no panel, no plate, no backdrop, no text, no "
         "letters, no watermark, single centered element")

CREST_STYLE = ("class crest for a dark fantasy roguelite: round bronze-gold "
               "medallion plate with ornate rim, deep midnight-blue enamel "
               "center, centered emblem, 16-bit pixel art, thick readable "
               "shapes designed to stay clear at 160 pixels, the round "
               "medallion is the ONLY object — nothing behind it, no square "
               "frame, no text")

CRESTS = {
    "berserk": "crossed crimson battle axes",
    "soldier": "military chevron over crossed rifles",
    "thief": "curved dagger crossing a gold coin",
    "elementalist": "triad of fire, ice and lightning shards in a ring",
    "sniper": "circular rifle scope crosshair reticle",
    "priest": "radiant holy seal with small wings",
    "biologist": "green DNA double helix strand",
    "robot": "glowing power core reactor ring",
    "engineer": "brass gear with a small wrench",
    "dark_mage": "violet crescent moon with a curse sigil",
    "guitarist": "guitar headstock as a battle standard",
    "assassin": "crescent blade behind a shadow mask",
    "ranger": "drawn longbow with a nocked arrow",
    "doctor": "bold golden medical cross with a small glass potion vial at "
              "its center, on the deep blue enamel",
    "chemist": "bubbling alchemical flask with acid drops",
    "knight": "heater shield with a gold cross brace",
    "druid": "oak branch entwined with a wolf claw",
}

# key -> (filename, gen_canvas, target_size, transparent_bg, prompt)
SPEC: dict[str, tuple[str, str, tuple[int, int] | None, bool, str]] = {
    "bg_sky": (
        "bg_sky.png", "1536x1024", (2560, 1440), False,
        "full-screen background for a hero meta-progression star atlas: deep "
        "midnight-blue night sky, faint teal nebula wisps, tiny scattered "
        "distant stars, subtle vignette toward edges, 16-bit pixel art, "
        "quiet and dark so bright gold star nodes stay readable on top, "
        "16:9 composition, no frame, no border, no text"),
    "frame_border": (
        "frame_border.png", "1536x1024", None, True,
        "ornate rectangular BORDER frame only, for a 16:9 game screen: dark "
        "tooled leather band with embossed antique gold trim and corner "
        "rosettes, uniform border thickness suitable for 9-slice scaling, "
        "COMPLETELY EMPTY center filled with solid uniform bright magenta "
        "color #FF00FF (a hollow window), 16-bit pixel art, no text"),
    "socket_minor": (
        "socket_minor.png", "1024x1024", (96, 96), True,
        f"{STYLE}; small empty brass socket for a skill node: perfectly "
        "CIRCULAR coin-shaped ring, round silhouette, subtle rivets, faint "
        "inner recess, designed to read at 96 pixels"),
    "socket_notable": (
        "socket_notable.png", "1024x1024", (128, 128), True,
        f"{STYLE}; octagonal ornate gold socket for an important skill node, "
        "filigree rim with four tiny ruby chips, empty recessed center, "
        "designed to read at 128 pixels"),
    "socket_keystone": (
        "socket_keystone.png", "1024x1024", (168, 168), True,
        f"{STYLE}; grand keystone socket: heavy ornate gold ring with wing "
        "flourishes and an empty sapphire-blue recessed core, designed to "
        "read at 168 pixels"),
    "socket_hidden": (
        "socket_hidden.png", "1024x1024", (112, 112), True,
        f"{STYLE}; mysterious fog-shrouded circular socket: pale mist swirl "
        "inside a dim bronze ring, ghostly and unlit, designed to read at "
        "112 pixels"),
    "star_alloc": (
        "star_alloc.png", "1024x1024", (80, 80), True,
        f"{STYLE}; blazing golden four-pointed star with a soft warm halo, "
        "allocated skill marker, designed to read at 80 pixels"),
    "keystone_ring": (
        "keystone_ring.png", "1024x1024", (200, 200), True,
        f"{STYLE}; thin radiant sapphire-blue rune ring, open center, gentle "
        "outer glow, marks the ACTIVE keystone, designed to read at 200 "
        "pixels"),
    "currency_emblem": (
        "currency_emblem.png", "1024x1024", (64, 64), True,
        f"{STYLE}; class sigil currency icon: faceted gold diamond-shaped "
        "emblem chip on a tiny bronze setting, designed to read at 64 pixels"),
    "currency_stardust": (
        "currency_stardust.png", "1024x1024", (64, 64), True,
        f"{STYLE}; stardust currency icon: icy SILVER-BLUE four-pointed "
        "spark with tiny trailing motes, cold pale blue light, NOT gold, "
        "designed to read at 64 pixels"),
}
for cid, emblem in CRESTS.items():
    SPEC[f"crest_{cid}"] = (
        f"crest_{cid}.png", "1024x1024", (160, 160), True,
        f"{CREST_STYLE}; emblem: {emblem}")


def require_client():
    if not os.environ.get("OPENAI_API_KEY"):
        raise SystemExit("OPENAI_API_KEY is not set (source ~/.codex/.env)")
    from openai import OpenAI
    return OpenAI()


def _key_mask(a: np.ndarray, key: tuple[int, int, int] | None, thr: int) -> np.ndarray:
    if key is None:  # light background (white-ish)
        return (a[:, :, 0] >= thr) & (a[:, :, 1] >= thr) & (a[:, :, 2] >= thr)
    kr, kg, kb = key
    dist = (abs(a[:, :, 0].astype(int) - kr) + abs(a[:, :, 1].astype(int) - kg)
            + abs(a[:, :, 2].astype(int) - kb))
    return dist <= thr


def erode_alpha(img: Image.Image, px: int = 1) -> Image.Image:
    """Shrink alpha by px to drop key-color halo on silhouette edges."""
    a = np.array(img, dtype=np.uint8)
    alpha = a[:, :, 3]
    solid = alpha > 0
    for _ in range(px):
        shrunk = solid.copy()
        shrunk[1:, :] &= solid[:-1, :]
        shrunk[:-1, :] &= solid[1:, :]
        shrunk[:, 1:] &= solid[:, :-1]
        shrunk[:, :-1] &= solid[:, 1:]
        solid = shrunk
    a[:, :, 3] = np.where(solid, alpha, 0)
    return Image.fromarray(a)


def clean_alpha(img: Image.Image, thr: int = 90,
                key: tuple[int, int, int] | None = (255, 0, 255)) -> Image.Image:
    """Border-connected flood fill: strip baked key-color background."""
    a = np.array(img.convert("RGBA"), dtype=np.uint8)
    h, w = a.shape[:2]
    light = _key_mask(a, key, thr)
    seen = np.zeros((h, w), dtype=bool)
    dq: deque = deque()
    for x in range(w):
        for y in (0, h - 1):
            if light[y, x] and not seen[y, x]:
                seen[y, x] = True; dq.append((y, x))
    for y in range(h):
        for x in (0, w - 1):
            if light[y, x] and not seen[y, x]:
                seen[y, x] = True; dq.append((y, x))
    while dq:
        y, x = dq.popleft()
        for yy, xx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
            if 0 <= yy < h and 0 <= xx < w and light[yy, xx] and not seen[yy, xx]:
                seen[yy, xx] = True; dq.append((yy, xx))
    a[seen, 3] = 0
    return Image.fromarray(a)


def hollow_center(img: Image.Image, thr: int = 90,
                  key: tuple[int, int, int] | None = (255, 0, 255)) -> Image.Image:
    """Frame post-pass: also clear the enclosed key-color window (not just
    border-connected) by flooding from the image center."""
    a = np.array(img.convert("RGBA"), dtype=np.uint8)
    h, w = a.shape[:2]
    light = _key_mask(a, key, thr)
    cy, cx = h // 2, w // 2
    if not light[cy, cx]:
        return img
    seen = np.zeros((h, w), dtype=bool)
    seen[cy, cx] = True
    dq = deque([(cy, cx)])
    while dq:
        y, x = dq.popleft()
        for yy, xx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
            if 0 <= yy < h and 0 <= xx < w and light[yy, xx] and not seen[yy, xx]:
                seen[yy, xx] = True; dq.append((yy, xx))
    a[seen, 3] = 0
    return Image.fromarray(a)


def crop_to_aspect(img: Image.Image, tw: int, th: int) -> Image.Image:
    w, h = img.size
    want = tw / th
    have = w / h
    if abs(want - have) < 1e-3:
        return img
    if have > want:
        nw = int(h * want)
        x0 = (w - nw) // 2
        return img.crop((x0, 0, x0 + nw, h))
    nh = int(w / want)
    y0 = (h - nh) // 2
    return img.crop((0, y0, w, y0 + nh))


def generate(client, key: str, quality: str) -> Path:
    fname, canvas, target, transparent, prompt = SPEC[key]
    if transparent and key != "frame_border":
        prompt = (prompt + "; entire background is one solid uniform bright "
                  "magenta color #FF00FF, flat with no gradient, no vignette, "
                  "nothing else touches the background")
    kwargs = dict(model=MODEL, prompt=prompt, size=canvas, quality=quality,
                  output_format="png", n=1)
    result = client.images.generate(**kwargs)
    raw = base64.b64decode(result.data[0].b64_json)
    src = ASSET_DIR / f"_src_{fname}"
    src.write_bytes(raw)
    img = Image.open(src).convert("RGBA")
    if key == "frame_border":
        img = clean_alpha(img)
        img = hollow_center(img)
        img = erode_alpha(img)
    elif transparent:
        # Magenta key is absent from the art palette, so a GLOBAL key wipe is
        # safe and also clears enclosed pockets (ring centers, gaps between
        # star points) that border-connected flood fill can't reach.
        a = np.array(img.convert("RGBA"), dtype=np.uint8)
        a[_key_mask(a, (255, 0, 255), 90), 3] = 0
        img = erode_alpha(Image.fromarray(a))
    if target is not None:
        img = crop_to_aspect(img, *target)
        img = img.resize(target, Image.LANCZOS)
    out = ASSET_DIR / fname
    img.save(out)
    src.unlink()
    return out


def contact_sheet() -> Path:
    from PIL import ImageDraw, ImageFont
    paths = [ASSET_DIR / spec[0] for spec in SPEC.values()
             if (ASSET_DIR / spec[0]).exists()]
    cols = 7
    cell = 176
    rows = (len(paths) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * cell, rows * cell + 20), (16, 18, 28, 255))
    dr = ImageDraw.Draw(sheet)
    font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 11)
    for i, p in enumerate(sorted(paths, key=lambda x: x.name)):
        img = Image.open(p).convert("RGBA")
        img.thumbnail((cell - 24, cell - 34), Image.LANCZOS)
        x = (i % cols) * cell
        y = (i // cols) * cell
        sheet.alpha_composite(img, (x + (cell - img.width) // 2,
                                    y + 6 + (cell - 34 - img.height) // 2))
        dr.text((x + cell // 2, y + cell - 16), p.stem, font=font,
                fill=(220, 205, 160, 255), anchor="mm")
    out = PREVIEW_DIR / "meta40_asset_contact.png"
    sheet.save(out)
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", help="comma-separated keys")
    ap.add_argument("--quality", default="medium", choices=["low", "medium", "high"])
    ap.add_argument("--sheet-only", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()
    if args.sheet_only:
        print(f"contact sheet: {contact_sheet().relative_to(ROOT)}")
        return
    keys = list(SPEC) if not args.only else [k.strip() for k in args.only.split(",")]
    unknown = [k for k in keys if k not in SPEC]
    if unknown:
        raise SystemExit(f"unknown keys: {unknown}")
    if args.dry_run:
        for k in keys:
            fname, canvas, target, tr, _ = SPEC[k]
            print(f"{k:22s} {canvas:9s} -> {target or 'as-is'} transparent={tr} ({fname})")
        return
    ASSET_DIR.mkdir(parents=True, exist_ok=True)
    client = require_client()
    for i, k in enumerate(keys, 1):
        q = "high" if k in ("bg_sky", "frame_border") else args.quality
        try:
            out = generate(client, k, q)
        except Exception as exc:  # noqa: BLE001 — report and stop, billing errors matter
            print(f"[{i}/{len(keys)}] {k}: FAILED — {exc}", flush=True)
            sys.exit(2)
        print(f"[{i}/{len(keys)}] {k}: {out.relative_to(ROOT)}", flush=True)
    print(f"contact sheet: {contact_sheet().relative_to(ROOT)}")


if __name__ == "__main__":
    main()
