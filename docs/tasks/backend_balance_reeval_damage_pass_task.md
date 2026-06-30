# Balance Re-Evaluation: Damage Tuning Pass

Jira: SCRUM-782
Статус: done
Приоритет: P1
Роль: Back-end / balance
Контур: Claude
Owner: Backend / Claude
Thread/Worker: claude-backend
Версия: 0.1.8
Создано: 2026-06-30
Автор: PM по запросу пользователя на пересмотр баланса (ось «урон»)
Labels: backend, claude, foma, balance, p1, area-balance, area-damage, reeval-wave
Epic: SCRUM-214 - Баланс

## Context

Дочерняя задача волны пересмотра баланса. Опирается на отчёт
`docs/design/reviews/balance_reeval_2026_06.md`. Цель — сузить разброс **урона**
между классами/оружием, не убивая ролевые архетипы (solo-burst vs AoE/control vs
summon). Учесть прошлый результат: best-weapon lvl20 spread (без berserk) держать
<= 2.0x, классы держать выше 0.75x медианного пола.

Не стартовать, пока аудит-задача не зафиксировала findings по damage.

## Scope / Locked Paths

- `scripts/progression_data_balance.gd`, `scripts/progression_data_weapons.gd`
  (damage/crit/attack-speed/scaling параметры).
- Тесты: `tests/global_damage_balance_smoke_test.gd`,
  `tests/class_damage_table_3variants_test.gd`, `tests/berserk_dps_runaway_gate.gd`,
  `tests/summon_weapon_crowd_floor_test.gd`.
- `docs/design/systems/progression_balance.md` (секция урона).

## Required Change

По выводам аудита:

- Подтянуть нижние классы/оружие к 0.75x медианного пола, срезать верхние
  выбросы lvl20-growth tail, удерживая best-weapon spread (без berserk) <= 2.0x.
- Стабилизировать пол summon/deploy-классов (druid amulet, chemist homunculus,
  engineer sentry) по `summon_weapon_crowd_floor_test.gd`.
- Berserk-ось проверять отдельным `berserk_dps_runaway_gate.gd` (не гонять
  тяжёлый CSV-арбитр — SIGABRT-флейк; ре-нормировку считать в Python).
- Сохранить идентичность: AoE/control классы остаются с честным solo-target,
  solo-burst классы не получают AoE-халяву.
- Каждое число — before/after + обоснование.

## Acceptance Criteria

- best-weapon `lvl20_ideal_1t` spread без berserk <= 2.0x; целевые классы выше
  0.75x пола и вне нижней четвёрки.
- random-build spreads (`lvl20_random_1t`, `lvl20_random_20t`) не ухудшены.
- summon/deploy floor стабилен (детерминированные budget-оценки в тесте).
- Все damage-гейты зелёные; ролевые архетипы различимы.
- Нет silent-retune: before/after по каждому числу в отчёте и комменте.
- Финальный Jira-коммент: branch/commit, тесты, before/after, `Disk cleanup: ...`.

## Suggested Verification

```bash
python3 tools/godot_gate.py --headless --path . --script res://tests/global_damage_balance_smoke_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/class_damage_table_3variants_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/summon_weapon_crowd_floor_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/berserk_dps_runaway_gate.gd
```

## Process Notes

Sync `dev`, проверить отсутствие активных владельцев на locked paths (не
пересекаться с survivability/comfort пассами). Гейты по одному (pkill чужих
Godot опасен при живом флоте). После: Jira -> mirror -> intentional commit
(явный git add) -> push. Учесть память про balance AC-blocker: AC через band,
а не абсолют; CSV-арбитр не гонять под нагрузкой.

## QA-Вердикт

Статус: PASSED
Дата: 2026-06-30 | QA: claude-qa | HEAD: origin/dev | Godot 4.7 (godot_gate)

Evidence-confirm no-op принят: AC SCRUM-782 (output-spread + floor) уже удовлетворены
на committed-тюнинге 504/506; остаточная budget-cap хрупкость — ИДЕНТИЧНОСТНАЯ проблема,
НЕ покрыта AC этого тикета, и безопасно отложена (CSV-арбитр SIGABRT-нестабилен → рисковый
ретюн в P1 не верифицируется; путь задокументирован). Соответствует PM-решению по
balance-AC-blocker 504/505/506/544.

Гейты (все PASS на HEAD, семафор, по одному):
- global_damage_balance_smoke: 51 пара, combined ±25%/solo ±20%/CCT ±30%, худшее CCT +22% (doctor/restore_potion/20).
- class_damage_table_3variants: 17 классов, 153 строки (lvl20-optimum коридор).
- summon_weapon_crowd_floor: druid 129.8/621.7, chemist 194.2/611.6, engineer 139.7/648.5 — все ≥ floor (совпадает с замером).
- berserk_dps_runaway (single): 20t=2164≤3600, 1t=514≤650.

Acceptance:
- best-weapon lvl20_ideal_1t spread без berserk ≤2.0x; целевые классы выше 0.75x пола. ✓
- random-build spreads не ухудшены (нет правок). ✓
- summon/deploy floor стабилен. ✓ Все damage-гейты зелёные, архетипы различимы. ✓
- Нет silent-retune: правок баланса нет, evidence задокументирован (progression_balance.md §Damage re-eval). ✓
- Соседние гейты не регрессировали: commits 975bb087+89e65a08 docs-only (scripts/tests НЕ изменены). ✓
