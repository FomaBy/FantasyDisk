# Design: PixelLab Dark Mage Hero Select Asset

Статус: done
Jira: SCRUM-685
Owner: codex-design-board-watcher
Lane: Codex
Role: Design
Executor: Codex
Дата старта: 2026-06-29

## Scope

Generate and integrate a new PixelLab Dark Mage character asset for Hero Select.
Do not create movement/combat animation packs. Hero Select must rotate the mage
clockwise through eight static directions, matching the Berserk preview order.

## Locked Paths

- `assets/sprites/characters/pixellab/dark_mage/`
- `assets/sprites/characters/full_frame/dark_mage_pixellab/`
- `assets/sprites/characters/dark_mage_heroselect_spriteframes.tres`
- `scripts/ui_screens.gd`
- `scripts/progression_data_characters.gd`
- `tests/hero_select_dark_mage_pixellab_preview_test.gd`
- `docs/design/previews/dark_mage_pixellab_hero_select_contact.png`
- `docs/design/current_game_state.md`
- `docs/design/content_registry.md`

## Implementation Notes

- PixelLab character source: `59825867-7d36-44fd-8ed9-83ae2c98272f`.
- Use existing Dark Mage/FantasyDisk references and the PixelLab MCP server.
- No `animate_character` call is in scope.
- Hero Select UI preview may use `idle_<direction>` static frames as the
  clockwise preview source when move/walk directional frames are absent.

## Verification Plan

- Download and normalize PixelLab 8-direction static PNGs.
- Build a Hero Select-only SpriteFrames resource for Dark Mage.
- Add focused Godot smoke coverage for static idle-direction clockwise preview.
- Run relevant Godot smoke through `tools/godot_gate.py`.

## Result

- Added PixelLab Dark Mage source rotations under
  `assets/sprites/characters/pixellab/dark_mage/`.
- Added normalized full-frame Hero Select rotations under
  `assets/sprites/characters/full_frame/dark_mage_pixellab/`.
- Added `dark_mage_heroselect_spriteframes.tres` with only static
  `idle_<direction>` frames.
- Updated Hero Select preview logic to rotate directional idle frames clockwise
  when move/walk frames are not present.
- Updated Dark Mage static character sprite path and design docs.

## Verification

- `python3 tools/godot_gate.py --headless --path . --script res://tests/hero_select_dark_mage_pixellab_preview_test.gd` - passed.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/hero_select_berserk_preview_test.gd` - passed.
- `python3 -m json.tool assets/sprites/characters/pixellab/dark_mage/manifest.json` - passed.
- `python3 -m json.tool docs/process/jira_sync_map.json` - passed.
- `git diff --check` - passed.

## Disk Cleanup

- Removed task temp script `/private/tmp/fantasydisk_dark_mage_pixellab_build.py`.
- Removed transient `.godot/` import cache after verification.
- No disposable checkout was created.

## QA-Вердикт
Статус: PASSED

Проверено на чистом worktree от origin/dev (1ec8fd5d).
Доставка: PixelLab dark_mage ассеты (8 направлений, full_frame) + .import уже в origin/dev; SpriteFrames dark_mage_spriteframes.tres в dev; интеграция в progression_data_characters.gd + ui_screens.gd hero-select. Дивергентная ветка codex/pixellab-dark-mage-20260629 (726b1285) НЕ мержилась — её diff удаляет guitarist pixellab-ассеты (регрессия), контент dark_mage попал в dev отдельным путём.
Гейты (fdengine, после --import): hero_select_dark_mage_pixellab_preview_test PASS («Hero Select Dark Mage PixelLab preview smoke test passed.»), character_sprite_registry_alignment_test PASS (17 персонажей), animation_smoke_test PASS.
