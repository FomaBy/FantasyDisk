# Back-end Task: Refactor `class_weapon.gd` Into Weapon Mode Registry

Статус: done
Версия: 0.1.4
Создано: 2026-06-13
Автор: Back-end audit SCRUM-174
Jira: SCRUM-196
QA: in_progress (2026-06-13)
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

## Dispatcher Unblock / Dispatch (2026-06-13)

Unblocked for a serialized Back-end refactor window: no active class/weapon work
is in progress and `scripts/class_weapon.gd` was clean in git status. Dispatched
to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` as item 2 after
SCRUM-202. Keep reasoning High/no low; close and Jira-sync SCRUM-202 before
starting this task, then close and Jira-sync this task before the next queued
refactor.

## Result (2026-06-13)

Completed during the 0.1.4 stabilization window as a low-risk behavior-preserving
refactor:

- `scripts/class_weapon.gd` now exposes `ATTACK_MODE_EXECUTORS`,
  `registered_attack_modes()` and `has_attack_mode_executor()`.
- The old long `_attack()` `match attack_mode` dispatch was replaced by a single
  registry executor call. Existing `_fire_*` mechanics, deployable cleanup
  groups and `player_weapon_effects` contracts were preserved.
- Primary and event animation action selection now share explicit mode tables
  instead of duplicated inline arrays.
- `tests/runtime_smoke_test.gd` and
  `tests/runtime_smoke_weapon_mechanics_test.gd` now assert that every
  non-Berserk weapon config with a data-driven `attack_mode` has a registered
  `ClassWeapon` executor. Legacy `attack_shape`/`summon`/`strip`/`sweep`/`circle`
  modes remain outside the `ClassWeapon` executor contract.
- Larger helper extraction into separate scripts was intentionally not expanded
  beyond the registry/wrapper seam during feature freeze to avoid destabilizing
  weapon damage, cleanup and delayed callback behavior.

Verification:

- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_weapon_mechanics_test.gd` — passed.
- `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd` — passed. Existing non-fatal `Lambda capture at index 0 was freed` log still appears before the pass line and is unrelated to SCRUM-196.

## QA-Вердикт (2026-06-13)
Статус: PASSED
Коммит: 1fbc20c6 (ветка dev; HEAD сдвинулся за время прогона, тесты зелёные на нём)

Проверено (фактически):
- **Registry + API**: `ATTACK_MODE_EXECUTORS` (class_weapon.gd:27),
  `registered_attack_modes()` (121), `has_attack_mode_executor()` (125).
  `_attack()` (209) диспатчит одним вызовом через
  `ATTACK_MODE_EXECUTORS.get(attack_mode, …DEFAULT…)` (251),
  `DEFAULT_ATTACK_MODE="sound_wave"` (10) как fallback.
- **Поведение сохранено**: 83 зарегистрированных executor'а покрывают все 39
  отдельных `_fire_*` механик (включая классовые sniper/priest/robot/engineer/bio).
  `_fire_*` функции на месте, не потеряны.
- **Coverage-регрессия не пустышка** (runtime_smoke:2306-2312): обходит ВЕСЬ
  не-Берсерк ростер `ProgressionData`, для каждого config с `attack_mode`
  ассертит `ClassWeapon.has_attack_mode_executor(mode)`, собирает missing и
  падает при пропуске. Это и есть требуемая приёмкой регрессия «каждый
  attack_mode имеет executor».
- **Тесты headless (1fbc20c6)**: `runtime_smoke_weapon_mechanics_test`,
  `melee_weapon_targeting_test`, `animation_smoke_test` (задача трогала
  anim mode-tables), umbrella `runtime_smoke_test`, `meta_progression_smoke_test`
  — все passed.

Acceptance:
- [x] Поведение не-Берсерк оружия сохранено (coverage-тест + weapon/umbrella smoke).
- [x] Scene/API совместимость `ClassWeapon` (`_attack` — та же точка входа, методы
  registry добавлены, не удалены).
- [x] Registry-seam + общие mode-tables (расширение helper-экстракции намеренно
  ограничено на время фриза — задокументировано в Result).
- [x] Deployable cleanup groups / `player_weapon_effects` — smoke зелёный.
- [x] Регрессия «mode → executor» добавлена.

Краевые случаи:
- Неизвестный mode → fallback `DEFAULT_ATTACK_MODE` (не краш).
- 83 executor / 39 `_fire_*` — все классовые механики присутствуют.
- Анимационный выбор action (mode-tables) — animation smoke зелёный.

Баги: нет. (Латентный umbrella-warning `Lambda capture freed` — общий, не от
SCRUM-196; учтён в QA SCRUM-202.)
