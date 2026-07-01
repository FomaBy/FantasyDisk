# ART/ANIM PixelLab: «Берсерк» — full redraw в размере 240-250 px

Статус: done
Приоритет: high
Роль: Design main (Codex) → Animator (Codex)
Версия: 0.1.8
Создано: 2026-06-30
Автор: PM (запрос пользователя)
Jira: SCRUM-703
Контур: Codex
Owner: Codex Design main + Animator
Thread/Worker: codex-scrum-703-berserk-240
Labels: foma, p1, design-main, pixellab, character-art, redesign, animation-source
Locked paths: `assets/sprites/characters/pixellab/berserk/`, `assets/sprites/characters/full_frame/berserk_pixellab/`, `assets/sprites/characters/berserk_spriteframes.tres`, `scripts/progression_data_characters.gd`, `docs/design/content_registry.md`, `docs/design/current_game_state.md`, `docs/design/systems/animation.md`, `docs/tasks/codex_design_character_redraw_pixellab_berserk_240_250_task.md`, `CHANGELOG.md`
Связано: SCRUM-420, SCRUM-421, SCRUM-423, SCRUM-685

## Claim / Start
2026-06-30: claimed in Jira as `В работе`.
Owner: Codex Design main + Animator.
Lane: Codex.
Thread/Worker: `codex-scrum-703-berserk-240`.
Branch/worktree: `codex/scrum-703-berserk-pixellab-240` at `/Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum-703-berserk-240`.
Next verification: use PixelLab MCP only, create/fetch new unarmed Berserk 8-direction idle plus 8-direction move/walk pack, normalize `512x512`, then run alpha-bbox QA for the `240..250 px` visible-height contract before SpriteFrames integration.

## Контекст
Пользователь попросил заново поставить задачи на полную переделку MVP-персонажей в том же актуальном PixelLab-пайплайне, что Биолог/Химик, но с новым размерным контрактом: персонаж должен быть в размере примерно `240-250 x 240-250 px`, как остальные новые readable персонажи, а не tiny/legacy-scale.

## Required change
Полностью перерисовать `berserk` через PixelLab по актуальному runtime-пайплайну: source/fetch character, 8-direction idle poses, 8-direction move/walk animation, transparent normalized `512x512` runtime frames under `assets/sprites/characters/full_frame/berserk_pixellab/`, source manifest under `assets/sprites/characters/pixellab/berserk/`, rebuilt `berserk_spriteframes.tres`, Hero Select/runtime integration, docs and focused smokes.

## Art direction
Берсерк — крупный, брутальный melee-воин/драконоборец: звериная стойка, мех/кожа/металл, боевой раскрас, читаемый силуэт фронтального напора. Руки пустые: двуручный меч, топор и молот остаются отдельными weapon assets/WeaponSocket и не должны быть baked into body art.

## Size contract
- Каждый runtime PNG остается `512x512`, transparent RGBA, centered X and bottom-aligned.
- Видимый alpha bbox персонажа в primary south idle должен попадать в `240..250 px` по высоте и целиться в `240..250 px` по ширине/общему footprint.
- Для остальных направлений и кадров move/walk видимая высота должна держаться в `240..250 px`; ни один кадр не должен быть меньше `230 px` или больше `260 px` по видимой высоте без явного QA-note.
- Размер проверять скриптом/PIL alpha-bbox report; визуально персонаж должен совпадать по масштабу с актуальными PixelLab-персонажами, а не со старыми 170-180 px static rotations.

## Requirements
1. Использовать `fantasydisk-asset-generator` / `fantasydisk-pixellab-animation-integrator`; non-PixelLab fallback запрещен без Jira override.
2. Сгенерировать/получить новый PixelLab character source для `berserk`, не масштабировать старый v2/cartoon/Pixellab ассет как production source.
3. Подготовить 8 idle directions and 8-direction move/walk animation, 5+ кадров на направление.
4. Встроить новый pack в runtime/Hero Select через существующие конвенции SpriteFrames and `sprite_path`.
5. Старые live ассеты сохранить в backup outside Godot import scope, без `.import` sidecars.
6. Обновить `content_registry`, `current_game_state`, `systems/animation` and `CHANGELOG`.
7. Прогнать focused animation/registry/Hero Select checks and runtime smoke through `tools/godot_gate.py`.

## Acceptance Criteria
- [x] `berserk` полностью перерисован заново в PixelLab, без baked weapon/held prop.
- [x] Runtime pack has 8 idle directions and 8-direction move/walk, transparent `512x512`, alpha bbox report confirms target `240-250 px` size.
- [x] `berserk_spriteframes.tres` and Hero Select/runtime use the new pack; old visual scale is not visible in game.
- [x] Docs, manifest, previews/contact sheet, alpha-bbox QA report and smokes are attached.

## Result
2026-07-01: completed for QA on branch `codex/scrum-703-berserk-pixellab-240`.

- PixelLab source character: `8486ce45-f749-4c63-9a6d-f0477d619c2d`, v3, `252x252`, unarmed Berserk.
- Source frames, `manifest.json`, `pixellab_metadata.json`, and `alpha_bbox_report.json`: `assets/sprites/characters/pixellab/berserk/`.
- Runtime pack: `assets/sprites/characters/full_frame/berserk_pixellab/`, 56 transparent `512x512` frames.
- Alpha-bbox QA: all 56 runtime frames are `245 px` high; primary south idle bbox is `217x245`; no frame is below `230 px` or above `260 px`.
- Visual QA note: first PixelLab template north-west move row produced hammer-like props in frames 0..2; it was deleted in PixelLab and replaced with v3 custom empty-hands move `f82b711b-d1e1-4ffa-907c-75046dda6934`, using frames 1..6.
- Old live assets backup: `docs/design/backups/scrum703_berserk_pixellab_pre_redraw_2026-06-30/` (PNG/TRES only, no `.import` sidecars).
- Focused checks:
  - `python3 tools/godot_gate.py --headless --path . --script res://tests/animation_smoke_test.gd` — PASS
  - `python3 tools/godot_gate.py --headless --path . --script res://tests/hero_select_berserk_preview_test.gd` — PASS
  - `python3 tools/godot_gate.py --headless --path . --script res://tests/hero_select_pixellab_layout_test.gd` — PASS
  - `python3 tools/godot_gate.py --headless --path . --script res://tests/character_sprite_registry_alignment_test.gd` — PASS
  - Alpha-bbox report validator — PASS (`56` frames, height `245..245 px`)

## Disk cleanup
Removed task-generated transient cache/temp data: `.godot/`, `/tmp/scrum703_berserk_pixellab`, and Python `__pycache__` directories. Kept the task worktree for commit/push and Jira QA traceability.

## QA-Вердикт: PASSED
Статус: PASSED
Проверено claude-qa на HEAD origin/dev (арт-коммит dff43b36 = ancestor origin/dev).
- Контракт размера ВЫПОЛНЕН: berserk_pixellab idle_south alpha bbox = 217×245 px (высота 245 в диапазоне 240-250), PNG 512×512, bottom-aligned. Старый 216px пак заменён.
- `berserk_spriteframes.tres`: 56 refs на berserk_pixellab, 0 stale-ссылок на старый пак; полный 8-dir idle/move/walk. Старый масштаб в игре не виден (acceptance выполнен).
- Смоуки зелёные (godot_gate): runtime_smoke, animation_smoke, character_sprite_registry_alignment.
Блок добавлен в .md, чтобы board_sync не реверт-ил PASSED-тикет обратно в QC (см. Статус: done без QA-блока).
