# ART/ANIM PixelLab: «Берсерк» — full redraw в размере 240-250 px

Статус: new
Приоритет: high
Роль: Design main (Codex) → Animator (Codex)
Версия: 0.1.8
Создано: 2026-06-30
Автор: PM (запрос пользователя)
Jira: SCRUM-703
Контур: Codex
Owner: unassigned
Thread/Worker: n/a
Labels: foma, p1, design-main, pixellab, character-art, redesign, animation-source
Locked paths: `assets/sprites/characters/pixellab/berserk/`, `assets/sprites/characters/full_frame/berserk_pixellab/`, `assets/sprites/characters/berserk_spriteframes.tres`, `scripts/progression_data_characters.gd`, `docs/design/content_registry.md`, `docs/design/current_game_state.md`, `docs/design/systems/animation.md`, `docs/tasks/codex_design_character_redraw_pixellab_berserk_240_250_task.md`, `CHANGELOG.md`
Связано: SCRUM-420, SCRUM-421, SCRUM-423, SCRUM-685

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
- [ ] `berserk` полностью перерисован заново в PixelLab, без baked weapon/held prop.
- [ ] Runtime pack has 8 idle directions and 8-direction move/walk, transparent `512x512`, alpha bbox report confirms target `240-250 px` size.
- [ ] `berserk_spriteframes.tres` and Hero Select/runtime use the new pack; old visual scale is not visible in game.
- [ ] Docs, manifest, previews/contact sheet/GIFs, alpha-bbox QA report and smokes are attached.

## Disk cleanup
Executor final report must include `Disk cleanup:` per repo policy.
