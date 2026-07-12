# SCRUM-1019 — independent QA: below-base Elementalist Intelligence penalties

Статус: done
Дата: 2026-07-10
Jira: SCRUM-1019
QA owner: Codex `/root/audit_repo`
Контур: Codex
Remediation: `2a8aac19` (Jira sync `cee96169`)

## QA-Вердикт

Статус: PASSED

Независимая перепроверка подтвердила, что remediation устраняет блокирующий
дефект SCRUM-947 без изменения tuning или механик кита. В
`ProgressionData.derived_parameters()` реальное значение Intelligence теперь
сохраняется по умолчанию, а пересборка с `magic_bonus_effectiveness = 1.30`
выполняется только для строго положительной дельты над базой класса.

Свежий QA-probe на Elementalist `elementalist_orb_ring` дал:

- нулевая дельта: ratio магического урона `1.000000`;
- положительная дельта `+2`: фактический ratio `1.265778`, ожидаемый
  `(base + 2 × class_growth × 1.30) / base = 1.265778`;
- отрицательная дельта `-2`: фактический ratio `0.777778`, ожидаемый
  `(base - 2) / base = 0.777778` — штраф не стёрт и не умножен на `1.30`;
- run-штраф `magic_damage_multiplier = 0.80`: ratio `0.800000`;
- passive-штраф `magic_damage_multiplier = 0.80`: ratio `0.800000`;
- независимое произведение run+passive magic-бонусов: фактический factor
  `1.349363`, ожидаемый `1.349363` — повторного применения trait нет;
- при положительной и отрицательной Intelligence delta физический `damage` и
  `dot_damage` не изменились.

Probe был временным QA-файлом, после прогона удалён вместе с Godot `.uid`; в
production/test scope QA изменений не вносил.

## Регрессионные ворота

Все команды запускались через `tools/godot_gate.py` с Godot 4.7 и завершились
PASS:

- `tests/elementalist_kit_test.gd`;
- `tests/damage_type_isolation_test.gd`;
- `tests/weapon_tuning_application_test.gd` — 51/51 пар;
- `tests/class_budget_profiles_integrity_test.gd` — 17 классов;
- `tests/global_damage_balance_smoke_test.gd` — 51 пара, худший CCT `+22%`;
- `tests/global_survivability_balance_smoke_test.gd` — 16 строк, без
  бессмертия/нарушения cap;
- `tests/comfort_band_cross_class_gate.gd` — 153/153 замера в полосе, spread
  `1.13x` на срезах 1/5/20 целей;
- `tests/projectile_chain_pierce_identity_test.gd`;
- `tests/animation_smoke_test.gd`;
- `tests/runtime_smoke_test.gd`;
- `tools/balance_harness.gd`;
- `tools/survivability_harness.gd`.

Runtime smoke завершился PASS; присутствовал только известный dummy-renderer
null-texture screenshot diagnostic. После тестов ветка была fast-forward на
актуальный `origin/dev` `9ce035b6`; новые коммиты затрагивали только SCRUM-1017
Design mockup/evidence и `jira_sync_map.json`, не production balance-код или
тесты, поэтому повторный кодовый gate не требовался.

## Балансный результат

`balance_harness` подтвердил PASS всех 51 class+weapon пар. Elementalist
сохранил настроенные бюджеты:

| Оружие | Solo DPS | 20-target DPS | EHP | Gate |
| --- | ---: | ---: | ---: | --- |
| `elementalist_orb_ring` | 51.84 | 178.11 | 50.8 | PASS |
| `elementalist_prism_focus` | 51.84 | 178.22 | 50.8 | PASS |
| `elementalist_meteor_core` | 51.85 | 178.23 | 50.8 | PASS |

Итог: SCRUM-1019 принят; родительский SCRUM-947 разблокирован и также может
быть переведён в `Готово`.

Disk cleanup: disposable `.godot/`, generated `build/`, temporary probe and QA
worktree removed after Jira/GitHub synchronization.
