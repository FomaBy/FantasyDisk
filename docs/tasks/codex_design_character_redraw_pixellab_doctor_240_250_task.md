# ART/ANIM PixelLab: «Доктор» — full redraw в размере 240-250 px

Статус: done
Приоритет: high
Роль: Design main (Codex) → Animator (Codex)
Версия: 0.1.8
Создано: 2026-06-30
Автор: PM (запрос пользователя)
Jira: SCRUM-705
Контур: Codex
Owner: Codex worker / Linnaeus
Thread/Worker: 019f18f1-b0f7-7462-b4ea-14b9ec12688e
Labels: foma, p1, design-main, pixellab, character-art, redesign, animation-source
Locked paths: `assets/sprites/characters/pixellab/doctor/`, `assets/sprites/characters/full_frame/doctor_pixellab/`, `assets/sprites/characters/doctor_spriteframes.tres`, `scripts/progression_data_characters.gd`, `docs/design/content_registry.md`, `docs/design/current_game_state.md`, `docs/design/systems/animation.md`, `docs/tasks/codex_design_character_redraw_pixellab_doctor_240_250_task.md`, `CHANGELOG.md`
Связано: SCRUM-425, SCRUM-421, SCRUM-423, SCRUM-685

## Контекст
Пользователь добавил Доктора к пакету полной переделки MVP-персонажей. SCRUM-425 уже доставил прежний PixelLab pass, но новый запрос требует отдельный replacement/follow-up с тем же актуальным пайплайном, что Биолог/Химик, и новым размерным контрактом: персонаж должен быть в размере примерно `240-250 x 240-250 px`, как остальные новые readable персонажи.

## Required change
Полностью перерисовать `doctor` через PixelLab по актуальному runtime-пайплайну: source/fetch character, 8-direction idle poses, 8-direction move/walk animation, transparent normalized `512x512` runtime frames under `assets/sprites/characters/full_frame/doctor_pixellab/`, source manifest under `assets/sprites/characters/pixellab/doctor/`, rebuilt `doctor_spriteframes.tres`, Hero Select/runtime integration, docs and focused smokes.

## Art direction
Доктор — dark-fantasy plague doctor / field medic: читаемый medical silhouette, кожаная маска/капюшон/плащ, холодные teal/cream акценты, клиническая drain/healing identity. Руки пустые: potion, plague syringe and bone saw are separate weapon visuals and must not be baked into the base body art. Belt details are acceptable only if they do not read as held weapons/tools.

## Size contract
- Каждый runtime PNG остается `512x512`, transparent RGBA, centered X and bottom-aligned.
- Видимый alpha bbox персонажа в primary south idle должен попадать в `240..250 px` по высоте и целиться в `240..250 px` по ширине/общему footprint.
- Для остальных направлений и кадров move/walk видимая высота должна держаться в `240..250 px`; ни один кадр не должен быть меньше `230 px` или больше `260 px` по видимой высоте без явного QA-note.
- Размер проверять скриптом/PIL alpha-bbox report; визуально персонаж должен совпадать по масштабу с актуальными PixelLab-персонажами, а не со старыми 170-180 px static rotations.

## Requirements
1. Использовать `fantasydisk-asset-generator` / `fantasydisk-pixellab-animation-integrator`; non-PixelLab fallback запрещен без Jira override.
2. Сгенерировать/получить новый PixelLab character source для `doctor`, не масштабировать старый v2/cartoon/Pixellab ассет как production source.
3. Подготовить 8 idle directions and 8-direction move/walk animation, 5+ кадров на направление.
4. Встроить новый pack в runtime/Hero Select через существующие конвенции SpriteFrames and `sprite_path`.
5. Старые live ассеты сохранить в backup outside Godot import scope, без `.import` sidecars.
6. Обновить `content_registry`, `current_game_state`, `systems/animation` and `CHANGELOG`.
7. Прогнать focused animation/registry/Hero Select checks and runtime smoke through `tools/godot_gate.py`.

## Acceptance Criteria
- [ ] `doctor` полностью перерисован заново в PixelLab, без baked potion/syringe/saw/held prop.
- [ ] Runtime pack has 8 idle directions and 8-direction move/walk, transparent `512x512`, alpha bbox report confirms target `240-250 px` size.
- [ ] `doctor_spriteframes.tres` and Hero Select/runtime use the new pack; old visual scale is not visible in game.
- [ ] Docs, manifest, previews/contact sheet/GIFs, alpha-bbox QA report and smokes are attached.

## Disk cleanup
Executor final report must include `Disk cleanup:` per repo policy.

## Result 2026-07-01
Готово для QA на branch `codex/scrum-705-doctor-pixellab-240`, head commit `05d90150f044250983a7f5016799a7cfec588cdd` (`3fe71fd9` implementation commit). PixelLab source `3e0a2b30-308e-48a8-a5a6-bb28a5038ca9`; собран новый Doctor pack: 8 idle directions, 8-direction move/walk, 56 transparent `512x512` runtime frames, rebuilt `doctor_spriteframes.tres`.

QA evidence: alpha bbox PASS, all visible heights `244 px`, primary south idle `150x244`; no baked potion/syringe/saw/held weapon. PASS: `character_sprite_registry_alignment_test.gd`, `hero_select_pixellab_layout_test.gd`, `animation_smoke_test.gd`, `runtime_smoke_test.gd`. Runtime smoke had pre-existing `settings_v3` warnings from current dev but exited 0.

Jira target status: `Контроль качества`. Disk cleanup: worker removed `/Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum-705-doctor-240` including ~1.3 GB `.godot`, dropped SCRUM-705 temporary stashes, and ran `git worktree prune`.
