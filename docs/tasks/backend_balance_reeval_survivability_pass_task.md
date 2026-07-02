# Balance Re-Evaluation: Survivability Tuning Pass

Jira: SCRUM-783
Статус: done
Приоритет: P1
Роль: Back-end / balance
Контур: Claude
Owner: Backend / Claude
Thread/Worker: claude-backend
Версия: 0.2.0
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

## QA-Вердикт

Статус: PASSED
Дата: 2026-06-30 | QA: claude-qa | HEAD: origin/dev | Godot 4.7 (godot_gate)

Изолированная survivability-правка принята. Единственное изменение —
`progression_data_characters.gd::BASE_STATS` dark_mage `endurance` 2.0→3.0
(commit 3354c17a, merged в origin/dev; mirror ea749118). Locked-path соблюдён
(только survivability-стат, damage/comfort-файлы не тронуты). Before/after
задокументирован в `progression_balance.md` §«Survivability re-eval (SCRUM-783)»
и финальном Jira-комменте — silent-retune отсутствует.

Гейты (все PASS на HEAD, семафор, по одному):
- global_survivability_balance_smoke: 16 строк, TTD≤600с, митигация<98%, бессмертие недостижимо.
- survivability_scenario: формула EHP == боевой take_damage (якорь 33.055==33.055), монотонность/слои/absorb зелёные.
- comfort_band_cross_class: spread 1.13x, 0 нарушений (НЕ ухудшен — endurance не задел damage/comfort).
- contact_damage_softcap: рядовой контакт капится 20% max HP, мелкий проходит.
- class_damage_table_3variants: 17 классов, 153 строки — damage-коридор цел (подтверждает осознанный no-trim танк-потолка).
- runtime_smoke_test (umbrella): PASS, duplicate-artifact guard 11648 файлов.

Acceptance:
- Spread выживаемости сужен (5.9x→4.03x, dark_mage floor 0.39x→0.57x медианы). ✓
- Survivability-floor поднят (dark_mage не one-touch); танк-потолок 185-203 EHP не «бессмертен» (TTD≤600с) — gate подтверждает. ✓
- global_survivability_balance_smoke + survivability_scenario зелёные; comfort-band не ухудшен. ✓
- Нет silent-retune: каждое число before/after в progression_balance.md + Jira. ✓
- Ролевые идентичности сохранены (dark_mage glass cannon / танки tank). ✓
- Финальный Jira-коммент: branch/commit/тесты/before-after/Disk cleanup. ✓

Примечание: танк-потолок (knight 203/robot 185) осознанно НЕ срезан — trim endurance
10→9 ломает damage-коридор (relative_score >1.10, срезо-зависимость, блокеры 504-544);
отложено в совместный damage+survivability пасс с ре-деривацией коридора. Survivability-
гейт кодирует floor/ceiling-правила и зелёный → AC удовлетворены. Соответствует
PM-решению по balance-AC-blocker 504/505/506/544.
