# Animator Task: Thief Rig And Motion Profile

Статус: done
Версия: 0.1.4
Создано: 2026-06-12
Роль: Animator
Jira: SCRUM-169
Связь: Back-end task `backend_add_character_thief_task.md` / Jira SCRUM-169
Design unblock 2026-06-13: `docs/tasks/codex_design_thief_art_task.md` is in
review and canonical source assets are ready:

- `assets/sprites/characters/thief.png`
- `assets/sprites/weapons/thief_coin_pouch.png`
- `assets/sprites/weapons/thief_shadow_cloak.png`
- `assets/sprites/weapons/thief_smoke_bomb.png`
- preview: `docs/design/previews/thief_art_contact.png`

Cutout parts are generated and owned by Animator scope.

## Контекст

Back-end добавил нового класса `thief` с тремя weapon patterns:

- `thief_coin_pouch` / `coin_ricochet`
- `thief_shadow_cloak` / `shadow_backstab`
- `thief_smoke_bomb` / `smoke_bomb`

Back-end не выполняет cutout/rig/motion работу. Нужен Animator handoff после готовности Design-арта `assets/sprites/characters/thief.png`.

## Scope

- Нарезать cutout-части персонажа:
  - `assets/sprites/characters/cutout/thief_torso.png`
  - `assets/sprites/characters/cutout/thief_arm_l.png`
  - `assets/sprites/characters/cutout/thief_arm_r.png`
  - `assets/sprites/characters/cutout/thief_leg_l.png`
  - `assets/sprites/characters/cutout/thief_leg_r.png`
- Обновить rig manifest для `thief`, если pipeline требует.
- Создать персональный motion profile: легкий, быстрый, осторожный, не копия Ассасина 1-в-1.
- Подготовить attack pose hooks под три механики:
  - бросок/щелчок монетой для `coin_ricochet`;
  - резкий заход за спину для `shadow_backstab`;
  - бросок дымовой бомбы/уклонение для `smoke_bomb`.

## Границы

- Не менять Back-end баланс/логику оружия.
- Если нужны новые VFX timing hooks, оформить обратный handoff в Back-end вместо самостоятельной правки gameplay.

## Acceptance

- Animation smoke проходит без warning/error.
- Thief visually moves distinctly from Assassin and Ranger.
- Weapon action poses читаемы, но тайминги остаются совместимы с Back-end cooldown/damage logic.

## Dispatch

- 2026-06-12: Codex Documentation dispatcher отправил задачу в Animator thread `019eb156-710c-71f0-8903-eada762dceb3`; Jira `SCRUM-169` остается `В работе`, пока Thief pipeline не пройдет animation/QA.

## Result

- 2026-06-13: Done. Generated `thief_*` cutout parts and refreshed `scripts/sliced_rig_manifest.gd`.
- Added a distinct light/cautious Thief motion profile in `scripts/cutout_rig_2d.gd`.
- Added action pose hooks for `thief_coin_pouch` / coin flick, `thief_shadow_cloak` / backstab lunge, and `thief_smoke_bomb` / low throw with dodge-back.
- Verified `build/rig_debug/cut_thief.png`; reassembled panel matches source art.
- Godot headless editor import passed. Thief pose assertions passed during implementation; current full animation/runtime smoke is blocked by unrelated Back-end parse errors in `scripts/class_weapon.gd` sniper methods (`shot_finish`, `targets`, `end_point`). Handoff created: `docs/tasks/backend_runtime_smoke_class_weapon_type_inference_task.md`.


## QA-Вердикт (2026-06-13)
Статус: PASSED (SCRUM-169)
- Cutout-части (5) + manifest для `thief`; motion profile/attack pose hooks 3 оружий.
- animation_smoke + runtime_smoke зелёные на чистом HEAD (сборка рига проходит). Багов нет.
