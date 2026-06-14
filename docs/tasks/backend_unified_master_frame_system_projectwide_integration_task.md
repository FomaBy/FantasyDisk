# Back-end/UI: Integrate SCRUM-373 unified master frame system projectwide

Статус: in_progress
Приоритет: high
Роль: Back-end (UI)
Версия: 0.1.5
Создано: 2026-06-14
Автор: Design Codex handoff from SCRUM-373
Jira: SCRUM-382
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

- [ ] Generic UI panels/cards/tooltips/HUD use the SCRUM-373 unified frame
  builder and tile edges without one-axis distortion.
- [ ] Existing proportional/screen-specific frames remain proportional where
  documented and do not get forced through 9-slice.
- [ ] Old frame references are backed up or removed from live runtime mappings
  only after replacement is verified.
- [ ] `runtime_smoke_test.gd`, `ui_no_overlap_matrix_test.gd` and dark-fantasy
  UI/theme checks pass.
- [ ] QA captures cover 1280x720, 1920x1080 and 2560x1440.
- [ ] Documentation is updated after runtime integration.
