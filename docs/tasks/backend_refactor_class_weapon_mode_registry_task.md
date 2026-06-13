# Back-end Task: Refactor `class_weapon.gd` Into Weapon Mode Registry

Статус: new
Версия: 0.1.5
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
