# ART/ANIM PixelLab: «Темный маг» — full redraw в размере 240-250 px

Статус: done
Приоритет: high
Роль: Design main (Codex) → Animator (Codex)
Версия: 0.2.0
Создано: 2026-06-30
Автор: PM (запрос пользователя)
Jira: SCRUM-704
Контур: Codex
Owner: Codex Design+Animator
Thread/Worker: codex-scrum-704-dark-mage-240
Branch: codex/scrum-704-dark-mage-pixellab-240
Worktree: `/Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum-704-dark-mage-240`
Labels: foma, p1, design-main, pixellab, character-art, redesign, animation-source
Locked paths: `assets/sprites/characters/pixellab/dark_mage/`, `assets/sprites/characters/full_frame/dark_mage_pixellab/`, `assets/sprites/characters/dark_mage_spriteframes.tres`, `scripts/progression_data_characters.gd`, `scripts/player.gd`, `tests/animation_smoke_test.gd`, `tests/hero_select_dark_mage_pixellab_preview_test.gd`, `tests/dark_mage_pixellab_pack_test.gd`, `docs/design/content_registry.md`, `docs/design/current_game_state.md`, `docs/design/systems/animation.md`, `docs/tasks/codex_design_character_redraw_pixellab_dark_mage_240_250_task.md`, `CHANGELOG.md`
Связано: SCRUM-424, SCRUM-421, SCRUM-423, SCRUM-685

## Контекст
Пользователь попросил заново поставить задачи на полную переделку MVP-персонажей в том же актуальном PixelLab-пайплайне, что Биолог/Химик, но с новым размерным контрактом: персонаж должен быть в размере примерно `240-250 x 240-250 px`, как остальные новые readable персонажи, а не tiny/legacy-scale.

## Required change
Полностью перерисовать `dark_mage` через PixelLab по актуальному runtime-пайплайну: source/fetch character, 8-direction idle poses, 8-direction move/walk animation, transparent normalized `512x512` runtime frames under `assets/sprites/characters/full_frame/dark_mage_pixellab/`, source manifest under `assets/sprites/characters/pixellab/dark_mage/`, rebuilt `dark_mage_spriteframes.tres`, Hero Select/runtime integration, docs and focused smokes.

## Art direction
Темный маг — выразительный dark fantasy void caster: фиолетово-пурпурные руны, темная мантия, контролируемая магическая аура, читаемый силуэт колдуна. Руки пустые: книга, проклятый череп и жезл остаются отдельными weapon assets and must not be baked into the body art.

## Size contract
- Каждый runtime PNG остается `512x512`, transparent RGBA, centered X and bottom-aligned.
- Видимый alpha bbox персонажа в primary south idle должен попадать в `240..250 px` по высоте и целиться в `240..250 px` по ширине/общему footprint.
- Для остальных направлений и кадров move/walk видимая высота должна держаться в `240..250 px`; ни один кадр не должен быть меньше `230 px` или больше `260 px` по видимой высоте без явного QA-note.
- Размер проверять скриптом/PIL alpha-bbox report; визуально персонаж должен совпадать по масштабу с актуальными PixelLab-персонажами, а не со старыми 170-180 px static rotations.

## Requirements
1. Использовать `fantasydisk-asset-generator` / `fantasydisk-pixellab-animation-integrator`; non-PixelLab fallback запрещен без Jira override.
2. Сгенерировать/получить новый PixelLab character source для `dark_mage`, не масштабировать старый v2/cartoon/Pixellab ассет как production source.
3. Подготовить 8 idle directions and 8-direction move/walk animation, 5+ кадров на направление.
4. Встроить новый pack в runtime/Hero Select через существующие конвенции SpriteFrames and `sprite_path`.
5. Старые live ассеты сохранить в backup outside Godot import scope, без `.import` sidecars.
6. Обновить `content_registry`, `current_game_state`, `systems/animation` and `CHANGELOG`.
7. Прогнать focused animation/registry/Hero Select checks and runtime smoke through `tools/godot_gate.py`.

## Acceptance Criteria
- [ ] `dark_mage` полностью перерисован заново в PixelLab, без baked book/skull/wand/staff/orb/held prop.
- [ ] Runtime pack has 8 idle directions and 8-direction move/walk, transparent `512x512`, alpha bbox report confirms target `240-250 px` size.
- [ ] `dark_mage_spriteframes.tres` and Hero Select/runtime use the new pack; old visual scale is not visible in game.
- [ ] Docs, manifest, previews/contact sheet/GIFs, alpha-bbox QA report and smokes are attached.

## Disk cleanup
Executor final report must include `Disk cleanup:` per repo policy.

## Result — Codex Design+Animator (2026-07-01)

Done.

- PixelLab-only source: generated new v3 character
  `9bb0eca8-5afe-49d4-8e56-7115a45efdcc`
  (`FantasyDisk SCRUM-704 Dark Mage 240 empty hands`) and queued
  `walking-6-frames` for all 8 directions. No OpenAI/image_gen/manual fallback
  used.
- Source package: `assets/sprites/characters/pixellab/dark_mage/` now contains
  8 idle rotations, 48 PixelLab move frames, `.import` sidecars and
  `manifest.json`.
- Runtime package: `assets/sprites/characters/full_frame/dark_mage_pixellab/`
  now contains normalized transparent `512x512` runtime frames. Bbox-fit from
  the new PixelLab source targets 246px visible height, centered X,
  bottom-aligned.
- SpriteFrames/runtime: rebuilt `assets/sprites/characters/dark_mage_spriteframes.tres`
  with `idle`, `move`, `walk`, `idle_<direction>`, `move_<direction>`,
  `walk_<direction>`; move/walk are 6f loops for all 8 directions. `Player`
  no longer gives Dark Mage the historical skeleton-rig priority, so combat
  uses the new full-frame PixelLab pack.
- Size QA: `build/qa/scrum704_dark_mage_pixellab/alpha_bbox_report.json`
  reports runtime visible heights `245..247 px`; primary south idle is
  `230x246 px`; all runtime images are `512x512`.
- Visual QA: `docs/design/previews/scrum704_dark_mage_pixellab_contact.png` and
  `docs/design/previews/scrum704_dark_mage_pixellab_south_walk.gif`. Contact
  sheet review: empty hands with purple casting glow; no baked
  book/skull/wand/staff/orb/held prop.
- Backup: previous static PixelLab Dark Mage pack copied without `.import`
  sidecars to `docs/design/backups/scrum704_dark_mage_pixellab_pre_redraw/`.
- Docs updated: `CHANGELOG.md`, `docs/design/content_registry.md`,
  `docs/design/current_game_state.md`, `docs/design/systems/animation.md`.

Tests:
- `python3 tools/godot_gate.py --headless --path . --script res://tests/dark_mage_pixellab_pack_test.gd` — PASS.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/hero_select_dark_mage_pixellab_preview_test.gd` — PASS.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/hero_select_pixellab_layout_test.gd` — PASS.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/character_sprite_registry_alignment_test.gd` — PASS.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/animation_smoke_test.gd` — PASS.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_test.gd` — PASS.

Disk cleanup: removed `.godot/` import cache (~1.3 GB) and
`build/tmp_scrum704_pixellab_download/`; kept committed QA evidence under
`build/qa/scrum704_dark_mage_pixellab/`. Worktree kept for pushed branch/QA.

## QA-Вердикт: PASSED
Статус: PASSED
Проверено claude-qa на HEAD origin/dev (арт-коммит 6fa2b5c8 = ancestor origin/dev).
- Контракт размера ВЫПОЛНЕН: dark_mage_pixellab idle_south alpha bbox = 230×246 px (высота 246 ∈ 240-250), PNG 512×512, bottom-aligned. Старый legacy 174px пак заменён.
- `dark_mage_spriteframes.tres`: 56 refs на dark_mage_pixellab, 0 stale. Старый масштаб в игре не виден (acceptance выполнен).
- runtime_smoke_test: PASS (exit 0, 12641 файлов, duplicate-guard OK) — dark_mage refs резолвятся после локального Godot --import (PNG+.import committed на origin/dev).
Блок добавлен в .md, чтобы board_sync не реверт-ил PASSED-тикет обратно в QC.
