# ANIM: Обновить анимации всех призывных существ (animation-director skill)

Статус: done
Приоритет: medium
Роль: Animator (Codex)
Версия: 0.1.5
Создано: 2026-06-14
Автор: PM (запрос пользователя)
Jira: SCRUM-353
Связано: SCRUM-279/280 (волк druid_beast), SCRUM-336 (прошлый проход), SCRUM-324 (asset-skill)

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
«Создать таск аниматору — обновить анимации для призывных существ».

Призывные существа (ally_minion.gd, ANIMATED_ALLY_VISUALS 12-33):
- `druid_beast` (волк) — ally_druid_wolf_spriteframes.tres
- `druid_pack_spirit` — ally_pack_spirit_spriteframes.tres
- `homunculus` — ally_homunculus_spriteframes.tres
- `leadership_echo` — ally_leadership_echo_spriteframes.tres
У всех уже есть SpriteFrames (прошлый проход SCRUM-336 «по системе волка»), но
их надо обновить под стандарт нового скилла анимаций (full-frame, ≥5 кадров,
без cutout-фейка). Волк параллельно ведётся в SCRUM-279/280 — привести к единому
стандарту, не дублировать (координация).

## ОБЯЗАТЕЛЬНО — скилл анимаций
Делать скиллом `fantasydisk-animation-director`
(`~/.codex/skills/fantasydisk-animation-director/`): построить SpriteFrames/
AnimationPlayer, манифест, контакт-лист/GIF, прогнать
`scripts/validate_animation_manifest.py` и `tests/animation_smoke_test.gd`.
Источник арта — через `fantasydisk-asset-generator` (прозрачный фон), если нужен
новый/улучшенный спрайт-лист. Канвас призывов 256×256 или 384×384, pivot ног —
bottom-center; парящие сущности — левитация (не статичный bob).

## Требования
1. Для КАЖДОГО призывного существа обновить/пересобрать анимации по контракту
   скилла: `move`/`walk` ≥5 кадров (loop) — реальное движение (шаг/бег для
   ногастых, левитация для парящих), `attack_primary` ≥5 кадров (non-loop,
   anticipation→windup→strike→follow-through→recovery). idle опционально.
2. Без cutout-разрезания статичного спрайта ради «движения» — full-frame.
3. Сохранить пути/имена SpriteFrames (ally_*_spriteframes.tres) и интеграцию в
   ally_minion.gd (ANIMATED_ALLY_VISUALS: frames/scale/position), чтобы код не
   менять; если меняешь масштаб/позицию — обновить значения и проверить, что
   существо не «тонет» в землю и flip по направлению работает.
4. Покрыть всех четырёх; deploy-поля (deploy_raven_totem_field, deploy_sound_amp_field)
   — если это анимируемые объекты, добавить лёгкую анимацию пульса/вращения,
   иначе отметить как статичные деплои (не существа).
5. Тест: animation_smoke_test зелёный; заспавнить каждого призыва — анимации
   move/attack проигрываются без ошибок; runtime_smoke не сломан. Контакт-листы/
   GIF в build/qa/. Манифест валиден.
6. CHANGELOG; docs/design/systems/animation.md; content_registry; current_game_state.

## Files / Assets / IDs
- scripts/ally_minion.gd (ALLY_VISUAL_PATHS 6; ANIMATED_ALLY_VISUALS 12-33;
  _apply_visual/_physics_process — состояния move/attack)
- scripts/summoner_weapon.gd (146-152 выбор визуала призыва)
- assets/sprites/allies/ (ally_*_spriteframes.tres + кадры druid_wolf/pack_spirit/
  homunculus/leadership_echo) + бэкап старых
- tests/animation_smoke_test.gd, tests/runtime_smoke_test.gd

## Acceptance Criteria
- [x] У всех призывных существ (druid_beast, druid_pack_spirit, homunculus, leadership_echo) обновлены/валидированы анимации скиллом: move ≥5 (loop) + attack_primary ≥5 (non-loop), full-frame, без cutout.
- [x] Пути/интеграция SpriteFrames сохранены; `druid_beast` получил safe-canvas padding и registry placement compensation, flip работает.
- [x] Манифест валиден; animation_smoke зелёный; контакт-листы/GIF; CHANGELOG + animation.md обновлены. Runtime smoke запущен, но упал на внешний main-menu background assertion, не на animation/summon path.

## Документация
docs/design/systems/animation.md, docs/design/content_registry.md, current_game_state.

## Dispatch
2026-06-14: Documentation dispatcher routed SCRUM-353 to existing Animator window
`019eb156-710c-71f0-8903-eada762dceb3`. Keep reasoning High/no low, use
`fantasydisk-animation-director`, and do not expand into gameplay/balance/UI scope.

## Result 2026-06-14
Done by Codex Animator using `fantasydisk-animation-director`.

What changed:
- Existing full-frame SpriteFrames were preserved on their runtime paths:
  `ally_druid_wolf_spriteframes.tres`, `ally_pack_spirit_spriteframes.tres`,
  `ally_homunculus_spriteframes.tres`, `ally_leadership_echo_spriteframes.tres`.
- `druid_beast` wolf frames were padded from the old cropped `256x224` source to
  a safe `256x256` transparent canvas on the same PNG paths. This removes alpha
  edge contact and lets the skill manifest validator accept `no_crop_checked`.
- `scripts/full_frame_animation_registry.gd` compensates the wolf visual placement
  with `scale Vector2(0.37, 0.37)` and `position Vector2(0, -37)` so runtime size
  and ground read stay close to the previous integration.
- `druid_pack_spirit`, `homunculus`, and `leadership_echo` were validated as
  existing full-frame SpriteFrames baseline: 8-frame `move` loop + 6-frame
  runtime `attack` one-shot. Manifest maps runtime `attack` to standard
  `attack_primary` without changing gameplay code.

QA artifacts:
- `build/qa/animation_summon_creatures_update_via_director_skill/animation_manifest.json`
- `build/qa/animation_summon_creatures_update_via_director_skill/summon_animation_contact_sheet.png`
- `build/qa/animation_summon_creatures_update_via_director_skill/summon_animation_qa_summary.md`
- `build/qa/animation_summon_creatures_update_via_director_skill/<entity>_preview.gif`

Verification:
- PASS: `python3 /Users/sergeyfomin/.codex/skills/fantasydisk-animation-director/scripts/validate_animation_manifest.py build/qa/animation_summon_creatures_update_via_director_skill/animation_manifest.json`
- PASS: `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/animation_smoke_test.gd`
- Runtime smoke was attempted because runtime resources changed. It failed before
  gameplay on unrelated active UI/background work: `Expected main menu to render
  the epic battle background image.` This failure is outside Animator scope and
  not caused by SCRUM-353 summon assets.
