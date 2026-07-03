# Back-end: Берсерк — геометрия оружия и разделение радиуса/сектора

Статус: done
Приоритет: P1
Роль: Back-end
Контур: Codex
Owner: backend/codex-berserk-geometry-radius-stat-split
Thread/Worker: current Codex control thread
Jira: SCRUM-852
Версия: 0.2.1
Создано: 2026-07-03
Locked paths: `scripts/progression_data_weapons.gd`, `scripts/progression_data.gd`, `scripts/progression_data_content.gd`, `scripts/progression_data_characters.gd`, `scripts/stat_formulas.gd`, `scripts/player.gd`, `scripts/berserk_weapon.gd`, `scripts/main.gd`, `scenes/TwoHandedSword.tscn`, `scenes/TwoHandedAxe.tscn`, `scenes/TwoHandedHammer.tscn`, `tests/runtime_smoke_test.gd`, `tests/melee_weapon_targeting_test.gd`, `tests/damage_type_isolation_test.gd`, `tests/berserk_dps_runaway_gate.gd`, `tests/event_data_contract_check.gd`, `tools/character_balance_csv.gd`, `docs/design/mechanics_extract.md`, `docs/design/systems/characters_weapons.md`, `docs/design/systems/progression_balance.md`, `docs/design/content_registry.md`, `docs/design/current_game_state.md`

## Контекст

Прямая пользовательская правка баланса Берсерка:
- молот должен бить кругом радиуса 150 px и дальше расти от радиусных параметров;
- топор должен бить сектором 180 градусов радиуса 250 px по направлению на ближайшего монстра;
- меч должен бить узким сектором 100 градусов радиуса 350 px;
- атрибут/награда ширины сектора не должен увеличивать молот;
- общий атрибут радиуса должен увеличивать радиус всех трех зон;
- магический и звуковой урон не должны усиливать физический урон Берсерка.

## Acceptance Criteria

- `berserk/sword`: сектор 100 градусов, базовый радиус 350 px, направление на ближайшего врага.
- `berserk/axe`: сектор 180 градусов, базовый радиус 250 px, направление на ближайшего врага.
- `berserk/hammer`: круг 150 px без fixed close-ring cap, radius scaling может увеличить круг.
- Sector/width upgrade влияет на `sweep_degrees` для меча/топора, не влияет на молот.
- Radius upgrade влияет на `attack_range`/`aoe_radius` всех трех weapons.
- Physical damage Берсерка использует только physical `damage`; `magic_damage` и `sound_wave_damage` не повышают его melee hits.
- Focused melee/runtime/type-isolation tests обновлены и проходят.

## Start Note

2026-07-03 Codex Back-end claim: Owner `backend/codex-berserk-geometry-radius-stat-split`, lane `Codex`, branch/worktree `dev` at `/Users/sergeyfomin/Documents/AI Agent`. Next verification: focused melee targeting/type-isolation checks, balance harness, and runtime smoke.

## Result

Done 2026-07-03:
- Berserk sword is now a `sweep` sector: 100 degrees, 350 px radius.
- Berserk axe is now a `sweep` sector: 180 degrees, 250 px radius.
- Berserk hammer is now a 150 px circle with Radius scaling, no fixed close-ring cap, and dense-pack diminishing (`circle_full_targets=4`, `circle_target_diminish=0.57`) to keep live 20-target DPS in gate.
- `aoe_radius` level-up became sector width (`sector_multiplier`) and does not expand hammer circles; `aura_radius` is renamed to general Radius and maps to `aoe_radius_multiplier`.
- `magic_damage_multiplier` and `sound_damage_multiplier` are isolated damage-type modifiers; physical damage no longer increases from magic/sound-specific upgrades.

Verification:
- `python3 tools/godot_gate.py --headless --path . --script res://tests/melee_weapon_targeting_test.gd` — PASS.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/damage_type_isolation_test.gd` — PASS.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/event_data_contract_check.gd` — PASS.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/berserk_dps_runaway_gate.gd` — PASS (`lvl20_ideal`: 20t=3469 <= 3600, 1t=474 <= 650).
- `python3 tools/godot_gate.py --headless --path . --script res://tests/global_damage_balance_smoke_test.gd` — PASS.
- `python3 tools/godot_gate.py --headless --path . --script res://tools/balance_harness.gd` — PASS / reports regenerated in `build/`.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/weapon_integrity_test.gd` — PASS.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_test.gd` — PASS.

Disk cleanup: none created.
