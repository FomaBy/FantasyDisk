#!/usr/bin/env python3
"""SCRUM-805: settings v5 UI element sprites via OpenAI gpt-image-2.

Pipeline mirrors build_combat_hud_v2_assets.py (SCRUM-806, QA PASSED):
transparent generation -> border flood-clean -> alpha bbox trim -> LANCZOS to
exact final size. Elements carry no baked text; Godot renders text on top.

Run: source ~/.codex/.env, then python3 tools/build_settings_v5_elements.py [--only name ...]
"""
from __future__ import annotations

import base64
import os
import pathlib
import sys
from collections import deque
from concurrent.futures import ThreadPoolExecutor, as_completed

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "assets" / "sprites" / "ui" / "frames" / "settings_v5"

STYLE = (
    "Dark fantasy game UI element, crisp pixel-art style, dark aged leather and riveted bronze, "
    "muted gold trim, ember-red gem accents, clean readable silhouette, single isolated element "
    "centered on a fully transparent background, flat front-facing UI sprite, no text, no lettering, no watermark. "
)

WIDE_HINT = "The element is a wide horizontal bar with proportions about {ratio}, filling most of the canvas width. "

JOBS: list[dict] = []


def job(name: str, final: tuple[int, int], prompt: str, ratio: str | None = None,
        crop_band: float | None = None) -> None:
    p = STYLE + (WIDE_HINT.format(ratio=ratio) if ratio else "") + prompt
    JOBS.append({"name": name + ".png", "final": final, "prompt": p, "crop_band": crop_band})


NEUTRAL = ("wide rectangular game button plate: dark aged leather face, bronze border with small "
           "corner rivets, subtle top bevel light, empty center. ")
PRIMARY = ("wide rectangular game button plate: deep ember-red leather face, gold border trim with "
           "small corner studs, subtle top bevel light, empty center. ")
FIELD = ("recessed rectangular input field: very dark sunken leather center, thin bronze frame, "
         "subtle inner shadow, empty. ")
TAB = "folder-style tab plate with slightly rounded top corners: "

job("ui_settings_v5_btn_neutral_normal", (320, 80), NEUTRAL, ratio="4 to 1")
job("ui_settings_v5_btn_neutral_hover", (320, 80), NEUTRAL + "Edges lit with a warm golden glow highlight.", ratio="4 to 1")
job("ui_settings_v5_btn_neutral_pressed", (320, 80), NEUTRAL + "Pressed inset look: darker face, shadowed top edge.", ratio="4 to 1")
job("ui_settings_v5_btn_neutral_disabled", (320, 80), NEUTRAL + "Desaturated gray-brown, dull border, inactive.", ratio="4 to 1")
job("ui_settings_v5_btn_primary_normal", (320, 80), PRIMARY, ratio="4 to 1")
job("ui_settings_v5_btn_primary_hover", (320, 80), PRIMARY + "Edges lit with a bright golden glow highlight.", ratio="4 to 1")
job("ui_settings_v5_btn_primary_pressed", (320, 80), PRIMARY + "Pressed inset look: darker face, shadowed top edge.", ratio="4 to 1")
job("ui_settings_v5_btn_primary_disabled", (320, 80), PRIMARY + "Desaturated dull red-gray, inactive.", ratio="4 to 1")
job("ui_settings_v5_tab_active", (340, 84), TAB + "warm lit leather face, bright gold edge trim, a small glowing ember gem embedded near the left edge.", ratio="4 to 1")
job("ui_settings_v5_tab_hover", (340, 84), TAB + "mid-dark leather face, faint gold glint along the edge.", ratio="4 to 1")
job("ui_settings_v5_tab_inactive", (340, 84), TAB + "dark recessed leather face, dull bronze edge, muted.", ratio="4 to 1")
job("ui_settings_v5_field_normal", (560, 56), FIELD, ratio="10 to 1")
job("ui_settings_v5_field_hover", (560, 56), FIELD + "Brighter bronze frame with a faint gold sheen.", ratio="10 to 1")
job("ui_settings_v5_field_pressed", (560, 56), FIELD + "Darker pressed inset with a strong inner shadow.", ratio="10 to 1")
job("ui_settings_v5_arrow_socket", (56, 56), "small square bronze socket plate with a downward-pointing gold triangular arrow rune in the center.")
job("ui_settings_v5_checkbox_on", (52, 52), "square bronze gem socket holding a lit glowing ember-red faceted gem, small warm glow.")
job("ui_settings_v5_checkbox_off", (52, 52), "square bronze gem socket with an empty dark hollow, unlit.")
job("ui_settings_v5_slider_track", (420, 18), "long slim horizontal slider groove: dark iron channel with subtle bronze end caps, flat.", ratio="12 to 1", crop_band=0.72)
job("ui_settings_v5_slider_fill", (416, 12), "long slim horizontal molten-gold glowing fill bar with a subtle ember gradient, flat.", ratio="16 to 1", crop_band=0.72)
job("ui_settings_v5_modal_frame_openai", (1420, 1060), "large game window frame: thin riveted bronze-iron border along the outer edge only, small bronze corner caps, vast empty flat dark aged leather center, no inner frame, no ornament in the center.", ratio="4 to 3")
job("ui_settings_v5_content_inset_openai", (1276, 630), "wide recessed panel: very dark sunken leather field with a thin bronze inner outline near the edge, subtle stitching, flat empty center.", ratio="2 to 1")
job("ui_settings_v5_slider_gem", (36, 36), "small round faceted amber gem knob set in a gold bezel.")
job("ui_settings_v5_value_chip", (96, 48), "small recessed rectangular plate: dark sunken center, thin bronze frame, empty.", ratio="2 to 1")
job("ui_settings_v5_icon_screen", (44, 44), "small game icon: bronze-framed crystal scrying mirror with a pale glassy sheen.")
job("ui_settings_v5_icon_sound", (44, 44), "small game icon: bronze war horn with gold bands.")
job("ui_settings_v5_icon_controls", (44, 44), "small game icon: armored gauntlet gripping a golden key.")
job("ui_settings_v5_medallion", (180, 72), "wide bronze dragon-head medallion plaque, symmetrical, metallic, mounted on a small backing plate.", ratio="2.5 to 1")


def flood_clean_alpha(im: Image.Image, tol: int = 26) -> Image.Image:
    im = im.convert("RGBA")
    px = im.load()
    w, h = im.size
    bg = px[0, 0][:3]
    seen = [[False] * w for _ in range(h)]
    q: deque[tuple[int, int]] = deque()
    for x in range(w):
        q.append((x, 0)); q.append((x, h - 1))
    for y in range(h):
        q.append((0, y)); q.append((w - 1, y))
    while q:
        x, y = q.popleft()
        if x < 0 or y < 0 or x >= w or y >= h or seen[y][x]:
            continue
        seen[y][x] = True
        r, g, b, a = px[x, y]
        if a == 0 or (abs(r - bg[0]) + abs(g - bg[1]) + abs(b - bg[2])) <= tol * 3:
            px[x, y] = (r, g, b, 0)
            q.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
    return im


def postprocess(im: Image.Image, j: dict) -> Image.Image:
    if im.getpixel((0, 0))[3] > 8:
        im = flood_clean_alpha(im)
    if j["crop_band"]:
        w, h = im.size
        band = int(h * j["crop_band"] / 2)
        im = im.crop((0, h // 2 - band, w, h // 2 + band))
    bbox = im.getchannel("A").getbbox()
    if bbox:
        im = im.crop(bbox)
    return im.resize(j["final"], Image.Resampling.LANCZOS)


def run_job(client, j: dict) -> str:
    out = OUT_DIR / j["name"]
    if out.exists():
        return f"skip {j['name']}"
    kwargs = dict(model="gpt-image-2", prompt=j["prompt"], size="1024x1024", quality="high", n=1)
    try:
        res = client.images.generate(background="transparent", **kwargs)
    except Exception:
        res = client.images.generate(**kwargs)
    raw = base64.b64decode(res.data[0].b64_json)
    tmp = OUT_DIR / ("_src_" + j["name"])
    tmp.write_bytes(raw)
    im = Image.open(tmp).convert("RGBA")
    im = postprocess(im, j)
    im.save(out)
    tmp.unlink()
    return f"done {j['name']} {im.size}"


def main() -> int:
    if not os.environ.get("OPENAI_API_KEY"):
        print("OPENAI_API_KEY is not set", file=sys.stderr)
        return 2
    from openai import OpenAI
    client = OpenAI()
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    only = set()
    if "--only" in sys.argv:
        only = set(sys.argv[sys.argv.index("--only") + 1:])
    jobs = [j for j in JOBS if not only or j["name"].removesuffix(".png") in only or j["name"] in only]
    errors = 0
    with ThreadPoolExecutor(max_workers=4) as pool:
        futs = {pool.submit(run_job, client, j): j for j in jobs}
        for fut in as_completed(futs):
            try:
                print(fut.result(), flush=True)
            except Exception as exc:  # noqa: BLE001
                errors += 1
                print(f"FAIL {futs[fut]['name']}: {exc}", flush=True)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
