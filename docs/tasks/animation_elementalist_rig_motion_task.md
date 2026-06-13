# Animator Task: Elementalist Rig And Motion Profile

Статус: done
Версия: 0.1.4
Создано: 2026-06-13
Роль: Animator
Jira: SCRUM-163
Связь: Back-end task `backend_add_character_elementalist_task.md` / Jira SCRUM-163
Design unblock 2026-06-13: `docs/tasks/codex_design_elementalist_art_task.md`
is in review and canonical source assets are ready:

- `assets/sprites/characters/elementalist.png`
- `assets/sprites/weapons/elementalist_orb_ring.png`
- `assets/sprites/weapons/elementalist_prism_focus.png`
- `assets/sprites/weapons/elementalist_meteor_core.png`
- preview: `docs/design/previews/elementalist_art_contact.png`

Cutout parts are generated and owned by Animator scope.

Dispatcher note 2026-06-13: Design art is ready and the Animator row exists in
`docs/process/task_board.md`; task is unblocked and completed.

## Контекст

Back-end добавил нового класса `elementalist` с тремя weapon patterns:

- `elementalist_orb_ring` / `elemental_orbit`
- `elementalist_prism_focus` / `prism_rift`
- `elementalist_meteor_core` / `meteor_shards`

Back-end не выполняет cutout/rig/motion работу. Нужен Animator handoff после готовности Design-арта `assets/sprites/characters/elementalist.png`.

## Scope

- Нарезать cutout-части персонажа:
  - `assets/sprites/characters/cutout/elementalist_torso.png`
  - `assets/sprites/characters/cutout/elementalist_arm_l.png`
  - `assets/sprites/characters/cutout/elementalist_arm_r.png`
  - `assets/sprites/characters/cutout/elementalist_leg_l.png`
  - `assets/sprites/characters/cutout/elementalist_leg_r.png`
- Обновить rig manifest для `elementalist`, если pipeline требует.
- Создать персональный motion profile: легкий caster, плавный, но энергичный; не копия Dark Mage 1-в-1.
- Подготовить attack pose hooks под три механики:
  - круговой elemental channel для `elemental_orbit`;
  - фокусировка кристалла для `prism_rift`;
  - бросок/призыв метеора для `meteor_shards`.

## Границы

- Не менять Back-end баланс/логику оружия.
- Если нужны новые VFX timing hooks, оформить обратный handoff в Back-end вместо самостоятельной правки gameplay.

## Acceptance

- Animation smoke проходит без warning/error.
- Elementalist visually moves distinctly from Dark Mage and Druid.
- Weapon action poses читаемы, но тайминги остаются совместимы с Back-end cooldown/damage logic.

## Result

- 2026-06-13: Done. Generated `elementalist_*` cutout parts and refreshed `scripts/sliced_rig_manifest.gd`.
- Added a distinct light/energetic caster motion profile in `scripts/cutout_rig_2d.gd`.
- Added action pose hooks for `elementalist_orb_ring` / elemental orbit channel, `elementalist_prism_focus` / forward prism focus, and `elementalist_meteor_core` / overhead meteor summon.
- Verified `build/rig_debug/cut_elementalist.png`; reassembled panel matches source art and cloak pieces stay on the torso/base layer.
- Godot headless editor import passed; `tests/animation_smoke_test.gd` and `tests/runtime_smoke_test.gd` passed.

## Dispatch

- 2026-06-13: dispatched to Animator thread `019eb156-710c-71f0-8903-eada762dceb3` after Design art reached review and canonical Elementalist assets were present. Jira `SCRUM-163` remains shared with the Elementalist pipeline.


## QA-Вердикт (2026-06-13)
Статус: PASSED (SCRUM-163)
- Cutout-части (5) + manifest для `elementalist`; motion profile/attack pose hooks 3 оружий.
- animation_smoke + runtime_smoke зелёные на чистом HEAD (сборка рига проходит). Багов нет.
