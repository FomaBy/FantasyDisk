# Refactor Wave: Class Weapon Executor Registry And Attack Modes

Jira: SCRUM-710
Статус: done
Приоритет: P1
Роль: Back-end / weapon quality
Контур: Claude
Owner: unassigned
Thread/Worker: n/a
Версия: 0.1.8
Создано: 2026-06-30
Автор: PM/Codex по запросу пользователя на полный рефакторинг игры
Labels: backend, claude, foma, refactor, refactor-wave, p1, area-weapons, area-combat
Epic: SCRUM-220 - Качество кода, тесты, аудиты

## Context

This task owns the non-Berserk class weapon runtime. It is intentionally separated from `player.gd`, Berserk melee and SummonerWeapon work to avoid locked-path overlap.

## Scope / Locked Paths

- `scripts/class_weapon.gd`
- Class weapon scenes under `scenes/*` only when the scene belongs to a touched weapon
- `tests/weapon_scene_integrity_test.gd`
- `docs/design/systems/characters_weapons.md`

## Required Change

Audit and safely refactor non-Berserk class weapon execution: `ATTACK_MODE_EXECUTORS`, `_fire_*` methods, damage type routing, VFX metadata, target query usage, deployable cleanup, attack cooldown state and data-driven config contracts for all 51 weapons.

## Acceptance Criteria

- Attack mode registry remains complete for every data-driven weapon mode.
- No weapon silently falls through or uses a wrong proxy scene/texture.
- Cleanup groups for deployables, temporary effects and projectiles remain reliable.
- Any behavior change is a verified bugfix, not an untracked balance/design change.
- Focused weapon tests are updated or added for changed contracts.
- Final Jira comment includes branch/commit, tests, evidence paths and `Disk cleanup: ...`.

## Suggested Verification

```bash
python3 tools/godot_gate.py --headless --path . --script res://tests/weapon_scene_integrity_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_weapon_mechanics_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/global_damage_balance_smoke_test.gd
```

## Process Notes

Before starting, Claude must sync `dev`, check dirty tree and verify no active owner overlaps the locked paths. Do not touch unrelated WIP. After completion: Jira -> local mirror -> checks -> intentional commit -> push.

## Результат (Claude backend, 2026-06-30)

Ветка/коммит: `dev` @ `68a7a70c` (origin/dev, ancestor подтверждён).

Аудит `scripts/class_weapon.gd` (2398 строк, 51 оружие, 35 attack-mode):
- Реестр `ATTACK_MODE_EXECUTORS` полон: все 35 уникальных режимов из data
  (`progression_data_weapons.gd`) зарегистрированы; диспетчер `_execute_attack_mode`
  делает lookup с fallback в `DEFAULT_ATTACK_MODE` ('sound_wave') — без рантайм-краша.
- `attack_mode` читает ТОЛЬКО class_weapon; berserk/summoner-оружие это поле не
  использует (проверено grep) — значит инвариант «каждый data attack_mode →
  зарегистрирован» применим ко всем 43 оружиям, задающим поле.
- Cleanup-группы deployables надёжны: amp/sentry/mine кладутся в
  `deployed_sound_amps`/`engineer_devices` (реапятся `game._clear_world` по группе),
  эффекты — в `player_weapon_effects` с pruning мёртвых ссылок в `_register_effect`/
  `_alive_effects`/`cleanup_effects` (вызов из `_exit_tree`).
- **Concrete-багов не найдено → поведение не менялось** (балансовые/дизайн-значения
  и логика атак нетронуты, per AC «behavior change = verified bugfix only»).

Изменения (locked path):
- `tests/weapon_scene_integrity_test.gd` — регрессионный гейт инварианта реестра:
  1. для каждого оружия с `attack_mode` требуем `ClassWeapon.has_attack_mode_executor`
     (иначе молчаливый fallback в 'sound_wave' — оружие стреляло бы чужой атакой);
  2. целостность реестра: каждый `ATTACK_MODE_EXECUTORS[mode]` резолвится в реальный
     метод `ClassWeapon` (защита от опечатки), `DEFAULT_ATTACK_MODE` зарегистрирован;
  3. анти-вакуум: >=12 уникальных режимов реально присутствуют в data.

Проверки (semaphore, GODOT_BIN=fdengine, slots=1) — все RC=0:
- `tests/weapon_scene_integrity_test.gd` → "Weapon scene integrity passed
  (51 оружие, ... attack_mode-реестр полон: 35 уникальных режимов из 35)."
- `tests/runtime_smoke_test.gd` → "Runtime smoke test passed."

Disk cleanup: рабочий worktree `/private/tmp/fsd_wt_scrum710` удалён после пуша;
временных артефактов не оставлено.
