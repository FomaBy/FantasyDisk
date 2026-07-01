# Animation: Guitarist replace live PixelLab pack with instrument variant

Статус: done
Приоритет: high
Роль: Animator (Codex)
Версия: 0.1.8
Создано: 2026-07-01
Автор: прямой запрос пользователя
Jira: SCRUM-797
Контур: Codex
Owner: Animator / Codex
Thread/Worker: codex-guitarist-instrument-pack
Labels: foma, p1, animator, codex, pixellab, character-animation
Locked paths: `assets/sprites/characters/pixellab/guitarist/`, `assets/sprites/characters/full_frame/guitarist_pixellab/`, `assets/sprites/characters/guitarist_spriteframes.tres`, `docs/design/content_registry.md`, `docs/design/current_game_state.md`, `docs/design/systems/animation.md`, `docs/tasks/animation_guitarist_replace_with_pixellab_instrument_pack_task.md`, `CHANGELOG.md`

## Context
The user asked to replace the current Guitarist because another animation/source looks better and cooler. Current live SCRUM-706 source is an empty-hands sonic bard pack; the better available PixelLab character is `d278e753-9885-4550-82ff-81ee3bef297d`, which visually reads as a true Guitarist with a held instrument.

This follow-up intentionally overrides the SCRUM-706 empty-hands acceptance rule for `guitarist` only. The gameplay weapon visuals remain separate, but the base character may carry a guitar because the direct user request prioritizes the stronger character silhouette.

## Required Change
- Generate or fetch 8-direction movement animation for PixelLab character `d278e753-9885-4550-82ff-81ee3bef297d`.
- Replace the live Guitarist source/runtime pack with that PixelLab source.
- Preserve the established runtime contract: transparent `512x512`, centered X, bottom-aligned, 8 idle directions, 6 movement frames per direction, `idle`, `move`, `walk`, and all directional rows.
- Update docs and task evidence with the accepted PixelLab ID and the user override rationale.

## Acceptance Criteria
- [x] `assets/sprites/characters/pixellab/guitarist/manifest.json` references `d278e753-9885-4550-82ff-81ee3bef297d`.
- [x] `assets/sprites/characters/guitarist_spriteframes.tres` uses the new runtime frames and has no stale references.
- [x] Hero Select and combat load the new Guitarist via the existing `sprite_path`.
- [x] Focused animation / Hero Select / registry smokes pass through `tools/godot_gate.py`.
- [x] Jira final comment includes tests, commit/push, PixelLab source ID, and `Disk cleanup:`.

## Work Log
- 2026-07-01: claimed by `codex-guitarist-instrument-pack`; direct user override accepts the held-instrument PixelLab variant as the new visual target.
- 2026-07-01: PixelLab template queue produced completed `walking-6-frames` rows for all 8 required directions. The package download remained locked by a duplicate pending `south` job, so source/runtime frames were downloaded from the completed `get_character` rotation/frame URLs and recorded in manifest/evidence.

## Result
- Replaced live Guitarist source pack under `assets/sprites/characters/pixellab/guitarist/` with PixelLab source `d278e753-9885-4550-82ff-81ee3bef297d`.
- Rebuilt `assets/sprites/characters/full_frame/guitarist_pixellab/` as transparent `512x512` runtime frames with every visible alpha bbox normalized to `245 px` height.
- Rebuilt `assets/sprites/characters/guitarist_spriteframes.tres` with generic `idle`/`move`/`walk`, 8 directional `idle_<direction>` rows, and 6-frame directional `move_<direction>` / `walk_<direction>` rows.
- Added evidence: `docs/design/previews/scrum797_guitarist_instrument_pack_contact.png`, `docs/design/previews/scrum797_guitarist_instrument_pack_bbox_report.json`, `docs/design/previews/scrum797_guitarist_instrument_pack_bbox_report.md`, `docs/design/previews/scrum797_guitarist_instrument_pack_walk_south.gif`, and `docs/design/previews/scrum797_guitarist_instrument_pack_walk_east.gif`.
- Backed up the previous SCRUM-706 live pack under `docs/design/backups/scrum797_guitarist_instrument_pack_pre_swap/` without `.import` sidecars.
- Docs updated: `CHANGELOG.md`, `docs/design/content_registry.md`, `docs/design/current_game_state.md`, and `docs/design/systems/animation.md`.

## Verification
- PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/hero_select_guitarist_pixellab_preview_test.gd`
- PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/character_sprite_registry_alignment_test.gd`
- PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/hero_select_pixellab_layout_test.gd`
- PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/animation_smoke_test.gd`
- PASS: `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_test.gd`

## Disk cleanup
Temporary download bytes were streamed directly into task-owned source files; no disposable worktree/clone or `/tmp` scratch output was created. Main checkout `.godot` import cache was reused for required Godot smoke tests and left in place because it is not a disposable task-owned cache.
