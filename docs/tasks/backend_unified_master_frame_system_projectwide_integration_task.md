# Back-end/UI: Integrate SCRUM-373 unified master frame system projectwide

Статус: done
Приоритет: high
Роль: Back-end (UI)
Версия: 0.1.5
Создано: 2026-06-14
Автор: Design Codex handoff from SCRUM-373
Jira: SCRUM-382
QA: in_progress (2026-06-14)
Связано: SCRUM-373, SCRUM-273, SCRUM-274, SCRUM-281, SCRUM-356

## Контекст

Design SCRUM-373 prepared the projectwide unified master UI frame kit. Runtime
integration is Back-end scope because it requires centralizing style builders,
theme paths, screen mappings and regression tests.

Do not stretch decorative frame art on one axis. Use Godot 9-slice tiling for
generic panels/cards/tooltips/HUD, and keep screen-specific whole-image frames
only where documented safe zones require proportional rendering.

## Assets

Runtime assets:

- `assets/sprites/ui/frames/unified/ui_frame_unified_master.png`
- `assets/sprites/ui/frames/unified/ui_frame_unified_master_fill.png`
- `assets/sprites/ui/frames/unified/ui_frame_unified_inner_fill.png`
- `assets/sprites/ui/frames/unified/ui_frame_unified_ornament_top.png`
- `assets/sprites/ui/frames/unified/ui_frame_unified_ornament_bottom.png`
- `assets/sprites/ui/frames/unified/ui_frame_unified_hover_overlay.png`

Reference and metadata:

- `docs/design/references/unified_master_frame/ui_frame_unified_master_reference.png`
- `docs/design/references/unified_master_frame/ui_frame_unified_master_reference_alpha_clean.png`
- `docs/design/references/unified_master_frame/unified_master_frame_metadata.json`

Previews:

- `docs/design/previews/unified_master_frame_9slice_contact.png`
- `docs/design/previews/unified_master_frame_safe_zone.png`

## Runtime Spec

Source size: `1024x1024`.

StyleBoxTexture margins:

- texture margins: left/top/right/bottom `128`
- content margins: left/top/right/bottom `132`
- strict safe rect: `Rect2(132, 132, 760, 760)`
- `axis_stretch_horizontal = AXIS_STRETCH_MODE_TILE`
- `axis_stretch_vertical = AXIS_STRETCH_MODE_TILE`

Usage:

- Use `ui_frame_unified_master.png` as the default border texture.
- Use `ui_frame_unified_inner_fill.png` as an optional separate center fill for
  panels that need a dark content field.
- Use `ui_frame_unified_master_fill.png` only for rectangular full-panel
  surfaces where an opaque full texture is acceptable.
- Use top/bottom ornament overlays only on large windows or menu panels. Do not
  use them on compact HUD cards, tooltips, stat chips or small buttons.
- Prefer hover/focus via runtime modulate/contrast on the base frame. The
  overlay texture is only an optional fallback.

## Required Back-end Work

1. Add a single master frame source of truth in `scripts/ui/ui_theme_paths.gd`.
2. Add one shared builder, for example `_unified_frame_style(opts)`, supporting:
   center fill on/off, content margins, texture margins, optional ornaments,
   hover/focus tint and role tint.
3. Replace the scattered global panel/card/tooltip/HUD frame references and
   helper styles with the unified builder where safe.
4. Preserve screen-specific proportional frames where needed:
   - Hero Select SCRUM-356 unified portrait/description frame;
   - Hero Select radar/carousel frames with authored source safe zones;
   - Settings tab switcher strip.
5. Back up superseded live frame families before removing runtime references.
6. Keep all runtime text, icons, portraits, buttons, cards, meters and hit zones
   inside the documented content/safe area. No content may sit on decorative
   borders, corners, metal, crests, gems or ornaments.

## Acceptance Criteria

- [x] Generic UI panels/cards/tooltips/HUD use the SCRUM-373 unified frame
  builder and tile edges without one-axis distortion.
- [x] Existing proportional/screen-specific frames remain proportional where
  documented and do not get forced through 9-slice.
- [x] Old frame references are backed up or removed from live runtime mappings
  only after replacement is verified.
- [x] `runtime_smoke_test.gd`, `ui_no_overlap_matrix_test.gd` and dark-fantasy
  UI/theme checks pass.
- [x] QA captures cover 1280x720, 1920x1080 and 2560x1440.
- [x] Documentation is updated after runtime integration.

## Result
Done 2026-06-14.

- Added unified master frame source-of-truth constants to
  `scripts/ui/ui_theme_paths.gd`, including runtime paths, texture margins and
  role-specific compact content margins.
- Added `_unified_frame_style()` in `scripts/ui_screens.gd`; generic
  panels/cards/tooltips/timers/HUD now use tiled `StyleBoxTexture` edges from
  the SCRUM-373 unified kit. Filled generic surfaces use
  `ui_frame_unified_master_fill.png` for readability; border-only
  `ui_frame_unified_master.png` remains available through the same builder.
- Preserved proportional/screen-specific surfaces: Hero Select unified
  portrait/description frame, Hero Select radar/carousel/portrait/dossier
  frames, Settings tab switcher strip and Red & Gold button kit are not routed
  through generic 9-slice.
- Updated `tests/dark_fantasy_ui_theme_test.gd` to assert unified frame resource
  paths, 128px 9-slice margins and tiled horizontal/vertical axes.
- QA artifact: `build/qa/scrum382/unified_master_runtime_qa.md`.
- Documentation updated: `CHANGELOG.md`, `docs/design/current_game_state.md`,
  `docs/design/systems/menus_ui.md`, `docs/design/systems/visual_style_assets.md`.

Verification:
- `git diff --check` — PASS
- `Godot --headless --script res://tests/dark_fantasy_ui_theme_test.gd` — PASS
- `Godot --headless --script res://tests/runtime_smoke_ui_test.gd` — PASS
- `Godot --headless --script res://tests/ui_no_overlap_matrix_test.gd` — PASS
- `Godot --headless --script res://tests/runtime_smoke_test.gd` — PASS

## QA-Вердикт (2026-06-14)
Статус: PASSED — закрывает петлю единого мастер-фрейма (SCRUM-373 дизайн + 382 интеграция)

Проверено (фактически):
- **Source-of-truth** (`ui/ui_theme_paths.gd:7-11`): `UNIFIED_FRAME_DIR` +
  `UNIFIED_MASTER_FRAME_PATH`/fill/inner_fill/ornament — единые константы.
- **Билдер** `_unified_frame_style(frame_type, tint, center_fill)` (ui_screens.gd:5510)
  с `axis_stretch_horizontal/vertical = AXIS_STRETCH_MODE_TILE` (5500-5501) — края
  тайлятся, НЕ one-axis stretch; texture margins 128.
- **Generic-панели → unified** (dark_fantasy_ui_theme_test:27-31 ассертит): `_panel_style`,
  `_level_up_panel_style`, `_character_card_style`, `_hud_panel_style`, `_hud_card_style`
  — все routed через unified builder. Визуал `cap_skilltree_unified_382.png`:
  панели Древа умений в едином орнаментальном фрейме, тайл без искажений, текст читаем.
- **Screen-specific СОХРАНЕНЫ** (не прогнаны через generic 9-slice): визуал
  `cap_heroselect_unified_382.png` идентичен SCRUM-361 — proportional unified
  portrait/description панель + радар/карусель отдельно; settings switcher + Red&Gold
  кнопки не тронуты.
- **Тесты**: `dark_fantasy_ui_theme_test` (unified paths + 128 margins + tile),
  `runtime_smoke_test`, `runtime_smoke_ui_test`, `ui_no_overlap_matrix_test`
  (1280/1920/2560) — все passed. QA-артефакт `build/qa/scrum382/unified_master_runtime_qa.md`.

Acceptance:
- [x] Generic panels/cards/tooltips/HUD используют unified builder + тайл без one-axis distortion.
- [x] Proportional/screen-specific фреймы остаются proportional (hero-select preserved).
- [x] Старые frame-ссылки централизованы/в бэкап после проверенной замены.
- [x] runtime + no-overlap + dark-fantasy зелёные; QA captures 3 разрешения; доки.

Баги: нет. **Веха**: единый мастер-фрейм спроектирован (373) и внедрён по проекту (382) —
generic UI унифицирован, screen-specific сохранены, без наложений.
