# ART/ANIM PixelLab: «Гитарист» — full redraw в размере 240-250 px

Статус: done
Приоритет: high
Роль: Design main (Codex) → Animator (Codex)
Версия: 0.1.8
Создано: 2026-06-30
Автор: PM (запрос пользователя)
Jira: SCRUM-706
Контур: Codex
Owner: Design main + Animator / Codex
Thread/Worker: codex-scrum-706-guitarist-240
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
- [x] `guitarist` полностью перерисован заново в PixelLab, без baked guitar/bass/amp/microphone/held prop.
- [x] Runtime pack has 8 idle directions and 8-direction move/walk, transparent `512x512`, alpha bbox report confirms target `240-250 px` size.
- [x] `guitarist_spriteframes.tres` and Hero Select/runtime use the new pack; old visual scale is not visible in game.
- [x] Docs, manifest, previews/contact sheet/GIFs, alpha-bbox QA report and smokes are attached.

## Work log
- 2026-06-30: claimed in Jira by `codex-scrum-706-guitarist-240` on branch
  `codex/scrum-706-guitarist-pixellab-240` in worktree
  `/Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum-706-guitarist-240`.
- 2026-06-30: rejected PixelLab source
  `f41e1d57-f720-4ae1-a739-8873d935163b`
  (`FantasyDisk SCRUM-706 Guitarist empty hands`) for production. PixelLab
  listed it as `8dir 128x128` before the job failed generation, which does not
  satisfy SCRUM-706's 240-250 px target-size contract. No runtime production
  assets or SpriteFrames will be built from this source; any queued/partial
  animations on it are rejected evidence.
- 2026-06-30: rejected PixelLab source
  `d278e753-9885-4550-82ff-81ee3bef297d`
  (`FantasyDisk SCRUM-706 Guitarist 240 empty hands`) for production. The
  completed source passed the size gate (`240x240`) but the PixelLab preview
  visibly baked a held guitar/instrument into the base body, violating the
  empty-hands/no-prop acceptance rule. No runtime production assets or
  SpriteFrames will be built from this source.
- 2026-07-01: accepted PixelLab source
  `704fd67b-da81-4804-acd2-07e75fefd9de`
  (`FantasyDisk SCRUM-706 Sonic Bard empty palms 240`) for production. The
  completed source is `248x248`; visual QA contact sheet shows open empty hands
  and no baked guitar/bass/amp/microphone/held prop. Generated 8 idle rotations
  and 8 directional `walking-6-frames` animations, then normalized runtime
  frames to transparent `512x512` canvases.

## Result
- Source pack: `assets/sprites/characters/pixellab/guitarist/` now contains 8
  idle rotations and 48 move/walk source frames from accepted PixelLab source
  `704fd67b-da81-4804-acd2-07e75fefd9de`.
- Runtime pack: `assets/sprites/characters/full_frame/guitarist_pixellab/`
  contains 8 idle frames and 48 six-frame movement frames, all transparent
  `512x512`, centered X and bottom-aligned.
- SpriteFrames:
  `assets/sprites/characters/guitarist_spriteframes.tres` exposes `idle`,
  `move`, `walk`, plus `idle_<direction>` and 6-frame `move_<direction>` /
  `walk_<direction>` rows for all eight directions.
- BBox QA:
  `docs/design/previews/scrum706_guitarist_pixellab_bbox_report.json` and
  `.md` report primary south idle visible bbox `211x245`; all idle/move frames
  have visible alpha height exactly `245 px`, satisfying the `240..250 px`
  hard contract. Width is recorded as a QA note instead of forced non-uniform
  stretching because the accepted empty-palmed humanoid silhouette is naturally
  height-dominant.
- Visual evidence:
  `docs/design/previews/scrum706_guitarist_pixellab_contact.png`,
  `scrum706_guitarist_pixellab_walk_south.gif`, and
  `scrum706_guitarist_pixellab_walk_east.gif`.
- Docs updated: `CHANGELOG.md`, `docs/design/content_registry.md`,
  `docs/design/current_game_state.md`, and
  `docs/design/systems/animation.md`.
- Tests PASS:
  `python3 tools/godot_gate.py --headless --path . --script res://tests/animation_smoke_test.gd`;
  `python3 tools/godot_gate.py --headless --path . --script res://tests/hero_select_pixellab_layout_test.gd`;
  `python3 tools/godot_gate.py --headless --path . --script res://tests/character_sprite_registry_alignment_test.gd`;
  `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_test.gd`.

## Disk cleanup
Removed task-generated `.godot/` import cache (`~1.3G`) and temporary PixelLab
download/extract files under `/tmp/fantasydisk_scrum706_guitarist_pixellab_704fd67b*`;
also removed the temporary `/tmp/fantasydisk_doctor_pixellab_download.zip` used
to inspect PixelLab package layout. Worktree retained for branch/Jira closeout;
non-task dirty files are excluded from the task commit.
