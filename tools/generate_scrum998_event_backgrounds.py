#!/usr/bin/env python3
"""SCRUM-998 — уникальные фоны стартового пака событий (OpenAI gpt-image-2).

12 полноэкранных фонов событий (id закреплены в docs/tasks/SCRUM-995.md) в
painterly dark-fantasy стиле проекта (НЕ пиксель-арт). Канон пайплайна фонов
(см. tools/generate_atlas_style_screens_openai.py): генерация 1536x1024 ->
центр-кроп 16:9 -> PIL LANCZOS 2560x1440.

Контракт safe-зон с UI события (SCRUM-997): главный сюжет в левых ~55-60%
ширины и верхних ~70% высоты; правые ~38% ширины (диалог-панель) и нижние
~24% высоты (карточки выбора) — тёмные, спокойные, низкодетальные.

Runtime: assets/backgrounds/events/event_bg_<id>.png (+ .import отдельно
через Godot), референс-копия в docs/design/references/events_backgrounds_pack/.

Usage:
  python3 tools/generate_scrum998_event_backgrounds.py [--only id1,id2]
      [--workers N] [--quality high] [--dry-run]
  python3 tools/generate_scrum998_event_backgrounds.py --sheet-only
  python3 tools/generate_scrum998_event_backgrounds.py --overlays-only
  python3 tools/generate_scrum998_event_backgrounds.py --manifest-only

Billing/quota hard limit НЕ ретраится — скрипт выходит с кодом 3 (блокер в
Jira, см. память проекта 2026-07-01).
"""

from __future__ import annotations

import argparse
import base64
import io
import json
import shutil
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
from generate_meta40_ui_openai import (  # noqa: E402
    MODEL, crop_to_aspect, require_client)

ROOT = Path(__file__).resolve().parents[1]
ASSET_DIR = ROOT / "assets/backgrounds/events"
REF_DIR = ROOT / "docs/design/references/events_backgrounds_pack"
PREVIEW_DIR = ROOT / "docs/design/previews"

TARGET = (2560, 1440)
CANVAS = "1536x1024"
FONT = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"

# Единый стиль пака: живописный тёмный D&D, палитра проекта.
STYLE = (
    "painterly dark fantasy illustration, detailed digital oil painting in "
    "the style of a Dungeons and Dragons rulebook scene, dramatic cinematic "
    "lighting, dark moody base palette with warm gold and firelight accents "
    "and subtle violet arcane glow, rich brushwork, NOT pixel art, not "
    "8-bit, no text, no letters, no words, no frame, no border, no "
    "watermark, no game interface elements, 16:9 full-screen game background")

# Контракт safe-зон SCRUM-997 (правая диалог-панель 38%, нижний ряд карт 24%).
SAFE = (
    "composition rule: the main subject and all important detail sit in the "
    "left 55 percent of the frame and the upper 70 percent of the frame; "
    "the right third and the bottom quarter of the image are kept dark, "
    "calm and low-detail — plain shadow, mist, empty ground or dim sky — "
    "so translucent UI panels overlay cleanly there")

# id (prio-порядок из docs/tasks/SCRUM-998.md) -> сюжет сцены.
SPEC: dict[str, str] = {
    "caravan_bandits": (
        "a burning merchant caravan ambushed on a dusty trade road at dusk: "
        "two overturned wagons with spilled crates and barrels burning on "
        "the left, embers and thick smoke rising, dark silhouettes of "
        "bandits with drawn blades closing in from the middle distance, a "
        "panicked draft horse rearing, warm orange firelight against a deep "
        "twilight sky"),
    "sudden_fork": (
        "a fork in a dirt road deep inside a cursed forest: two diverging "
        "paths split around a huge gnarled dead tree on the left, cold grey "
        "fog crawling low over the ground, twisted black trunks with "
        "clawing branches, faint violet witch-lights glimmering far between "
        "the trees, thin pale moonlight from above"),
    "sacrifice_altar": (
        "a black stone sacrificial altar in an underground shrine: the "
        "altar slab on the left glistening dark red, carved runes glowing "
        "faint violet along its sides, clusters of guttering candles with "
        "warm flames, a looming shadowed stone idol behind it, thin ritual "
        "smoke curling upward into the vaulted dark"),
    "night_market": (
        "a smugglers' night market hidden in a narrow city alley: canvas "
        "stalls and tents on the left glowing with warm golden lanterns, "
        "hooded traders as dim silhouettes haggling over crates, exotic "
        "wares and rolled carpets, strings of small paper lamps overhead, "
        "deep blue night shadows swallowing the far end of the alley"),
    "cursed_chapel": (
        "the interior of a ruined chapel at night: a tall shattered "
        "stained-glass window on the left pouring pale moonlight over "
        "broken pews and rubble, a heavy sealed crypt door bound with "
        "rusted chains in the wall beneath it, drifting dust motes in the "
        "light beams, a faint violet glow seeping from under the crypt "
        "door"),
    "gilded_gambler": (
        "a candlelit gambling table in a dark tavern corner: scattered "
        "ivory dice, stacked gold coins and worn cards on green felt on "
        "the left, across the table sits a ghostly translucent gambler in "
        "a deep hood with faint golden glowing eyes, candle flames "
        "reflecting warm gold off the coins"),
    "wounded_mercenary": (
        "a wounded mercenary slumped against a broken cart wheel beside a "
        "muddy trade road in grey pouring rain: his cracked shield and "
        "notched sword lying in the mud on the left, blood-stained "
        "bandages, dull grey daylight, a distant treeline lost in rain "
        "haze"),
    "stone_guardian": (
        "a colossal ancient stone golem standing guard before massive "
        "carved gates: the guardian rising to full height on the left, "
        "moss and deep cracks over rune-etched granite, its chest core and "
        "the gate runes glowing faint violet, broken pillars at its feet "
        "emphasizing its scale"),
    "heroes_graveyard": (
        "a graveyard of fallen heroes on a foggy hillside at night: rows "
        "of weathered graves each marked by a sword thrust into the earth "
        "on the left, ragged faded banners, black ravens perched on the "
        "sword hilts, low creeping mist, cold moonlight breaking through "
        "torn clouds"),
    "old_well": (
        "an old moss-covered stone wishing well in a forest clearing on a "
        "moonlit night: the well with its wooden crossbeam and hanging "
        "bucket standing on the left, swarms of tiny green-gold fireflies "
        "drifting around it, soft silver moonlight, dark encircling trees "
        "at the clearing edge"),
    "war_drums_camp": (
        "a distant war camp of a savage horde behind a ridge, seen from a "
        "dark hilltop: dozens of campfires and torch lines glowing warm "
        "orange across the valley on the left, crude totems and spiked "
        "banners as black silhouettes, columns of smoke rising into a "
        "starless night sky"),
    "fallen_star": (
        "a smoking impact crater in a dark night field: at its heart on "
        "the left a jagged fallen star shard glowing white-violet, molten "
        "cracks radiating outward through scorched earth and burnt grass, "
        "drifting sparks, a faint glowing smoke trail arcing up into the "
        "night sky"),
}

ORDER = list(SPEC)  # порядок словаря = приоритет 1..12 из спеки

_print_lock = threading.Lock()


class BillingBlocked(RuntimeError):
    """Квота/биллинг OpenAI мертвы — не ретраить, фиксировать блокер."""


def _is_billing_error(exc: Exception) -> bool:
    text = str(exc).lower()
    return any(t in text for t in (
        "billing_hard_limit_reached", "billing hard limit", "billing",
        "insufficient_quota", "exceeded your current quota"))


def _is_transient(exc: Exception) -> bool:
    text = str(exc).lower()
    return any(t in text for t in (
        "rate limit", "rate_limit", "timeout", "timed out", "connection",
        "server_error", "internal server error", "overloaded", "temporarily",
        "502", "503", "504"))


def full_prompt(key: str) -> str:
    return f"{SPEC[key]}; {SAFE}; {STYLE}"


def generate_one(client, key: str, quality: str, retries: int = 3) -> Path:
    prompt = full_prompt(key)
    delay = 12.0
    for attempt in range(1, retries + 1):
        try:
            result = client.images.generate(
                model=MODEL, prompt=prompt, size=CANVAS, quality=quality,
                output_format="png", n=1)
            break
        except Exception as exc:  # noqa: BLE001 — сортируем billing/transient
            if _is_billing_error(exc):
                raise BillingBlocked(str(exc)) from exc
            if attempt >= retries or not _is_transient(exc):
                raise
            with _print_lock:
                print(f"  {key}: transient ({exc}) — retry {attempt}/"
                      f"{retries - 1} in {delay:.0f}s", flush=True)
            time.sleep(delay)
            delay *= 2
    raw = base64.b64decode(result.data[0].b64_json)
    img = Image.open(io.BytesIO(raw)).convert("RGB")
    img = crop_to_aspect(img, *TARGET)
    img = img.resize(TARGET, Image.LANCZOS)
    out = ASSET_DIR / f"event_bg_{key}.png"
    img.save(out, optimize=True)
    REF_DIR.mkdir(parents=True, exist_ok=True)
    shutil.copy2(out, REF_DIR / out.name)
    return out


def contact_sheet() -> Path:
    paths = [ASSET_DIR / f"event_bg_{k}.png" for k in ORDER
             if (ASSET_DIR / f"event_bg_{k}.png").exists()]
    cell_w, cell_h = 640, 400
    cols = 3
    rows = (len(paths) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * cell_w, rows * cell_h), (14, 14, 20))
    dr = ImageDraw.Draw(sheet)
    font = ImageFont.truetype(FONT, 18)
    for i, p in enumerate(paths):
        img = Image.open(p).convert("RGB")
        img.thumbnail((cell_w - 20, cell_h - 46), Image.LANCZOS)
        x = (i % cols) * cell_w
        y = (i // cols) * cell_h
        sheet.paste(img, (x + (cell_w - img.width) // 2, y + 8))
        dr.text((x + cell_w // 2, y + cell_h - 20), p.stem, font=font,
                fill=(222, 205, 160), anchor="mm")
    PREVIEW_DIR.mkdir(parents=True, exist_ok=True)
    out = PREVIEW_DIR / "scrum998_event_backgrounds_contact.png"
    sheet.save(out)
    return out


def safe_zone_overlays(key: str = "caravan_bandits") -> list[Path]:
    """Оверлей контракта SCRUM-997: правые 38% ширины + нижние 24% высоты."""
    src = ASSET_DIR / f"event_bg_{key}.png"
    outs: list[Path] = []
    for name, size in (("scrum998_event_bg_safezones_720.png", (1280, 720)),
                       ("scrum998_event_bg_safezones_1440.png", (2560, 1440))):
        img = Image.open(src).convert("RGB").resize(size, Image.LANCZOS)
        w, h = size
        panel_x = int(w * (1.0 - 0.38))
        cards_y = int(h * (1.0 - 0.24))
        ov = Image.new("RGBA", size, (0, 0, 0, 0))
        dr = ImageDraw.Draw(ov)
        dr.rectangle([panel_x, 0, w, h], fill=(90, 60, 200, 96))
        dr.rectangle([0, cards_y, w, h], fill=(200, 150, 40, 96))
        dr.rectangle([panel_x, 0, w - 1, h - 1], outline=(160, 120, 255, 220),
                     width=max(2, w // 640))
        dr.rectangle([0, cards_y, w - 1, h - 1], outline=(255, 200, 90, 220),
                     width=max(2, w // 640))
        merged = Image.alpha_composite(img.convert("RGBA"), ov).convert("RGB")
        dr2 = ImageDraw.Draw(merged)
        font = ImageFont.truetype(FONT, max(16, w // 55))
        dr2.text((panel_x + (w - panel_x) // 2, h // 3),
                 "dialog panel 38%", font=font, fill=(235, 225, 255),
                 anchor="mm")
        dr2.text((w // 3, cards_y + (h - cards_y) // 2),
                 "choice cards 24%", font=font, fill=(255, 235, 190),
                 anchor="mm")
        out = PREVIEW_DIR / name
        merged.save(out)
        outs.append(out)
    return outs


def write_manifest() -> Path:
    entries = []
    for k in ORDER:
        f = ASSET_DIR / f"event_bg_{k}.png"
        entries.append({
            "id": k,
            "file": f"assets/backgrounds/events/{f.name}",
            "prompt": full_prompt(k),
            "status": "done" if f.exists() else "blocked",
            "safe_zones_ok": bool(f.exists()),
        })
    REF_DIR.mkdir(parents=True, exist_ok=True)
    out = REF_DIR / "manifest.json"
    out.write_text(json.dumps(entries, ensure_ascii=False, indent=2) + "\n",
                   encoding="utf-8")
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", help="comma-separated event ids")
    ap.add_argument("--workers", type=int, default=5)
    ap.add_argument("--quality", default="high",
                    choices=["low", "medium", "high"])
    ap.add_argument("--sheet-only", action="store_true")
    ap.add_argument("--overlays-only", action="store_true")
    ap.add_argument("--manifest-only", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    if args.sheet_only:
        print(f"contact sheet: {contact_sheet().relative_to(ROOT)}")
        return
    if args.overlays_only:
        for p in safe_zone_overlays():
            print(f"overlay: {p.relative_to(ROOT)}")
        return
    if args.manifest_only:
        print(f"manifest: {write_manifest().relative_to(ROOT)}")
        return

    keys = ORDER if not args.only else [k.strip()
                                        for k in args.only.split(",")]
    unknown = [k for k in keys if k not in SPEC]
    if unknown:
        raise SystemExit(f"unknown ids: {unknown}")
    if args.dry_run:
        for k in keys:
            print(f"{k:20s} {CANVAS} -> {TARGET} event_bg_{k}.png")
        return

    ASSET_DIR.mkdir(parents=True, exist_ok=True)
    client = require_client()
    failed: list[str] = []
    billing_dead = threading.Event()

    def job(k: str) -> Path:
        if billing_dead.is_set():
            raise BillingBlocked("skipped: billing already reported dead")
        return generate_one(client, k, args.quality)

    with ThreadPoolExecutor(max_workers=max(1, args.workers)) as pool:
        futures = {pool.submit(job, k): k for k in keys}
        done_n = 0
        for fut in as_completed(futures):
            k = futures[fut]
            try:
                out = fut.result()
            except BillingBlocked as exc:
                billing_dead.set()
                failed.append(k)
                with _print_lock:
                    print(f"BILLING BLOCKED on {k}: {exc}", flush=True)
            except Exception as exc:  # noqa: BLE001
                failed.append(k)
                with _print_lock:
                    print(f"{k}: FAILED — {exc}", flush=True)
            else:
                done_n += 1
                with _print_lock:
                    print(f"[{done_n}/{len(keys)}] {k}: "
                          f"{out.relative_to(ROOT)}", flush=True)

    if billing_dead.is_set():
        print("RESULT: BILLING/QUOTA HARD LIMIT — стоп без ретраев", flush=True)
        sys.exit(3)
    if failed:
        print(f"RESULT: failed ids: {failed}", flush=True)
        sys.exit(2)
    print("RESULT: OK", flush=True)


if __name__ == "__main__":
    main()
