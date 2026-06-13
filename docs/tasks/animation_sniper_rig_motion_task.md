# Animator Task: Sniper Cutout Rig And Motion

Статус: done
Версия: 0.1.4
Создано: 2026-06-13
Роль: Animator
Jira: SCRUM-167
Источник: `docs/tasks/backend_add_character_sniper_task.md`
Design unblock 2026-06-13: `docs/tasks/codex_design_sniper_art_task.md`
is in review and canonical source assets are ready:

- `assets/sprites/characters/sniper.png`
- `assets/sprites/weapons/sniper_deadeye_rifle.png`
- `assets/sprites/weapons/sniper_spotter_scope.png`
- `assets/sprites/weapons/sniper_shatter_rounds.png`
- preview: `docs/design/previews/sniper_art_contact.png`

Cutout parts are generated and owned by Animator scope.

## Context

Back-end добавил playable class `sniper` с тремя weapon modes:

- `sniper_lockshot` / `sniper_deadeye_rifle`
- `sniper_kill_zone` / `sniper_spotter_scope`
- `sniper_split_round` / `sniper_shatter_rounds`

Сейчас Sniper использует fallback Ranger full-art и работает без отдельного rig. После готовности canonical Sniper PNG нужно подключить cutout rig/motion без изменения gameplay/balance.

## Scope

- Нарезать Sniper source sprite на cutout parts через существующий pipeline.
- Обновить `scripts/sliced_rig_manifest.gd` для `sniper`.
- Добавить/настроить motion profile для дальнего точного класса:
  - steady idle/aim stance;
  - controlled walk without melee lunge feel;
  - readable attack pose hooks for lockshot, kill-zone marking, split shot.
- Проверить weapon socket placement with 3 Sniper weapon visuals.
- Keep animation smoke clean.

## Out Of Scope

- Не менять Sniper damage/cooldown/balance.
- Не менять Back-end targeting logic.
- Не создавать/перерисовывать art assets; canonical art comes from Design task.

## Acceptance

- Sniper cutout parts exist and assemble without missing resources.
- `animation_smoke_test.gd` passes for Sniper rig/motion.
- Weapon socket placement is readable for all 3 Sniper weapons.
- Any existing unrelated animation warnings are reported separately, not hidden.

## Dispatch

- 2026-06-13: handed off from Back-end thread after SCRUM-167 Sniper gameplay implementation; unblocked after Design art kit reached review.
- 2026-06-13: dispatched to Animator thread `019eb156-710c-71f0-8903-eada762dceb3` after canonical Sniper assets appeared. Animator owns cutout rig, motion profile, pose hooks, socket placement, and animation smoke only.

## Result

- 2026-06-13: Done. Generated `sniper_*` cutout parts and refreshed `scripts/sliced_rig_manifest.gd`.
- Added a controlled ranged/sniper motion profile in `scripts/cutout_rig_2d.gd`.
- Added action pose hooks for `sniper_deadeye_rifle` / lockshot brace, `sniper_spotter_scope` / kill-zone mark, and `sniper_shatter_rounds` / heavier split-round recoil.
- Verified `build/rig_debug/cut_sniper.png`; reassembled panel matches source art and cloak pieces stay on the torso/base layer.
- Weapon socket placement for all 3 Sniper weapon variants is covered by `tests/animation_smoke_test.gd`.
- Godot headless editor import passed; `tests/animation_smoke_test.gd` and `tests/runtime_smoke_test.gd` passed.
