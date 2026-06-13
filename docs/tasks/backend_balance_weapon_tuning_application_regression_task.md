# Back-end Task: Weapon Budget Tuning Application Regression

Статус: done (2026-06-13, Claude Fable 5)
Версия: 0.1.4
Создано: 2026-06-13
Автор: Back-end audit SCRUM-176
Jira: SCRUM-191
QA: passed (2026-06-13)
Эпик: epic_full_project_quality_pass

## Scope

Ensure all weapon runtime paths receive `ProgressionData.weapon()` configs with budget tuning applied.

## Requirements

- For every class+weapon, instantiate player, equip weapon and assert derived damage includes `budget_damage_multiplier`.
- Guard against bypassing `ProgressionData.weapon()` with raw `WEAPONS_BY_CLASS` dictionaries.

## Verification

- Runtime smoke or focused weapon config test passes.

## Done (2026-06-13)
`tests/weapon_tuning_application_test.gd` — три гейта: (1) реестр `ProgressionData.weapon()` добавляет `budget_damage_multiplier`/`budget_tuning`, а сырой `WEAPONS_BY_CLASS` их НЕ несёт (обход отлавливается); (2) деривация — `damage/magic_damage/sound_wave_damage` масштабируются ровно множителем (ratio == budget_damage_multiplier); (3) рантайм — реальный `Player.configure_character` кладёт тюненный конфиг в `weapon_config`, equip не обходит `weapon()`. Анти-вакуум: ≥9 пар, ≥1 нетривиальный множитель. Headless зелёный: 51 пара, все 51 с множителем != 1.0.

## Dispatcher Note (2026-06-13)
Dispatched to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` after user confirmed no feature freeze / backlog is eligible.
Dispatcher: restarted to Back-end thread `019eabd9-780b-78a2-9f4b-e7203d659ef2` on 2026-06-13 after PM reset stale in_progress.

## QA-Заметка (2026-06-13) — BLOCKED, не сертифицировано
Статус QA: BLOCKED (повторить после стабилизации дерева)

Что подтверждено в КОНСИСТЕНТНОМ окне дерева:
- Целевой тест `weapon_tuning_application_test.gd` — **PASS (51 пара, все 51 с
  нетривиальным множителем != 1.0)**, 3 гейта (реестр vs сырой WEAPONS_BY_CLASS,
  деривация ratio==budget_damage_multiplier, рантайм через Player.configure_character).
  Содержательный, не пустышка.

Почему BLOCKED (не PASS):
- Рабочее дерево в момент QA **non-green из-за активного рефактора SCRUM-198**
  (ProgressionData domain split). git status: модифицированы `progression_data.gd`,
  `class_weapon.gd`, `ui_screens.gd`; новые `progression_data_{ascension,balance,
  characters,enemies,shop}.gd`. HEAD быстро двигался (fa66cf37 → 31bc8c61 за
  минуты).
- QA поймал ДВА транзиентных окна, где `scripts/player.gd` не парсится/не
  компилируется (`Static function "weapon()"/"base_stats()"/… not found in base
  "ProgressionData"`), из-за чего `runtime_smoke_weapon_mechanics_test`,
  `melee_weapon_targeting_test` и др. не загружались. animation/meta при этом
  проходили.
- По правилу «done=HEAD зелёный» нельзя сертифицировать регрессию на дереве,
  которое осциллирует red/green под активным воркером. По случайно пойманному
  зелёному окну сертифицировать отказался.

Действие: **повторить QA SCRUM-191 после того, как SCRUM-198 закоммитит единый
green-стейт.** Собственный тест задачи уже зелёный — ожидаю, что после
стабилизации будет clean PASS.

Координационный риск зафиксирован в QA-заметке SCRUM-198 и эскалирован PM.

## QA-Вердикт (2026-06-13)
Статус: PASSED
Коммит: 9d9cd15b (ветка dev)

Дерево SCRUM-198 устаканилось в стабильное зелёное окно — блокер снят, перепроверено.

Проверено (фактически, ДВА полных прохода подряд, оба зелёные — не lucky-окно):
- Целевой `weapon_tuning_application_test.gd` — PASS ×2 («51 пар, 51 с
  нетривиальным множителем != 1.0»). 3 содержательных гейта: реестр
  `ProgressionData.weapon()` несёт `budget_damage_multiplier` (а сырой
  `WEAPONS_BY_CLASS` — нет, обход ловится); деривация `ratio ==
  budget_damage_multiplier`; рантайм через реальный `Player.configure_character`.
- Регрессия ×2: `runtime_smoke_weapon_mechanics_test`, `melee_weapon_targeting_test`,
  `animation_smoke_test`, `meta_progression_smoke_test` — все зелёные оба прохода.

Acceptance:
- [x] Каждый class+weapon получает тюненный конфиг через `weapon()` (51 пара, все
  с множителем != 1.0).
- [x] Обход сырым `WEAPONS_BY_CLASS` отлавливается (гейт 1).
- [x] Focused weapon config test + регрессия зелёные.

Краевые случаи:
- Стабильность подтверждена двумя проходами (ранее ловил транзиентную churn
  SCRUM-198 — теперь её нет).

Баги: нет.
