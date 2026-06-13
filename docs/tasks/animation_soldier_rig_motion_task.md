# Animator Task: Soldier Rig And Motion Profile

Статус: done 2026-06-13. Результат: Soldier добавлен в cutout pipeline (`tools/slice_rig_cutouts.py`), сгенерированы `assets/sprites/characters/cutout/soldier_*.png` и manifest entry `soldier`; `cutout_rig_2d.gd` получил дисциплинированный motion profile и action pose hooks для `soldier_rifle`/`suppression_burst`, `soldier_grenade`/`grenade_cook`, `soldier_bayonet`/`bayonet_brace`; `player.gd` передает `weapon_id` в rig как animation variant для всех weapon actions. `tests/animation_smoke_test.gd` проходит; runtime smoke сейчас падает на Back-end roster/signature test `_test_all_playable_classes`, не на Animator layer.
Версия: 0.1.4
Создано: 2026-06-12
Роль: Animator
Jira: SCRUM-168
Связь: Back-end task `backend_add_character_soldier_task.md` / Jira SCRUM-168

Design unblock 2026-06-13: `docs/tasks/codex_design_soldier_art_task.md` is in
review and canonical source assets are ready:

- `assets/sprites/characters/soldier.png`
- `assets/sprites/weapons/soldier_rifle.png`
- `assets/sprites/weapons/soldier_grenade.png`
- `assets/sprites/weapons/soldier_bayonet.png`
- preview: `docs/design/previews/soldier_art_contact.png`

Cutout parts are still absent and are owned by Animator scope.

## Контекст

Back-end добавляет нового класса `soldier` с тремя weapon patterns:

- `soldier_rifle` / `suppression_burst`
- `soldier_grenade` / `grenade_cook`
- `soldier_bayonet` / `bayonet_brace`

Back-end не выполняет cutout/rig/motion работу. Нужен Animator handoff после готовности Design-арта `assets/sprites/characters/soldier.png`.

## Scope

- Нарезать cutout-части персонажа:
  - `assets/sprites/characters/cutout/soldier_torso.png`
  - `assets/sprites/characters/cutout/soldier_arm_l.png`
  - `assets/sprites/characters/cutout/soldier_arm_r.png`
  - `assets/sprites/characters/cutout/soldier_leg_l.png`
  - `assets/sprites/characters/cutout/soldier_leg_r.png`
- Обновить rig manifest для `soldier`, если pipeline требует.
- Создать персональный motion profile: дисциплинированный, средний вес, строевой шаг, не копия Берсерка/Рыцаря.
- Подготовить attack pose hooks под три механики:
  - короткая отдача/залп для `suppression_burst`;
  - бросок/замах для `grenade_cook`;
  - defensive brace для `bayonet_brace`.

## Границы

- Не менять Back-end баланс/логики оружия.
- Если нужны новые VFX timing hooks, оформить обратный handoff в Back-end вместо самостоятельной правки gameplay.

## Acceptance

- Animation smoke проходит без warning/error.
- Soldier visually moves distinctly from current warrior classes.
- Weapon action poses читаемы, но тайминги остаются совместимы с Back-end cooldown/damage logic.

## Dispatch

- 2026-06-12: Codex Documentation dispatcher отправил задачу в Animator thread `019eb156-710c-71f0-8903-eada762dceb3`; Jira `SCRUM-168` остается `В работе`, пока Soldier pipeline не пройдет animation/QA.


## QA-Вердикт (2026-06-13)
Статус: PASSED (SCRUM-168)
- Cutout-части (5) + manifest для `soldier`; motion profile/attack pose hooks 3 оружий.
- animation_smoke + runtime_smoke зелёные на чистом HEAD (сборка рига проходит). Багов нет.
