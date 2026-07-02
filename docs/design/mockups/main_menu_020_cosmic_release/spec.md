# Main Menu 0.2.0 Cosmic Release Background

Дата: 2026-07-02
Источник задачи: direct user request. User explicitly requested OpenAI Image Generation,
so this pass is an intentional OpenAI override to the default PixelLab-first UI/art
rule for a release background and social announcement image.

## Assets

| Role | Path |
| --- | --- |
| Runtime main-menu background | `assets/backgrounds/main_menu_epic_battle_v3.png` |
| OpenAI source image | `docs/design/references/main_menu_020_cosmic_release/main_menu_020_cosmic_openai_source.png` |
| Character/boss reference sheet | `docs/design/references/main_menu_020_cosmic_release/character_boss_reference_sheet.png` |
| Previous runtime backup | `docs/design/backups/main_menu_020_cosmic_release/main_menu_epic_battle_v3_pre_020_cosmic.png` |
| Full-size preview copy | `docs/design/previews/main_menu_020_cosmic_release/main_menu_020_cosmic_background_2560x1440.png` |
| Telegram/Discord announcement | `assets/marketing/fantasydisk_020_announcement_telegram_discord.png` |

## Runtime Background Contract

- Native runtime size: `2560x1440`, RGB PNG.
- Main-menu code path remains unchanged: `MAIN_MENU_BACKGROUND` still points to
  `res://assets/backgrounds/main_menu_epic_battle_v3.png`.
- Left source-space menu column remains low-detail and dark for
  `MM_SAFE_2K = Rect2(72, 394, 380, 674)`.
- Top-left title area remains readable for
  `MM_TITLE_2K = Rect2(56, 44, 720, 270)`.
- The background contains no baked UI text, buttons, panels, frames, title, logo,
  or watermark.
- Visual focus is center-right: cosmic character atlas, star-chart rings,
  constellation paths, pixel-art hero silhouettes and distant boss figures.

## Announcement Contract

- Social image size: `1920x1080`, RGB PNG.
- Uses the same background composition as the runtime asset.
- Text is local raster overlay, not AI-baked text:
  - `ВЕРСИЯ 0.2.0`
  - `ПИКСЕЛЬНЫЕ ГЕРОИ`
  - `Редизайн персонажей`
  - `теперь герои в pixel-art`
  - `Атлас героев и созвездия`
  - `новые боссы на горизонте`
- The existing transparent `FantasyDisk` menu title asset is composited on top,
  preserving the release logo style.

## Validation

- Visual inspection: runtime background and announcement PNG checked after resize
  and composition.
- Godot import/UI smoke:
  `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_ui_test.gd`
  -> PASS.
