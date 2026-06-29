# SCRUM-678: Codex/Glossary UI Design Package

Jira: SCRUM-678 · Role: Design / Codex · Lane: Codex · Sprint: Спринт 0.1.7
Статус: done — ready for QA / backend integration handoff
Owner: Design/Codex `codex-design-board-watcher`
Branch/worktree: `codex/design-board-watcher-20260629-0711` · `/Users/sergeyfomin/Documents/FantasyDisk_worktrees/design-board-watcher`

## Scope

Design-only rebuild package for the in-game Codex/Glossary screen: OpenAI 2K mockup, exact content zones, frame/button assets, central clean icon-grid direction, and backend handoff notes. Runtime GDScript integration is out of scope for this task.

## Outputs

- Accepted OpenAI mockup: `docs/design/references/codex_glossary_scrum678/codex_glossary_2k_mockup_v2.png`
- Rejected first pass/source evidence: `docs/design/references/codex_glossary_scrum678/codex_glossary_2k_mockup.png` (center placeholders were too frame-like)
- Spec: `docs/design/mockups/codex_glossary_scrum678/spec.md`
- Layout JSON: `docs/design/mockups/codex_glossary_scrum678/layout.json`
- Safe-zone preview: `docs/design/previews/codex_glossary_scrum678_safe_zones.png`
- Asset contact sheet: `docs/design/previews/codex_glossary_scrum678_asset_contact.png`
- Runtime assets: `assets/sprites/ui/frames/codex_glossary/*.png`

## Runtime Assets

| Asset | Size | Notes |
| --- | ---: | --- |
| `ui_frame_cg_main.png` | `2496x1387` | screen shell, margins `70/82/70/76`, content `96/106/96/92` |
| `ui_frame_cg_nav.png` | `430x1130` | category panel, margins `42/58/42/54`, content `52/70/52/70` |
| `ui_frame_cg_grid.png` | `1120x1130` | central grid/list panel, margins `42/58/42/54`, content `74/70/74/70` |
| `ui_frame_cg_detail.png` | `764x1130` | right detail panel, margins `42/58/42/54`, content `76/74/76/76` |
| `ui_btn_cg_category_{normal,hover,pressed,active}.png` | `326x118` | category switch states |
| `ui_btn_cg_back_{normal,hover,pressed,disabled}.png` | `260x104` | shared Back button states |
| `ui_frame_cg_grid_hover_glow.png` | `144x144` | subtle icon hover/selected glow; not a heavy item frame |
| `ui_frame_cg_entry_separator.png` | `972x6` | optional clean list divider |

All assets are RGBA with transparent outer alpha and no baked text.

## Backend Handoff Notes

- Register the new assets in `scripts/ui/ui_theme_paths.gd` under a new Codex/Glossary key family or replace current `codex_*` keys after QA acceptance.
- In `scripts/ui_screens.gd::_show_codex_screen`, map the layout to the 2560x1440 rectangles from `spec.md` / `layout.json`, scaled uniformly to runtime viewport.
- Convert the central sector away from heavy per-entry cards. Preferred runtime pattern: larger unframed icons (`96-112px @2K`) plus compact title/subtitle lines, using `ui_frame_cg_grid_hover_glow.png` only for hover/selected state.
- Keep category labels, icons, portraits, chips and body text inside the listed content margins. No content may touch frame rails, corner claws or ruby markers.
- Long right-panel descriptions must scroll inside `detail_text_zone`.

## Verification

- OpenAI mockup generated via `$fantasydisk-asset-generator`.
- v2 mockup accepted because the central sector shows larger standalone icons without individual item frames.
- Asset dimensions/alpha checked with Pillow.
- `git diff --check` pending before commit.
- No production runtime code changed in this design task.

## Result

Design package complete. Backend integration can consume the spec/assets without re-planning content zones.

Disk cleanup: temporary generator script in `/private/tmp/scrum678_generate_assets.py` can be removed after commit; no Godot cache created.

## QA-Вердикт

Статус: PASSED

Дата: 2026-06-29
QA: claude-qa-scrum678 (взято на себя после bounce-loop воркера codex-design-board-watcher)
Доставка: пакет был на ветке codex/design-board-watcher-20260629-0711 без влития в origin/dev и без .import. QA забрал 21 файл в worktree от origin/dev, сгенерировал .import (Godot --import, валидные uid), влил в origin/dev.
- 14 PNG (frames cg_main/nav/grid/detail/grid_hover_glow/entry_separator + кнопки cg_category_{normal,hover,pressed,active} + cg_back_{normal,hover,pressed,disabled}) + 14 валидных .import (14 уникальных uid).
- Docs: mockup 2K (+v2), spec.md/layout.json, previews safe_zones/asset_contact.
- Готово к runtime-интеграции SCRUM-679.
