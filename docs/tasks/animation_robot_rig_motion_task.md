# Animator Task: Robot Cutout Rig And Motion

Статус: done
Версия: 0.1.4
Создано: 2026-06-13
Автор: Back-end handoff для `backend_add_character_robot_task.md`
Jira: SCRUM-166
Unblocked By: `docs/tasks/codex_design_robot_art_task.md`

## Цель

После готовности canonical `assets/sprites/characters/robot.png` собрать cutout rig и motion-профиль
для нового класса `robot` без изменения gameplay/balance.

## Scope

- Нарезать cutout parts:
  - `assets/sprites/characters/cutout/robot_torso.png`
  - `assets/sprites/characters/cutout/robot_arm_l.png`
  - `assets/sprites/characters/cutout/robot_arm_r.png`
  - `assets/sprites/characters/cutout/robot_leg_l.png`
  - `assets/sprites/characters/cutout/robot_leg_r.png`
- Обновить `scripts/sliced_rig_manifest.gd`.
- Добавить тяжелый, инертный motion profile: медленный шаг, заметная масса корпуса, GroundShadow.
- Добавить/проверить action hooks под weapon variants:
  - `robot_magnetic_anchor`
  - `robot_hydraulic_press`
  - `robot_reactor_core`

## Role Boundary

Animator owns rig/motion/pose/timing polish. Back-end owns only gameplay configs and attack logic.

## Acceptance

- Animation smoke passes.
- Full-art sprite and cutout rest pose match visually.
- Motion не ломает socket/equipped weapon display.

## Dispatch Notes

- 2026-06-13: Animator received Back-end handoff for SCRUM-166. Verified current branch `dev`; task remains `blocked` because `assets/sprites/characters/robot.png` does not exist yet and `docs/tasks/codex_design_robot_art_task.md` is still `in_progress`. No Back-end gameplay/balance changes made.
- 2026-06-13: Design handoff unblocked. Ready assets: `assets/sprites/characters/robot.png`, `assets/sprites/weapons/robot_magnetic_anchor.png`, `assets/sprites/weapons/robot_hydraulic_press.png`, `assets/sprites/weapons/robot_reactor_core.png`; preview `docs/design/previews/robot_art_contact.png`. Proceed with Animator-owned cutout/rig/motion only; no Back-end gameplay/balance changes.

## Result

- 2026-06-13: generated Robot cutout parts from `assets/sprites/characters/robot.png`:
  `assets/sprites/characters/cutout/robot_torso.png`,
  `robot_arm_l.png`, `robot_arm_r.png`, `robot_leg_l.png`, `robot_leg_r.png`,
  plus Godot `.import` files.
- Updated `tools/slice_rig_cutouts.py` and regenerated `scripts/sliced_rig_manifest.gd` with Robot pivots/socket placement; debug sheet: `build/rig_debug/cut_robot.png`.
- Added distinct heavy construct motion profile in `scripts/cutout_rig_2d.gd`: slow inertial walk, strong mass bob, low arm swing, heavy foot lift, slower blend rates.
- Added shoot pose hooks:
  - `robot_magnetic_anchor`: heavy plant and low pull gesture;
  - `robot_hydraulic_press`: forward dual-arm compression drive;
  - `robot_reactor_core`: wide reactor vent stance with both arms opening.
- Extended `tests/animation_smoke_test.gd` to cover Robot profile, animation variants, pose separation, and readable weapon socket placement for all 3 Robot weapons.
- Verification:
  - Godot headless editor import passed.
  - `res://tests/animation_smoke_test.gd` passed.
  - `res://tests/runtime_smoke_test.gd` passed.


## QA-Вердикт (2026-06-13)
Статус: PASSED (SCRUM-166)
- Cutout-части (5) + manifest для `robot`; motion profile/attack pose hooks 3 оружий.
- animation_smoke + runtime_smoke зелёные на чистом HEAD (сборка рига проходит). Багов нет.
