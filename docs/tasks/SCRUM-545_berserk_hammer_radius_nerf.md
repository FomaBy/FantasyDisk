# SCRUM-545: Нерф радиуса берсерк-хаммера: убрать AFK-фарм

Jira: SCRUM-545
Статус: review
Роль: backend
Контур: Codex
Owner: Back-end / codex-background-backend-agent
Thread/Worker: codex-background-backend-agent
Locked paths: scripts/berserk_weapon.gd, scripts/progression_data_weapons.gd, tests/melee_weapon_targeting_test.gd, tests/berserk_dps_runaway_gate.gd, docs/design/systems/characters_weapons.md, docs/design/systems/progression_balance.md, docs/design/current_game_state.md

## Задача

Сильно уменьшить фактическую позднеигровую зону поражения `berserk/hammer`, чтобы молот оставался сильным ближним круговым оружием, но больше не фармил толпу на AFK за счет огромного радиуса. Не трогать урон/множители SCRUM-503; правка должна быть геометрической.

## Acceptance

- Радиус/зона молота заметно уменьшены: ближнее кольцо вокруг игрока, не экранная зона.
- `berserk/hammer` сохраняет соло-смысл по цели в упор.
- 20-target DPS падает за счет меньшего числа одновременно попадающих целей, а не за счет урона по одной цели.
- Меч/топор Берсерка не затронуты.
- Headless balance/combat smokes проходят или отклонения явно зафиксированы как чужие.

## Work Log

- 2026-06-28 EEST — Claimed in Jira by `codex-background-backend-agent`. Dirty worktree contains Claude-owned SCRUM-498 files (`scripts/enemy.gd`, `scripts/ui_screens.gd`, `tests/runtime_smoke_test.gd`, `scripts/threat_indicators.gd`, `scratchpad_jira.py`); this task avoids those paths.
- 2026-06-28 EEST — Decision: solve with hammer-specific geometry cap in `BerserkWeapon`, not damage multipliers. Rationale: SCRUM-545 scope is AFK radius, while SCRUM-503 already owns DPS multiplier runaway.
- 2026-06-28 EEST — Jira moved to `Контроль качества`; local mirror set to `review`.

## Result

Balance result:
- Scope: `berserk/hammer` geometry only. `sword`/`axe` and SCRUM-503 damage/attack-speed multipliers were not changed.
- Mechanics changed: `BerserkWeapon` now supports optional `max_aoe_radius`; circle hit checks and VFX use the effective capped radius. `berserk/hammer` sets `max_aoe_radius=145`.
- Numeric tuning changed: none for damage, cooldown, attack-speed, or upgrade exponents.
- Before/after: checked-in stale CSV row before task was `berserk/hammer lvl20_ideal_20t=60450.57`, `1t=2519.81`. Focused live gate before radius cap on current soft-cap code was ~`20t=13851`, `1t=922`; after cap it is ~`20t=8858`, `1t=840`. In the attempted full CSV regeneration the hammer row was `lvl20_ideal_20t=9518.7`, `1t=922.4`.
- Per-weapon identity: hammer remains the close circular stagger weapon; late AoE upgrades no longer turn it into a screen-wide AFK farmer. Sword remains long frustum reach; axe remains wide sweep/cleave.
- Commands run:
  - `tests/melee_weapon_targeting_test.gd` — PASS (with existing `data.tree is null` warning from weapon attach path).
  - `tests/berserk_dps_runaway_gate.gd` — PASS (`20t=8858 <= 12000`, `1t=840 <= 2363`).
  - `tests/class_damage_table_3variants_test.gd` — PASS.
  - `tests/global_damage_balance_smoke_test.gd` — PASS.
  - `tools/balance_harness.gd` — PASS/report written.
  - `tools/character_balance_csv.gd` — INCOMPLETE/nonzero after reaching Elementalist rows; hammer row was printed with accepted numbers, but the CSV file was not rewritten.
- Docs updated: mechanics extract, current game state, characters/weapons system doc, progression balance system doc.
- Remaining risk: full matrix runner still needs a clean complete pass in QA; current worktree also contains Claude-owned SCRUM-498 dirty files, so this task did not touch HUD/threat-indicator paths.
