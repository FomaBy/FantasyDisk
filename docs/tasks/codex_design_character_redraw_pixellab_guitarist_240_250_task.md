# ART/ANIM PixelLab: «Гитарист» — full redraw в размере 240-250 px

Статус: done
Приоритет: high
Роль: Design main (Codex) → Animator (Codex)
Версия: 0.1.8
Создано: 2026-06-30
Автор: PM (запрос пользователя)
Jira: SCRUM-706
Контур: Codex
Owner: Codex worker / Parfit
Thread/Worker: 019f18f1-e366-7f52-bafe-e4beba095ad6
Labels: foma, p1, design-main, pixellab, character-art, redesign, animation-source
Locked paths: `assets/sprites/characters/pixellab/guitarist/`, `assets/sprites/characters/full_frame/guitarist_pixellab/`, `assets/sprites/characters/guitarist_spriteframes.tres`, `scripts/progression_data_characters.gd`, `docs/design/content_registry.md`, `docs/design/current_game_state.md`, `docs/design/systems/animation.md`, `docs/tasks/codex_design_character_redraw_pixellab_guitarist_240_250_task.md`, `CHANGELOG.md`
Связано: SCRUM-429, SCRUM-421, SCRUM-423, SCRUM-685

## Контекст
Пользователь попросил заново поставить задачи на полную переделку MVP-персонажей в том же актуальном PixelLab-пайплайне, что Биолог/Химик, но с новым размерным контрактом: персонаж должен быть в размере примерно `240-250 x 240-250 px`, как остальные новые readable персонажи, а не tiny/legacy-scale.

## Required change
Полностью перерисовать `guitarist` через PixelLab по актуальному runtime-пайплайну: source/fetch character, 8-direction idle poses, 8-direction move/walk animation, transparent normalized `512x512` runtime frames under `assets/sprites/characters/full_frame/guitarist_pixellab/`, source manifest under `assets/sprites/characters/pixellab/guitarist/`, rebuilt `guitarist_spriteframes.tres`, Hero Select/runtime integration, docs and focused smokes.

## Art direction
Гитарист — харизматичный dark-fantasy rock bard / stage controller: янтарно-золотые и магента акценты, sonic-wave silhouette, сценическая энергия without comedy. Руки пустые: электрогитара, бас-гитара and amp are separate weapon visuals and must not be baked into the base body art.

## Size contract
- Каждый runtime PNG остается `512x512`, transparent RGBA, centered X and bottom-aligned.
- Видимый alpha bbox персонажа в primary south idle должен попадать в `240..250 px` по высоте и целиться в `240..250 px` по ширине/общему footprint.
- Для остальных направлений и кадров move/walk видимая высота должна держаться в `240..250 px`; ни один кадр не должен быть меньше `230 px` или больше `260 px` по видимой высоте без явного QA-note.
- Размер проверять скриптом/PIL alpha-bbox report; визуально персонаж должен совпадать по масштабу с актуальными PixelLab-персонажами, а не со старыми 170-180 px static rotations.

## Requirements
1. Использовать `fantasydisk-asset-generator` / `fantasydisk-pixellab-animation-integrator`; non-PixelLab fallback запрещен без Jira override.
2. Сгенерировать/получить новый PixelLab character source для `guitarist`, не масштабировать старый v2/cartoon/Pixellab ассет как production source.
3. Подготовить 8 idle directions and 8-direction move/walk animation, 5+ кадров на направление.
4. Встроить новый pack в runtime/Hero Select через существующие конвенции SpriteFrames and `sprite_path`.
5. Старые live ассеты сохранить в backup outside Godot import scope, без `.import` sidecars.
6. Обновить `content_registry`, `current_game_state`, `systems/animation` and `CHANGELOG`.
7. Прогнать focused animation/registry/Hero Select checks and runtime smoke through `tools/godot_gate.py`.

## Acceptance Criteria
- [ ] `guitarist` полностью перерисован заново в PixelLab, без baked guitar/bass/amp/microphone/held prop.
- [ ] Runtime pack has 8 idle directions and 8-direction move/walk, transparent `512x512`, alpha bbox report confirms target `240-250 px` size.
- [ ] `guitarist_spriteframes.tres` and Hero Select/runtime use the new pack; old visual scale is not visible in game.
- [ ] Docs, manifest, previews/contact sheet/GIFs, alpha-bbox QA report and smokes are attached.

## Disk cleanup
Executor final report must include `Disk cleanup:` per repo policy.

## Result 2026-07-01
Готово для QA на branch `codex/scrum-706-guitarist-pixellab-240`, head commit `d07d20e905a58dea15cf8b775bcf255725a6fd8d` (`5c6bda39` implementation commit + `d07d20e9` Jira sync). Accepted PixelLab source `704fd67b-da81-4804-acd2-07e75fefd9de`; rejected sources documented: `f41e1d57-f720-4ae1-a739-8873d935163b` (128px/failed generation) and `d278e753-9885-4550-82ff-81ee3bef297d` (baked instrument). Built empty-hands Guitarist pack: 8 idle directions, 8-direction 6-frame walk/move, transparent `512x512` runtime frames, rebuilt `guitarist_spriteframes.tres`.

QA evidence: alpha bbox PASS; no baked guitar/bass/amp/microphone/held prop. PASS: `animation_smoke_test.gd`, `hero_select_pixellab_layout_test.gd`, `character_sprite_registry_alignment_test.gd`, `runtime_smoke_test.gd`.

Jira target status: `Контроль качества`. Disk cleanup: worker removed `.godot/` (~1.3 GB) and `/tmp/fantasydisk_scrum706_guitarist_pixellab_704fd67b*`; unrelated `source_docs/FantasyDisk_GDD.txt` line-ending diff and Godot-touched `assets/sprites/ui/skill_tree/*.import` were left uncommitted.
