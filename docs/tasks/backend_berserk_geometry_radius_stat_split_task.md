# Back-end: Берсерк — геометрия оружия и разделение радиуса/сектора

> Историческая справка: упоминания `sound_wave_damage` в этом документе описывают состояние ДО SCRUM-898 (2026-07-10). Звуковая ось урона удалена; оружия Гитариста/Друида бьют магией (`magic_damage`).

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
- Berserk hammer is now a 150 px circle with Radius scaling, no fixed close-ring cap, and dense-pack diminishing (`circle_full_targets=4`, `circle_target_diminish=0.62`) to keep live 20-target DPS in gate.
- `aoe_radius` level-up became sector width (`sector_multiplier`) and does not expand hammer circles; `aura_radius` is renamed to general Radius and maps to `aoe_radius_multiplier`.
- `magic_damage_multiplier` and `sound_damage_multiplier` are isolated damage-type modifiers; physical damage no longer increases from magic/sound-specific upgrades.

Verification:
- `python3 tools/godot_gate.py --headless --path . --script res://tests/melee_weapon_targeting_test.gd` — PASS.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/damage_type_isolation_test.gd` — PASS.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/event_data_contract_check.gd` — PASS.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/berserk_dps_runaway_gate.gd` — PASS after dense-pack margin fix (`lvl20_ideal`: 20t=3427/3456 <= 3600 across repeated runs, 1t=504/564 <= 650).
- `python3 tools/godot_gate.py --headless --path . --script res://tests/global_damage_balance_smoke_test.gd` — PASS.
- `python3 tools/godot_gate.py --headless --path . --script res://tools/balance_harness.gd` — PASS / reports regenerated in `build/`.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/weapon_integrity_test.gd` — PASS.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_test.gd` — PASS.

Disk cleanup: none created.

## QA-Вердикт

Статус: PASSED
Дата: 2026-07-03
QA owner: qa/codex-scrum-852-verification
Проверено на: working tree after dense-pack margin fix (`circle_target_diminish=0.62`); final commit SHA is recorded in Jira/Git after commit.

Acceptance verified:
- `berserk/sword`: `attack_shape=sweep`, `sweep_degrees=100`, `attack_range=350`, closest-enemy aiming covered by `tests/melee_weapon_targeting_test.gd`.
- `berserk/axe`: `attack_shape=sweep`, `sweep_degrees=180`, `attack_range=250`.
- `berserk/hammer`: circular hit area starts at `aoe_radius=150`, `max_aoe_radius=0`, radius scaling grows the circle, sector upgrades do not grow it, and dense-pack target diminishing is `0.62`.
- Physical Berserk hits are isolated from `magic_damage` and `sound_wave_damage` modifiers.

QA commands:
- `python3 tools/godot_gate.py --headless --path . --script res://tests/melee_weapon_targeting_test.gd` — PASS.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/damage_type_isolation_test.gd` — PASS.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/event_data_contract_check.gd` — PASS.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/berserk_dps_runaway_gate.gd` — PASS twice after fix (`lvl20_ideal`: 20t=3427/3456 <= 3600, 1t=504/564 <= 650).
- `python3 tools/godot_gate.py --headless --path . --script res://tests/global_damage_balance_smoke_test.gd` — PASS.
- `python3 tools/godot_gate.py --headless --path . --script res://tools/balance_harness.gd` — PASS / reports regenerated in `build/`.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/weapon_integrity_test.gd` — PASS.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/runtime_smoke_test.gd` — PASS.

Note: an earlier independent QA clone checked stale `origin/dev` at `7f45b6ff` and correctly reported the SCRUM-852 implementation missing there. After remote was refreshed, Noether re-ran on `411f1f1f` and caught one real blocker (`20t=3607 > 3600`). The final fix raises hammer dense-pack diminishing from `0.57` to `0.62`; repeated local gates now hold below the live runaway cap.
