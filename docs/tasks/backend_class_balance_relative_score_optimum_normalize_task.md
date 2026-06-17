# BALANCE: Нормализовать relative_score при lvl20-оптимуме к ≈1 для всех классов

Статус: in_progress
Приоритет: high
Роль: Back-end (баланс)
Исполнитель: Codex (скилл fantasydisk-class-balance-director)
Версия: 0.1.6
Создано: 2026-06-17
Автор: PM (запрос пользователя)
Jira: SCRUM-469

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
- [ ] Перегенерён `docs/design/reports/class_damage_table_3variants.md` (+ CSV).
- [ ] Все 17 классов: «Lvl20 optimum» `relative_score` ∈ **[0.90, 1.10]**; нет флагов HIGH/LOW при оптимуме.
- [ ] Тир «Base lvl1» остаётся в коридоре (не разбалансирован правками).
- [ ] Тир «Lvl20 random avg» не уехал в крайности (разумные значения).
- [ ] Три оружия каждого класса сохраняют различающиеся gameplay/нишу.
- [ ] `runtime_smoke_test` + meta/melee/vfx смоуки зелёные; CHANGELOG + `progression_balance.md` обновлены.

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
