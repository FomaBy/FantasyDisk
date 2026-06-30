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
