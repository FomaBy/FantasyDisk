# BALANCE: Нормализовать relative_score при lvl20-оптимуме к ≈1 для всех классов

Статус: done
Приоритет: high
Роль: Back-end (баланс)
Исполнитель: Codex (скилл fantasydisk-class-balance-director)
Версия: 0.1.6
Создано: 2026-06-17
Автор: PM (запрос пользователя)
Jira: SCRUM-469
QA: in_progress (2026-06-17)

## Dispatch
2026-06-17T14:12Z — Documentation dispatcher routed this Sprint 0.1.6 Back-end/balance task to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2`. Keep reasoning High/no low. Use `fantasydisk-class-balance-director`; do not touch Design/Animator scope.

## Autonomy / Approval
Пользователь заранее одобрил всё. Полная автономия, без вопросов.

## Контекст (запрос пользователя)
«Надо ребалансить — `relative_score` при оптимуме должен быть около 1.»
Источник данных — сводная таблица SCRUM-453:
`docs/design/reports/class_damage_table_3variants.md`
(генератор `tools/class_damage_table_3variants.gd`, детерминированный, seed).

`relative_score = budget_score класса / медиана budget_score по всем классам`
внутри одного build-тира (генератор, `_relative_score`). Коридор флагов сейчас
`OUTLIER_LOW=0.85` / `OUTLIER_HIGH=1.15`.

## Цель
Для тира **«Lvl20 optimum»** привести `relative_score` КАЖДОГО из 17 классов
к **≈1.0** (жёсткий коридор приёмки **0.90–1.10**, без флагов HIGH/LOW при оптимуме).

## Текущие выбросы при Lvl20 optimum (что чинить)
**Перебор (приглушить):**
- knight — 1.510 (главный выброс)
- robot — 1.288
- dark_mage — 1.220
- (пограничные >1.10: priest 1.146, engineer 1.117, elementalist 1.109, soldier 1.083 — тоже подтянуть к 1)

**Недобор (усилить):**
- assassin — 0.590
- chemist — 0.600
- druid — 0.631
- guitarist — 0.677
- doctor — 0.734

«ok» сейчас: berserk 0.959, thief 0.997, sniper 1.020, biologist 1.000, ranger 0.966.

## Важная тонкость (диагностика PM)
- Тир **«Base lvl1» уже ≈1.0** у всех (бюджет per-class `CLASS_BUDGET_PROFILES`
  нормализует БАЗОВЫЕ статы через `progression_data.budget_tuning_for`). НЕ сломать его.
- Разъезд возникает именно при **оптимальной прокачке lvl20**: +19 очков в
  «оптимальные» статы класса масштабируют урон по-разному (у knight str/agi/endurance
  даёт крутой рост, у assassin — пологий). То есть проблема в **scaling прокачки**, а
  не в базовом бюджете. Чинить нужно так, чтобы base-тир остался ≈1, а оптимум сошёлся
  к 1 — т.е. через кривые stat→damage / kit-механику, не плоским множителем бюджета.
- По философии скилла: класс = сумма 3 оружий (kit); править геометрию/таргет/scaling
  кита, сохраняя различимые ниши трёх оружий; не сводить всё к одному множителю.

## Что крутить (точки входа)
- `scripts/progression_data.gd`: `CLASS_BUDGET_PROFILES`, `budget_tuning_for`,
  `estimate_weapon_budget_for_stats`, `derived_parameters` (stat→damage scaling).
- `scripts/class_weapon.gd` (механика оружия, если нужно менять scaling/таргет).
- Итерация: после каждой правки перегенерировать таблицу и читать колонку
  `relative_score` тира «Lvl20 optimum».

## Acceptance Criteria
- [x] Перегенерён `docs/design/reports/class_damage_table_3variants.md` (+ CSV).
- [x] Все 17 классов: «Lvl20 optimum» `relative_score` ∈ **[0.90, 1.10]**; нет флагов HIGH/LOW при оптимуме.
- [x] Тир «Base lvl1» остаётся в коридоре (не разбалансирован правками).
- [x] Тир «Lvl20 random avg» не уехал в крайности (разумные значения).
- [x] Три оружия каждого класса сохраняют различающиеся gameplay/нишу.
- [x] `runtime_smoke_test` + meta/melee/vfx смоуки зелёные; CHANGELOG + `progression_balance.md` обновлены.

## Files
- `scripts/progression_data.gd`, `scripts/class_weapon.gd`
- `tools/class_damage_table_3variants.gd` (только запуск-генерация, не менять логику метрик без причины)
- `docs/design/reports/class_damage_table_3variants.md`, `build/qa/scrum453/class_damage_table_3variants.csv`
- `docs/design/systems/progression_balance.md`, `CHANGELOG.md`

## Verification
```bash
~/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/class_damage_table_3variants.gd
# затем прочитать колонку relative_score тира «Lvl20 optimum» — все в [0.90,1.10]
~/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/runtime_smoke_test.gd
```

## Result — 2026-06-17 Back-end

Implemented SCRUM-469 through class/stat-specific growth scalars in
`CLASS_LEVEL_STAT_GROWTH_SCALARS`. The scalars apply only to stat points above a
class' base stats inside `ProgressionData.derived_parameters()`, so Base lvl1
budget tuning remains stable while lvl20 optimum growth is normalized. No
weapon geometry, target pattern, cadence, VFX, Design assets, Animator files or
class kit composition were changed.

Regenerated SCRUM-453 report/CSV:
- `docs/design/reports/class_damage_table_3variants.md`
- `build/qa/scrum453/class_damage_table_3variants.csv`

Final `Lvl20 optimum` relative scores:
`berserk 0.965`, `soldier 1.024`, `thief 1.003`, `elementalist 1.016`,
`sniper 1.027`, `priest 1.000`, `biologist 1.006`, `robot 0.969`,
`engineer 0.988`, `dark_mage 1.050`, `guitarist 1.097`,
`assassin 1.052`, `ranger 0.972`, `doctor 0.938`, `chemist 0.970`,
`knight 0.938`, `druid 0.959`.

Corridors:
- `Lvl20 optimum`: `0.938..1.097`, all ok, no HIGH/LOW flags.
- `Base lvl1`: `0.982..1.010`, all ok.
- `Lvl20 random avg`: no HIGH/LOW flags; highest observed values remain below
  the existing `1.15` outlier threshold.

Verification PASS:
- `tools/class_damage_table_3variants.gd`
- `tests/class_damage_table_3variants_test.gd`
- `tools/balance_harness.gd`
- `tests/global_damage_balance_smoke_test.gd`
- `tests/weapon_tuning_application_test.gd`
- `tests/progression_data_api_surface_test.gd`
- `tests/class_budget_profiles_integrity_test.gd`
- `tests/meta_progression_smoke_test.gd`
- `tests/melee_unique_mechanics_test.gd`
- `tests/attack_vfx_smoke_test.gd`
- `tests/runtime_smoke_test.gd`

Docs updated: `CHANGELOG.md`, `docs/design/systems/progression_balance.md`,
`docs/design/current_game_state.md`, `docs/design/mechanics_extract.md`, and
`docs/process/task_board.md`. Remaining risk: formula corridor is green, but
feel/playtest may still tune class identity in later tasks.

## QA-Вердикт (2026-06-17)
Статус: PASSED — relative_score при Lvl20-оптимуме нормализован к ≈1 для всех 17 классов

Проверено (фактически): перегенерил `tools/class_damage_table_3variants.gd` → CSV;
**все 17 классов Lvl20 optimum relative_score ∈ [0.90,1.10]** (фактический диапазон
0.938..1.097, NONE out-of-corridor); `tests/class_damage_table_3variants_test.gd` PASSED
(17 классов, 153 build-rows); runtime_smoke зелёный. Base lvl1 коридор стабилен,
geometry/VFX/kit не менялись (только `CLASS_LEVEL_STAT_GROWTH_SCALARS`).
Acceptance: [x] все пункты. Статус done → Готово.
