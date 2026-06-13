# Animator Task: Priest Cutout Rig And Motion

Статус: done
Версия: 0.1.4
Создано: 2026-06-13
Роль: Animator
Jira: SCRUM-165
Источник: `docs/tasks/backend_add_character_priest_task.md`
Design unblock 2026-06-13: `docs/tasks/codex_design_priest_art_task.md`
is in review and canonical source assets are ready:

- `assets/sprites/characters/priest.png`
- `assets/sprites/weapons/priest_reliquary.png`
- `assets/sprites/weapons/priest_censer.png`
- `assets/sprites/weapons/priest_chime.png`
- preview: `docs/design/previews/priest_art_contact.png`

Cutout parts are generated through the existing Animator pipeline.

## Context

Back-end добавил playable class `priest` с тремя weapon modes:

- `priest_sanctify` / `priest_reliquary`
- `priest_ward` / `priest_censer`
- `priest_prayer_chain` / `priest_chime`

Сейчас Priest использует fallback Doctor full-art и работает без отдельного rig. После готовности canonical Priest PNG нужно подключить cutout rig/motion без изменения gameplay/balance.

## Scope

- Нарезать Priest source sprite на cutout parts через существующий pipeline.
- Обновить `scripts/sliced_rig_manifest.gd` для `priest`.
- Добавить/настроить motion profile для healer/support caster:
  - calm idle/cast posture;
  - readable but not aggressive walk;
  - attack pose hooks for sanctify mark, ward pulse, prayer chain.
- Проверить weapon socket placement with 3 Priest weapon visuals.
- Keep animation smoke clean.

## Out Of Scope

- Не менять Priest damage/cooldown/balance.
- Не менять Back-end targeting/healing logic.
- Не создавать/перерисовывать art assets; canonical art comes from Design task.

## Acceptance

- Priest cutout parts exist and assemble without missing resources.
- `animation_smoke_test.gd` passes for Priest rig/motion.
- Weapon socket placement is readable for all 3 Priest weapons.
- Any existing unrelated animation warnings are reported separately, not hidden.

## Dispatch

- 2026-06-13: handed off from Back-end thread after SCRUM-165 Priest gameplay implementation; unblocked after Design art kit reached review.
- 2026-06-13: dispatcher confirmed existing Animator dispatch `019eb156-710c-71f0-8903-eada762dceb3`; task is ready for Animator execution without changing Back-end gameplay/balance.

## Result

- 2026-06-13: generated Priest cutout parts from `assets/sprites/characters/priest.png`:
  `assets/sprites/characters/cutout/priest_torso.png`,
  `priest_arm_l.png`, `priest_arm_r.png`, `priest_leg_l.png`, `priest_leg_r.png`,
  plus Godot `.import` files.
- Updated `tools/slice_rig_cutouts.py` and regenerated `scripts/sliced_rig_manifest.gd` with Priest pivots/socket placement; debug sheet: `build/rig_debug/cut_priest.png`.
- Added Priest healer/support caster motion profile in `scripts/cutout_rig_2d.gd`: calm low-bob walk, restrained arm swing, support-caster sway, and distinct shoot pose hooks:
  - `priest_reliquary` / `priest_sanctify`: raised blessing hand and release;
  - `priest_censer` / `priest_ward`: outward ward pulse gesture;
  - `priest_chime` / `priest_prayer_chain`: lifted chime/chant pose.
- Extended `tests/animation_smoke_test.gd` to cover Priest profile, animation variants, pose separation, and readable weapon socket placement for all 3 Priest weapons.
- Verification:
  - Godot headless editor import passed.
  - `res://tests/animation_smoke_test.gd` passed.
  - `res://tests/runtime_smoke_test.gd` passed.
