# ART/ANIM PixelLab: «Рейнджер» (ranger) — final 8-direction runtime redraw

Статус: done
Приоритет: medium
Роль: Design main (Codex) -> Animator/Back-end integration
Версия: 0.2.0
Создано: 2026-07-01
Jira: SCRUM-804
Контур: Codex
Owner: Codex Design/Animator
Thread/Worker: codex-design-scrum804-ranger-pixellab-20260701
Locked paths: `assets/sprites/characters/pixellab/ranger/`, `assets/sprites/characters/full_frame/ranger_pixellab/`, `assets/sprites/characters/ranger_spriteframes.tres`, `scripts/progression_data_characters.gd`, character docs/tests.
Branch/worktree: `codex/scrum-804-ranger-pixellab-final` at `/Users/sergeyfomin/.codex/worktrees/cd13/AI Agent`

## Context / Problem

`ranger` still uses legacy non-PixelLab runtime art in active `dev`. No dedicated
PixelLab-final ranger ticket existed before this issue; older broad art tasks are
historical and not live PixelLab runtime.

## Required Change

Create/reuse a PixelLab MCP character from current references, then integrate a
transparent 8-direction idle + 6-frame move/walk runtime pack. The base body must
stay empty-handed: no baked bow, crossbow, trap, projectile, or UI frame.

References: `docs/design/references/characters/ranger/ranger_sheet_source.png`,
`assets/sprites/characters/ranger.png`, `assets/sprites/characters/full_frame/ranger/`.

## Acceptance Criteria

- PixelLab source and `manifest.json` are stored under `assets/sprites/characters/pixellab/ranger/`.
- Runtime transparent 512x512 PNGs are stored under `assets/sprites/characters/full_frame/ranger_pixellab/`.
- `assets/sprites/characters/ranger_spriteframes.tres` exposes generic and 8-direction `idle`/`move`/`walk` rows.
- `scripts/progression_data_characters.gd` points `ranger.sprite_path` to `res://assets/sprites/characters/full_frame/ranger_pixellab/ranger_idle_south.png`.
- Hero Select preview rotates with live directional frames.
- Docs and focused animation/Hero Select smokes are updated/run; Jira result records the PixelLab source id.

## Result / Evidence

Completed implementation on 2026-07-01 and ready for QA (`Контроль качества`).

- PixelLab character: `1646d83c-f570-4bdd-9065-cb1b46bf13f7` (`FantasyDisk Ranger SCRUM-804 empty hands`).
- Source pack: `assets/sprites/characters/pixellab/ranger/` with 8 idle directions, 8 x 6 move frames, `manifest.json`, and `pixellab_metadata.json`.
- Runtime pack: `assets/sprites/characters/full_frame/ranger_pixellab/` with transparent 512x512 frames normalized to 245 px visible height.
- SpriteFrames: `assets/sprites/characters/ranger_spriteframes.tres` now exposes generic `idle`/`move`/`walk` plus 8-direction `idle_*`, `move_*`, and `walk_*`; no baked `attack` or `attack_primary` rows.
- Live pointer: `scripts/progression_data_characters.gd` now uses `res://assets/sprites/characters/full_frame/ranger_pixellab/ranger_idle_south.png` for `ranger.sprite_path`.
- Evidence files: `docs/design/previews/scrum804_ranger_pixellab_contact.png` and `docs/design/previews/scrum804_ranger_pixellab_bbox_report.json`.

Validation:

- Static asset contract: PASS (`56` runtime frames, every runtime alpha bbox `245` px high on transparent 512x512 canvases).
- `FSD_GODOT_SLOTS=6 python3 tools/godot_gate.py --headless --path . --script res://tests/ranger_pixellab_pack_test.gd`: PASS.
- `FSD_GODOT_SLOTS=6 python3 tools/godot_gate.py --headless --path . --script res://tests/hero_select_ranger_pixellab_preview_test.gd`: PASS.
- `FSD_GODOT_SLOTS=6 python3 tools/godot_gate.py --headless --path . --script res://tests/character_sprite_registry_alignment_test.gd`: PASS.
- `FSD_GODOT_SLOTS=6 python3 tools/godot_gate.py --headless --path . --script res://tests/hero_select_pixellab_layout_test.gd`: PASS.
- `FSD_GODOT_SLOTS=6 python3 tools/godot_gate.py --headless --path . --script res://tests/animation_smoke_test.gd`: PASS.

Disk cleanup: removed `.godot/`, `build/tmp/scrum804_pixellab_download/`, generated `.import` files, generated `.uid` files, and local `__pycache__` directories.
