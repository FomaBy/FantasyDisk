#!/usr/bin/env python3
"""SCRUM-805: settings v5 mockups via OpenAI gpt-image-2 (3 tabs + 3 state sheets).

Mockups are style/composition references (references/settings_v5/), not final art.
Run: source ~/.codex/.env (OPENAI_API_KEY) then python3 tools/build_settings_v5_mockups.py
"""
from __future__ import annotations

import base64
import os
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "references" / "settings_v5"

STYLE = (
    "Dark fantasy pixel-art game settings menu mockup, full 16:9 game screen. "
    "Deep charcoal background dimmed with vignette. Centered modal panel about 55% of screen width and 73% of height: "
    "aged dark leather field framed by a riveted bronze-iron border (~4% screen width thick), a small bronze dragon-head "
    "medallion centered ON the top border edge. Panel title 'НАСТРОЙКИ' in pale gold capitals at top center inside the panel. "
    "Below the title a row of three folder-style tabs with icons: 'Экран', 'Звук', 'Управление' — the active tab is warm-lit "
    "leather with a gold edge and a small glowing ember gem, inactive tabs darker and recessed. "
    "Below tabs an inset darker ledger-style content area with a thin bronze inner outline, generous even padding. "
    "Inside the content area a strict two-column grid: left column labels in pale gold, right column controls all of EQUAL width "
    "(about 44% of the panel width), equal row heights, generous vertical spacing. "
    "At the bottom of the modal above the lower border: a thin bronze divider and three buttons side by side: "
    "'Применить' (ember-red leather with gold trim, primary), 'Вернуть' and 'Назад' (neutral dark leather with bronze trim). "
    "Crisp pixel art, clean readable large text, high contrast, NOTHING overlapping, no text or content touching the ornamental "
    "border, no stretched elements, neat professional game UI like Baldur's Gate 3 or Darkest Dungeon settings reimagined as pixel art."
)

TABS = {
    "mockup_tab_screen.png": (
        "Active tab: 'Экран'. Content rows top to bottom: "
        "'Монитор' with a dropdown field reading 'Экран 1 (2560×1440)' and a bronze ▼ rune socket on its right edge; "
        "'Разрешение' with dropdown '2560×1440'; "
        "'Режим окна' with dropdown 'Полноэкранный'; "
        "'Тряска камеры' with a square gem-socket checkbox in ON state (lit ember gem) and word 'Вкл.'; "
        "below rows a small amber status line 'Экранные настройки применены.'"
    ),
    "mockup_tab_sound.png": (
        "Active tab: 'Звук'. Content rows top to bottom: "
        "'Общая громкость' with a horizontal slider (dark groove, glowing gold fill to 80%, faceted gem knob) and a small value chip '80%'; "
        "'Музыка' with same slider at 60%, chip '60%' and a gem-socket checkbox ON; "
        "'Эффекты' with slider at 70%, chip '70%' and gem checkbox ON; "
        "last row: a neutral leather button 'Сбросить звук' aligned to the controls column."
    ),
    "mockup_tab_controls.png": (
        "Active tab: 'Управление'. Content rows top to bottom: "
        "'Прицеливание' with dropdown 'Автонаводка на ближайшего'; "
        "'Дебаг-режим' with gem-socket checkbox OFF (empty dark socket) and word 'Выкл.'; "
        "'Боевой фидбек' with gem checkbox ON and 'Вкл.'; "
        "then key binding rows: 'Движение вверх' with an inset key field '[W]', 'Движение вниз' with '[S]', 'Пауза' with '[Esc]'; "
        "a small hint line 'Клик по биндингу, затем нажми клавишу.' and a neutral button 'Сбросить управление'; "
        "a slim bronze scroll bar on the right edge of the content area."
    ),
}

SHEET_STYLE = (
    "Pixel-art UI element states sheet for a dark fantasy game settings menu, on a flat dark neutral background, "
    "organized in labeled horizontal rows with even spacing, each state drawn at identical size, crisp pixel art, "
    "leather/bronze/gold/ember-red palette, clean silhouettes, readable, no overlaps. "
)

SHEETS = {
    "states_tab_screen.png": (
        "Rows: 1) folder tab plate 'Экран' states: inactive, hover, active(gold edge + lit ember gem); "
        "2) dropdown field states: normal, hover(brighter bronze frame), open(pressed inset, ▼ flipped); "
        "3) gem-socket checkbox states: off(empty socket), hover(faint glow), on(lit ember gem); "
        "4) bottom button 'Применить' states: normal, hover(glowing gold edge), pressed(inset darker), disabled(gray desaturated)."
    ),
    "states_tab_sound.png": (
        "Rows: 1) folder tab plate 'Звук' states: inactive, hover, active; "
        "2) horizontal slider states: normal(gold fill, gem knob), hover(knob glint), dragging(knob pressed, brighter fill), muted(gray fill); "
        "3) value chip states: static, updating(brighter text); "
        "4) button 'Сбросить звук' states: normal, hover, pressed, disabled."
    ),
    "states_tab_controls.png": (
        "Rows: 1) folder tab plate 'Управление' states: inactive, hover, active; "
        "2) key bind field states: normal '[W]', hover, listening(pulsing ember outline, text '...'), conflict(red outline); "
        "3) dropdown field states: normal, hover, open; "
        "4) button 'Назад' states: normal, hover, pressed."
    ),
}


def main() -> int:
    if not os.environ.get("OPENAI_API_KEY"):
        print("OPENAI_API_KEY is not set", file=sys.stderr)
        return 2
    from openai import OpenAI
    client = OpenAI()
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    jobs = [(n, STYLE + " " + extra, "1536x1024") for n, extra in TABS.items()]
    jobs += [(n, SHEET_STYLE + extra, "1536x1024") for n, extra in SHEETS.items()]
    for name, prompt, size in jobs:
        out = OUT_DIR / name
        if out.exists():
            print("skip (exists)", name, flush=True)
            continue
        print("generating", name, flush=True)
        res = client.images.generate(model="gpt-image-2", prompt=prompt, size=size,
                                     quality="high", n=1)
        out.write_bytes(base64.b64decode(res.data[0].b64_json))
        print("saved", out, flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
