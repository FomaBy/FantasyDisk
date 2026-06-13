# Back-end Task: Refactor `class_weapon.gd` Into Weapon Mode Registry

Статус: blocked
Версия: 0.1.4
Создано: 2026-06-13
Автор: Back-end audit SCRUM-174
Jira: SCRUM-196
Эпик: epic_full_project_quality_pass

## Scope

Replace the long `attack_mode` match in `scripts/class_weapon.gd` with a registry of mode executors and move shared helpers into focused scripts.

## Requirements

- Preserve all 48 non-Berserk weapon behaviors.
- Keep scene/API compatibility for `ClassWeapon`.
- Extract shared targeting/damage/cleanup helpers.
- Keep deployable cleanup groups and `player_weapon_effects` contract.

## Verification

- All weapon mechanics tests and runtime smoke pass.
- Add regression that every `attack_mode` in `ProgressionData.WEAPONS_BY_CLASS` has a registered executor.

## Serialization

High conflict risk. Run only after active class/weapon work is complete.

## Dispatcher Note (2026-06-13)
Dispatched to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` after user confirmed no feature freeze / backlog is eligible.
Dispatcher: restarted to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` on 2026-06-13 after PM reset stale in_progress. High-conflict task; serialize with active class/weapon work.

## Blocked / Serialized (2026-06-13)

Blocked by serialization, not by a technical failure. This refactor touches the
shared `scripts/class_weapon.gd` hot path for all 51 weapon variants and should
not run while class/content alignment and smoke-regression cleanup are active.

Next unblock: resume after current class/weapon/content tasks are stable and
there is an isolated refactor window. No `class_weapon.gd` refactor was started.
