# Back-end Task: Integrate SCRUM-390 Combat HUD Redraw

Статус: done
Приоритет: high
Роль: Back-end (UI)
Версия: 0.1.5
Создано: 2026-06-14
Источник: SCRUM-390 `design_combat_hud_full_redraw_skill_task.md`
Jira: SCRUM-400
QA: in_progress (2026-06-14)

## Dispatch

- 2026-06-14 16:52 UTC — Documentation dispatcher routed this Back-end handoff to
  existing Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2`.
  Reasoning must stay High/no low. Scope is Back-end UI integration only.

## Context

Design prepared a new D&D/dark-fantasy combat HUD visual kit with alpha-ready PNG
assets and safe-zone metadata. The active HUD is created in
`scripts/ui_screens.gd` (`_create_hud`, `_create_resource_hud_panel`,
`_create_combat_timer_panel`, `_update_hud`, `_update_level_up_button`), so
runtime wiring belongs to Back-end.

Do not change gameplay values, balance, timers, XP, money, ultimate charge, level
up availability or combat logic. This is visual UI integration only.

## Design Assets

Metadata source:

- `docs/design/references/combat_hud_redraw/combat_hud_redraw_metadata.json`

Frames:

- `res://assets/sprites/ui/frames/combat_hud/ui_frame_combat_hud_resource_panel.png`
- `res://assets/sprites/ui/frames/combat_hud/ui_frame_combat_hud_card_hp.png`
- `res://assets/sprites/ui/frames/combat_hud/ui_frame_combat_hud_card_xp.png`
- `res://assets/sprites/ui/frames/combat_hud/ui_frame_combat_hud_card_gold.png`
- `res://assets/sprites/ui/frames/combat_hud/ui_frame_combat_hud_card_ult.png`
- `res://assets/sprites/ui/frames/combat_hud/ui_frame_combat_hud_timer.png`
- `res://assets/sprites/ui/frames/combat_hud/ui_frame_combat_hud_ascension_badge.png`

Level-up plus button:

- `res://assets/sprites/ui/frames/combat_hud/ui_btn_combat_level_up_plus.png`
- `res://assets/sprites/ui/frames/combat_hud/ui_btn_combat_level_up_plus_hover.png`
- `res://assets/sprites/ui/frames/combat_hud/ui_btn_combat_level_up_plus_pressed.png`
- `res://assets/sprites/ui/frames/combat_hud/ui_btn_combat_level_up_plus_disabled.png`

Bar fills and medallion:

- `res://assets/sprites/ui/hud/combat_hud/ui_hud_bar_fill_hp.png`
- `res://assets/sprites/ui/hud/combat_hud/ui_hud_bar_fill_xp.png`
- `res://assets/sprites/ui/hud/combat_hud/ui_hud_bar_fill_ult.png`
- `res://assets/sprites/ui/hud/combat_hud/ui_hud_bar_fill_gold.png`
- `res://assets/sprites/ui/hud/combat_hud/ui_hud_gold_medallion.png`

Previews / QA:

- `docs/design/previews/combat_hud_redraw_contact.png`
- `docs/design/previews/combat_hud_redraw_safe_zones.png`
- `build/qa/scrum390/combat_hud_mock_1280x720.png`
- `build/qa/scrum390/combat_hud_mock_1920x1080.png`
- `build/qa/scrum390/combat_hud_mock_2560x1440.png`

## Required Runtime Work

1. Add a combat HUD asset mapping in the UI theme layer or `ui_screens.gd`
   without replacing unrelated global menu frames.
2. Use the new resource panel and resource card assets for `RunResourceHud`,
   HP, XP, money and ultimate.
3. Use the new timer and ascension badge assets for `CombatTimerPanel` and
   `AscensionHudBadge`.
4. Use the new opaque plus button kit for `LevelUpPlusButton`, preserving the
   existing bottom-right anchor and pending-count badge.
5. Keep labels, icons, progress bars, glyphs, badge counts and click/focus zones
   inside the safe rects from `combat_hud_redraw_metadata.json`.
6. Preserve proportional scaling/no one-axis art distortion. For compact HUD
   elements, prefer StyleBoxTexture with the recorded margins; do not place text
   on red gems, dragon heads, metal claws or bevels.
7. Optional: wire bar fill textures for HP/XP/ULT if it can be done without
   changing value update semantics. Otherwise keep existing ProgressBar logic and
   use the new frames first.

## Key Margins

- Resource panel: texture margins `[96,44,96,44]`, content margins
  `[92,30,92,30]`, safe rect `[92,30,840,84]`.
- Resource cards: texture margins `[48,42,48,38]`, content margins
  `[32,24,32,22]`, safe rect `[32,24,192,98]`.
- Timer: texture margins `[92,42,92,38]`, content margins `[82,32,82,28]`,
  safe rect `[82,32,220,68]`.
- Ascension badge: content margins `[40,34,40,34]`, safe rect `[40,34,48,60]`.
- Level-up plus button: texture margins `[34,34,34,34]`, content margins
  `[36,34,36,36]`, safe rect `[36,34,56,58]`.

## Acceptance Criteria

- [x] Combat HUD uses the SCRUM-390 frame assets in live runtime.
- [x] HP, XP, money, ultimate, timer and ascension badge remain readable at
  `1280x720`, `1920x1080`, `2560x1440`.
- [x] `LevelUpPlusButton` remains bottom-right, fully opaque, with readable count
  badge and no yellow glow.
- [x] No content overlaps decorative borders/gems/dragon heads/claws.
- [x] Existing HP/XP/money/ultimate/timer update logic is unchanged.
- [x] `tests/ui_no_overlap_matrix_test.gd` passes.
- [x] `tests/runtime_smoke_ui_test.gd` passes.
- [x] `tests/runtime_smoke_test.gd` passes.
- [x] Add/update QA screenshots in `build/qa/scrum390/`.

## Result

Done 2026-06-14 (Back-end): live `scripts/ui_screens.gd` now uses the SCRUM-390
combat HUD kit for the resource panel, HP/XP/money/ULT cards, bar fills, timer,
ascension badge, gold medallion and bottom-right `LevelUpPlusButton`. Runtime
keeps existing HP/XP/money/ULT/timer update semantics; only frame/style/layout
wiring changed. The level-up return button now uses the dedicated opaque combat
plus texture states with neutral hover/focus and the existing pending-count
badge.

Layout note: source safe-zone metadata remains documented as canonical, while
runtime uses compact content margins for the 720p HUD band so labels/icons/bars
stay inside the frame center and do not cover dragon/gem/claw ornament. Artifact
row placement now drops below the lowest occupied top-HUD element when the
resource panel/timer/badge occupy the upper band.

Verification:

- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_ui_test.gd` — PASS.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/ui_no_overlap_matrix_test.gd` — PASS.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd` — PASS.
- QA dumps updated: `build/qa/scrum390/combat_hud_runtime_rects.md` and
  `build/qa/scrum390/combat_level_up_button.md`.

## QA-Вердикт (2026-06-14)
Статус: PASSED — закрывает видимый combat HUD redraw (Design 390 + Back-end 400)

Проверено (фактически):
- **Рантайм использует combat_hud kit** (ui_screens.gd:88-93): `COMBAT_HUD_FRAME_DIR`
  + resource panel + cards (hp/xp/gold/ult) + timer + badge + fills + level-up.
- **Level-up button** (QA-dump `combat_level_up_button.md`): texture =
  `ui_btn_combat_level_up_plus.png` (новый combat-HUD медальон), **alpha 1.000**
  (непрозрачный), P(1476,1476) правый-нижний угол, бейдж S(28,28) читаем.
- **Визуал** `build/qa/cap_combat_hud_400.png`: resource panel (HP/XP/gold/ult)
  top-left + timer «0:30» в драконьей рамке top-center — новый dragon-стиль,
  читаемо, не перекрывает геймплей, контент в content-зоне.
- **Тесты**: `runtime_smoke_ui_test` («Runtime UI smoke suite passed»),
  `ui_no_overlap_matrix_test`, `runtime_smoke_test` — все passed (build зелёный;
  прежний level-up assertion-конфликт реконсилен — `_button_uses_combat_hud_plus_style`).

Acceptance:
- [x] Combat HUD на SCRUM-390 ассетах в live runtime.
- [x] HP/XP/money/ult/timer/badge читаемы; level-up правый-низ, непрозрачный, бейдж, без жёлтого.
- [x] Контент не на орнаменте; логика обновления цела (runtime_smoke).
- [x] ui_no_overlap + runtime_smoke_ui + runtime smoke зелёные; QA-скрин/dump.

Петля HUD закрыта: SCRUM-390 (kit) + 400 (интеграция). Баги: нет.
