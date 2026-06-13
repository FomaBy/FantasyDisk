# Animator Task: Engineer Cutout Rig And Motion

Статус: in_progress
Версия: 0.1.4
Создано: 2026-06-13
Автор: Back-end handoff для `backend_add_character_engineer_task.md`
Jira: SCRUM-164
Unblocked By: `docs/tasks/codex_design_engineer_art_task.md`

## Цель

После готовности canonical `assets/sprites/characters/engineer.png` собрать cutout rig и motion-профиль
для нового класса `engineer` без изменения gameplay/balance.

## Scope

- Нарезать cutout parts:
  - `assets/sprites/characters/cutout/engineer_torso.png`
  - `assets/sprites/characters/cutout/engineer_arm_l.png`
  - `assets/sprites/characters/cutout/engineer_arm_r.png`
  - `assets/sprites/characters/cutout/engineer_leg_l.png`
  - `assets/sprites/characters/cutout/engineer_leg_r.png`
- Обновить `scripts/sliced_rig_manifest.gd`.
- Добавить motion profile: практичная походка мастера с рюкзаком/инструментами, не копировать Druid/Robot.
- Добавить/проверить action hooks под weapon variants:
  - `engineer_sentry_wrench`
  - `engineer_repair_drone`
  - `engineer_pressure_mines`

## Role Boundary

Animator owns rig/motion/pose/timing polish. Back-end owns only gameplay configs and attack logic.

## Acceptance

- Animation smoke passes.
- Full-art sprite and cutout rest pose match visually.
- Motion не ломает socket/equipped weapon display.

## Dispatch Notes

- 2026-06-13: Dispatcher sent to Animator thread `019eb156-710c-71f0-8903-eada762dceb3`. Design task is in `review` with required PNGs/imports present; keep work to Animator-owned cutout/rig/motion and action hook polish.
- 2026-06-13: Design handoff unblocked. Ready assets: `assets/sprites/characters/engineer.png`, `assets/sprites/weapons/engineer_sentry_wrench.png`, `assets/sprites/weapons/engineer_repair_drone.png`, `assets/sprites/weapons/engineer_pressure_mines.png`; preview `docs/design/previews/engineer_art_contact.png`. Proceed with Animator-owned cutout/rig/motion only; no Back-end gameplay/balance changes.

## Dispatch Notes

- 2026-06-13: Animator received Back-end handoff for SCRUM-164. Verified current branch `dev`; task remains `blocked` because `assets/sprites/characters/engineer.png` does not exist yet and `docs/tasks/codex_design_engineer_art_task.md` is still `in_progress`. No Back-end gameplay/balance changes made.
