# Events Backend: условные и скрытые исходы для нового пака событий

Статус: done
Приоритет: p1
Роль: Back-end
Версия: 0.2.1
Создано: 2026-07-09
Jira: SCRUM-996
Контур: Claude
Owner: claude-fable-orchestrator
Thread/Worker: claude-backend-scrum996-event-outcomes
Locked paths: `scripts/ui_screens.gd` (event resolve/apply/reveal-функции), `scripts/combat_director.gd` (event shop hook), `scripts/event_data.gd` (схема/pick_event), `scripts/main.gd` (снапшот-поля событий), `tests/event_*`, `tests/runtime_smoke_test.gd` (event-блок).

## Волна оркестрации

Пакет SCRUM-995..998 (переработка событий). **Эта задача идёт первой (волна 1)** —
её схема является контрактом для контента (995) и UI (997). Параллельно в волне 1
идёт только 998 (арт, кода не трогает). Пул событий НЕ менять — это 995 (волна 2).

## Context / Problem

Текущий рантайм событий (`ui_screens.gd:8881-8975`) умеет: money/stats/mods/heal,
`cost_money`, `health_percent_cost`, `random_artifact`, стат-чек `check{stat,difficulty}`
(детерминированный порог, `:8916`), `random_outcomes`, бой `combat{...}`+`post_combat`
(потребитель `combat_director.gd:264,1146-1153`). Новому дизайну (SCRUM-995) не хватает:
скрытых/загадочных исходов с честным раскрытием ПОСЛЕ выбора, магазина после
события/после победы в событийном бою, плоского урона, act/biome-тегов. Исход сейчас
применяется молча и мгновенно — игрок не видит, что произошло.

## Required Change

Расширить data-driven схему события (все ключи опциональны, обратная совместимость
со старым пулом обязательна — пул в этой задаче не меняется):

1. **`hidden: true`** (уровень choice) — загадочный выбор. Карточка НЕ раскрывает
   исход: `_event_choice_description_text` показывает `unknown_hint` (новый опц.
   ключ choice, дефолт «Исход неизвестен…»), `_event_choice_action_text` → «Рискнуть».
2. **`outcome_text: String`** (уровень исхода: choice-корень / success / failure /
   элемент random_outcomes) — русский текст «что произошло». Обязателен для исходов
   hidden-выборов и веток check (честность раскрытия).
3. **Reveal-шаг**: если у применённого исхода есть `outcome_text` ЛИБО выбор был
   hidden ЛИБО был check — после применения исхода экран события переходит в
   состояние раскрытия: story-текст заменяется на `outcome_text` (+ строка
   «Проверка Сила 7 — пройдена/провалена» при check), карточки скрываются, появляется
   одна кнопка `EventContinueButton` («В путь») → только по ней `current_event_definition.clear()`
   + `route._advance_route_after_noncombat()`. Исходы без этих признаков сохраняют
   текущий мгновенный переход. Бой стартует как раньше без reveal (исход боя — сам бой).
   Фокус/геймпад: фокус на кнопке продолжения (цепь SCRUM-477 не ломать).
4. **`damage_flat: int`** (уровень исхода) — прямой урон HP, пол 1 HP (не летально,
   консистентно с `health_percent_cost`, `:8972`).
5. **`shop_after: true`** (уровень исхода И внутри `post_combat`) — после применения
   исхода (и reveal-подтверждения) открыть магазин `_show_shop_screen()`; выход из
   магазина ведёт к штатному `_advance_route_after_noncombat()`. Для `post_combat.shop_after`
   — после наград за победу в событийном бою открыть магазин перед возвратом на карту.
   Опциональный `shop_discount: float` (0..1) — если реализуемо дёшево через
   существующий прайсинг магазина; иначе зафиксировать в доке как «не поддержано».
6. **`tags: {"acts": Array[int], "biomes": Array[String]}`** (уровень события) —
   future-ready теги. `pick_event(used_ids, rng, context := {})`: если у события
   непустой `acts` и в context передан `act` — событие допустимо только при
   совпадении; пустые теги = любой акт (текущее поведение не меняется, вызовы без
   context работают как раньше).
7. Снапшот/автосейв: reveal-состояние и shop_after опираются на существующую
   семантику снапшота (исход применяется на temp_player → снапшот, автосейв только
   в `_advance_route_after_noncombat`); выход из игры до подтверждения reveal =
   откат к последнему автосейву с повторным входом в то же событие (SCRUM-530,
   без реролла) — это норма, задокументировать. Новые поля в сейв добавлять только
   если без них ломается restore (обосновать в коммите).

## Acceptance Criteria (Jira)

- Рантайм детерминированно резолвит видимые и скрытые исходы из данных события.
- Чек Strength/Agility и т.п. ветвит success/failure (порог, существующая механика).
- Выбор может запускать бой и применять post-combat награды ИЛИ магазин после победы.
- Исход может применять прямой урон, золото, статы, артефакты или ничего — безопасно.
- UI умеет показывать «неизвестный» текст выбора, не раскрывая исход (hidden/unknown_hint).
- Сейв/автосейв и возврат на маршрут стабильны после резолва события.
- Тесты покрывают: успех, провал, скрытый исход, боевой исход, магазин-после-события,
  применение наград.

## Тесты / Verification

- Новый `tests/event_outcomes_runtime_test.gd` (SceneTree, по образцу соседних):
  check success/failure, hidden+reveal (outcome_text доступен, карточки скрыты,
  continue завершает событие), combat-исход (`pending_event_combat`+`post_combat`),
  shop-after-event (магазин открылся, выход → advance), shop-after-combat-victory,
  `damage_flat` пол 1 HP, money/stats/artifact применение, `current_event_definition`
  очищен после завершения.
- `tests/event_data_contract_check.gd`: разрешить новые ключи (hidden, unknown_hint,
  outcome_text, damage_flat, shop_after, tags), валидировать их типы; существующий
  пул остаётся валиден.
- `tests/runtime_smoke_test.gd` `_test_random_event_data_and_outcomes` (:2571):
  обновить прогон под reveal-шаг (докликивать EventContinueButton), инвариант
  «пул ≥10 событий» не трогать.
- Прогоны ТОЛЬКО через `python3 tools/godot_gate.py --headless --path . --script res://tests/<t>.gd`.
- Зелёный гейт: runtime_smoke + все event-тесты 2 прогона подряд.

## Files

`scripts/ui_screens.gd` (:8458-8560 показ — минимально, :8850-8878 тексты карточек,
:8881-8975 resolve/apply + новый reveal), `scripts/combat_director.gd` (:264-284,
:1146-1153 shop_after hook), `scripts/event_data.gd` (:300-326 pick_event context +
док-коммент схемы), `scripts/main.gd` (только при доказанной нужде в сейв-поле),
`tests/*`, `docs/design/systems/menus_ui.md` (§Event: reveal-контракт),
`docs/design/systems/persistence.md` (абзац о reveal/shop_after и автосейве).

## Definition of Done

Зелёный гейт → push в origin/dev → Jira SCRUM-996 «Контроль качества» + комментарий
с итогом → этот файл `Статус: done`.

## QA-Вердикт

Статус: PASSED
Проверил: claude-fable-orchestrator, 2026-07-09.
Верификация HEAD в worktree: event_data_contract_check (pool=29, новые ключи
типизированы), event_data_smoke_test, event_outcomes_runtime_test (все ветки AC:
check S/F, hidden+reveal, damage_flat пол 1 HP, shop_after событие/победа, награды,
очистка current_event_definition) — PASSED; runtime_smoke_test ×2 подряд — passed
(шум _try_capture_weapon_select_screenshot — известный headless-артефакт). Обратная
совместимость со старым пулом подтверждена зелёными старыми тестами. AC закрыты.

## Итог

Реализовано и запушено в origin/dev пятью коммитами (18022681 схема event_data +
pick_event(context) c act-фильтром; 430ede8a рантайм: hidden/unknown_hint («Рискнуть»),
reveal-шаг (EventStory=outcome_text + строка «Проверка … — пройдена/провалена»,
карточки/Назад скрыты, EventContinueButton с фокусом), damage_flat (пол 1 HP),
shop_after/shop_discount после события и после победы событийного боя с выходом
магазина в advance/combat-возврат; 02133dcc тест event_outcomes_runtime_test.gd —
все ветки AC; bda26302 contract_check типизирует новые ключи + честность hidden,
runtime_smoke докликивает reveal, инвариант «≥10 событий» сохранён; ad7e3445 доки
menus_ui §Event + persistence). Пул RANDOM_EVENTS не тронут (заменит SCRUM-995).
Воркер отчитался о двойном зелёном гейте; оркестратор перепроверил HEAD:
contract_check / event_data_smoke / event_outcomes_runtime — PASSED, runtime_smoke
— двойной прогон (см. QA-Вердикт).
