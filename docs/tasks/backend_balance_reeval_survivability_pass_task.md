# Balance Re-Evaluation: Survivability Tuning Pass

Jira: SCRUM-783
Статус: done
Приоритет: P1
Роль: Back-end / balance
Контур: Claude
Owner: Backend / Claude
Thread/Worker: claude-backend
Версия: 0.1.8
Создано: 2026-06-30
Автор: PM по запросу пользователя на пересмотр баланса (ось «выживаемость»)
Labels: backend, claude, foma, balance, p1, area-balance, area-survivability, reeval-wave
Epic: SCRUM-214 - Баланс

## Context

Дочерняя задача волны пересмотра баланса. Опирается на отчёт
`docs/design/reviews/balance_reeval_2026_06.md` (задача-аудит). Цель — выровнять
**выживаемость** между классами так, чтобы не было «стекляшек», умирающих от
любого касания, и «бессмертных» танков, обнуляющих сложность.

Не стартовать, пока аудит-задача не зафиксировала findings по survivability.

## Scope / Locked Paths

- `scripts/progression_data_balance.gd`, `scripts/progression_data_characters.gd`
  (только параметры выживаемости: HP, defense, dodge, endurance-скейл).
- `scripts/stat_formulas.gd` — только если аудит доказал баг формулы effective-HP.
- Тесты: `tests/global_survivability_balance_smoke_test.gd`,
  `tests/survivability_scenario_test.gd`.
- `docs/design/systems/progression_balance.md` (секция выживаемости).

## Required Change

По выводам аудита привести effective-HP (HP + defense + dodge) и sustain
(vampirism/реген) классов в комфортный коридор:

- Поднять самые хрупкие классы до пола выживаемости (не умирать от одного хита
  на своей волне), не делая их танками.
- Срезать чрезмерный sustain/EHP у классов, обнуляющих риск (см. память про
  vampirism-nerf + weighted level-up).
- Сохранить ролевую идентичность (танк ≠ ассасин); правки в пределах
  class-kit коридора 0.90..1.10, как в прошлых пассах.
- Каждое изменение значения — с before/after и обоснованием в отчёте.

## Acceptance Criteria

- Spread выживаемости между классами сужен к целевому диапазону из отчёта.
- Ни один класс не вне survivability-floor и не выше танк-ceiling.
- `global_survivability_balance_smoke_test.gd` и `survivability_scenario_test.gd`
  зелёные; comfort-band не ухудшен.
- Нет silent-retune: каждое число задокументировано before/after в
  `progression_balance.md` и финальном комменте.
- Ролевые идентичности сохранены (танк/глушка/ассасин различимы).
- Финальный Jira-коммент: branch/commit, тесты, before/after, `Disk cleanup: ...`.

## Suggested Verification

```bash
python3 tools/godot_gate.py --headless --path . --script res://tests/global_survivability_balance_smoke_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/survivability_scenario_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/comfort_band_cross_class_gate.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/contact_damage_softcap_test.gd
```

## Process Notes

Sync `dev`, проверить отсутствие активных владельцев на locked paths (не
пересекаться с damage/comfort пассами — изоляция файлов; survivability берёт
только survivability-параметры). Гейты по одному. После: Jira -> mirror ->
intentional commit (явный git add своих файлов при churn) -> push.
