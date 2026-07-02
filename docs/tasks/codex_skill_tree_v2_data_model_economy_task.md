# Skill Tree v2 — Дерево умений в стиле PoE: данные, экономика метаочков, миграция (БЭК)

Статус: done
Роль: Back-end
Контур: Codex
Исполнитель: Codex
Lane: codex
Owner: backend-board-watcher-20260630T111412Z
Версия: 0.2.0
Создано: 2026-06-30
Автор: User request (PM)
Jira: SCRUM-696
Labels: foma, backend, codex
Связано: SCRUM-698 (UI), SCRUM-697 (Design), SCRUM-699 (QA)

## Контекст

Пользователь хочет ПОЛНЫЙ редизайн (с нуля) страницы меню «Древо умений». Сейчас это
4 линейные ветки (`wealth/lore/might/endure`, 40 узлов, последовательная прокачка тиров)
в `scripts/meta_progression.gd:15-63` + `scripts/ui_screens.gd:2099-2402`. Нужно сделать
ОДНО общее дерево умений в духе Path of Exile 1/2 (граф взаимосвязанных узлов с
связями-«рёбрами», прокачка от точки входа наружу), но компактнее («чуть поменьше, чем в ПоЕ»).
Ключевые требования пользователя:

1. **Глобальный уровень персонажа**, который качается, тратя **метаочки**.
2. **Метаочки начисляются за закрытие возвышений** (ascension), по формуле (см. ниже).
3. **Максимум 100 метаочков** суммарно.
4. **Дерево общее** для всех персонажей (как сейчас — `skill_nodes` единый массив), НО
   **точка входа в дерево у разных персонажей в разных местах** (как стартовые узлы классов
   на общем дереве пассивок в ПоЕ).

Эта задача — БЭК-фундамент (данные дерева + экономика + правила выделения + миграция сейва).
UI-перерисовка экрана — отдельный таск (`skill_tree_v2_ui_redesign`, lane=claude, `ui_screens.gd`),
он потребляет API из этой задачи. Эта спека — канонический источник модели данных; UI/Art/QA
ссылаются на неё.

## Экономика метаочков (точная формула)

Метаочко (`meta_points`) — единственная валюта дерева. UI-название: «Метаочки».

Начисление — за ПЕРВОЕ закрытие (победа над боссом на данном уровне возвышения) каждого
уровня возвышения, ПО КАЖДОМУ персонажу (возвышения 0..5, `MAX_ASCENSION_LEVEL=5`):

| Закрыто возвышение | Метаочков |
|---|---|
| 0 (нулевое) | +1 |
| 1 (первое)  | +1 |
| 2 (второе)  | +2 |
| 3 (третье)  | +3 |
| 4 (четвёртое) | +4 |
| 5 (пятое)   | +5 |

- Максимум с одного полностью пройденного персонажа = 1+1+2+3+4+5 = **16 метаочков**.
- Начисление ТОЛЬКО за первое закрытие уровня (как уже устроено в `record_boss_victory()`,
  `meta_progression.gd:313-343` — нельзя фармить один уровень).
- **Жёсткий потолок суммарного заработка = 100 метаочков** (`META_POINTS_CAP=100`).
  Заработанное сверх 100 не начисляется. С ~16 классами потолок реально достижим и является
  эндгейм-целью.

### Глобальный уровень персонажа
- «Глобальный уровень» = число ВЫДЕЛЕННЫХ (купленных) узлов дерева (каждое выделение = +1
  уровень), по аналогии с уровнем персонажа в ПоЕ ≈ числу вложенных пассивок.
- Бюджет уровней ограничен заработанными метаочками (cap 100). Показывать в шапке экрана как
  «Уровень {allocated} / {earned}» или «Уровень {allocated}» + отдельный счётчик доступных
  метаочков (точную подачу финализирует UI-таск).
- Доступные к трате метаочки = `earned_meta_points(state) - sum(cost выделенных узлов)`.

## Модель данных нового дерева

Заменить линейный `SKILL_TREE` графовой моделью (общее дерево). Предлагаемая схема узла:

```gdscript
{
  "id": "node_xyz",            # уникальный id
  "pos": Vector2(x, y),        # координаты на холсте дерева (для рендера и раскладки)
  "cost": 1,                   # метаочков за выделение (мелкие узлы = 1)
  "kind": "minor",             # minor | notable | keystone
  "title": "…",                # рус. название
  "desc": "…",                 # рус. описание эффекта
  "effects": { … },            # боевые модификаторы (как сейчас, совместимо со skill_modifiers())
  "adj": ["node_a", "node_b"], # рёбра (неориентированные связи с соседями)
}
```

- **Точки входа классов**: новая карта `CLASS_ENTRY_NODES = { "<character_id>": "<node_id>", … }`
  для всех ~16 классов (`progression_data_characters.gd` CHARACTER_CONFIGS). Каждый класс
  «входит» в общее дерево в своём узле-старте (разные места дерева).
- **Правила выделения (allocation):**
  - Узел можно выделить, если: (а) это узел-вход любого ОТКРЫТОГО игроком класса (корень),
    ИЛИ (б) он соседствует (есть ребро) с уже выделенным узлом — связность как в ПоЕ.
  - Хватает доступных метаочков (cost) и не превышен cap 100.
  - (Опц., на усмотрение реализации) сброс/возврат: либо без возврата, либо кнопка
    «Сбросить дерево» с полным рефандом — согласовать с UI-таском; по умолчанию реализовать
    полный сброс-рефанд (дёшево и удобно для теста баланса).
- **Размер дерева («чуть поменьше ПоЕ»)**: ориентир ~60–90 узлов: преимущественно `minor`
  (cost 1, маленькие приросты), вкрапления `notable` (cost 2–3, заметные эффекты) и 3–6
  `keystone` (cost 3–5, сильные «правило-меняющие» эффекты). Суммарная стоимость полного
  выделения должна быть близка к 100 (cap = эндгейм). Топология: общий «ствол/хабы» в центре,
  узлы-входы классов разнесены по периметру/секторам, сектора тематически связаны с сильными
  сторонами классов (но дерево едино, можно дойти куда угодно через связность).
- Эффекты узлов сохраняют совместимость с `skill_modifiers()` — боевые бонусы применяются
  как раньше. Можно переиспользовать существующие ключи эффектов (`damage_multiplier`,
  `max_health_flat`, `money_gain_mult`, и т.д.) из старого `SKILL_TREE`.

## Миграция сейва (`user://fantasydisk_meta.cfg`)

- Не ломать существующие сейвы. При загрузке старого стейта:
  - Старые `skill_nodes` (id из 40-узлового дерева) больше не существуют в новой схеме →
    выполнить безопасный «респек»: вернуть игроку метаочки за старые узлы (не падать, не
    оставлять «висящие» id). Простейший вариант: при несовпадении схемы сбросить `skill_nodes`
    в [] (дерево заново), метаочки пересчитать по формуле из `ascension_levels`.
  - **Пересчёт `meta_points`**: заработанные метаочки выводятся из `ascension_levels` по новой
    формуле (детерминированно), а не хранятся как накопленный счётчик прошлой механики. Старое
    поле `skill_points` (прежняя валюта дерева) — депрекейтнуть/свернуть в `meta_points`.
  - Клампы как раньше (ascension в [0..5], `meta_progression.gd:153`).
- Сделать миграцию идемпотентной и покрыть тестом (старый cfg → корректный новый стейт без
  краша, метаочки = ожидаемой сумме).

## Acceptance Criteria

- [ ] Новая графовая модель дерева в `meta_progression.gd` (или новом `skill_tree_data.gd`):
      узлы с `pos/cost/kind/title/desc/effects/adj`, ~60–90 узлов, 3–6 keystone.
- [ ] `CLASS_ENTRY_NODES` — карта точек входа для ВСЕХ классов из CHARACTER_CONFIGS; каждый
      класс входит в разном узле; все id валидны и присутствуют в дереве.
- [ ] Экономика метаочков: начисление по формуле (0→1,1→1,2→2,3→3,4→4,5→5) при первом
      закрытии возвышения; cap 100; функция `earned_meta_points(state)` детерминированна.
- [ ] Правила выделения: корни = узлы-входы открытых классов; рост по связности (`adj`);
      проверка бюджета и cap; функция статуса узла (`locked|available|purchased`) под новую модель.
- [ ] `buy_skill_node()` / новое `allocate_node()` тратит метаочки, уважает cap и связность,
      сохраняет стейт (`save_state()` атомарно как сейчас).
- [ ] Полный сброс/рефанд дерева (`reset_tree()` или аналог) — по умолчанию доступен.
- [ ] `skill_modifiers()` отдаёт корректные суммарные эффекты выделенных узлов (боевые бонусы
      применяются в бою без регрессий).
- [ ] Миграция старого сейва не падает; метаочки пересчитаны из `ascension_levels`; старые
      `skill_nodes` безопасно сброшены/перенесены.
- [ ] Юнит/смоук-тест `meta_skill_tree_smoke_test.gd` обновлён под новую модель и ЗЕЛЁНЫЙ:
      формула начисления, cap=100, связность выделения, точки входа, миграция, отсутствие
      «висящих» id, бюджет полного дерева ≈ 100.
- [ ] Публичный API стабилен и задокументирован в этой спеке для UI-таска (функции: статус узла,
      выделить узел, сбросить, доступные/заработанные метаочки, глобальный уровень, карта входов,
      перечень узлов с pos/adj для рендера).

## Files

- `scripts/meta_progression.gd` — модель дерева, экономика, правила выделения, миграция, API
  (или вынести дерево в новый `scripts/skill_tree_data.gd` и подключить).
- `scripts/progression_data_characters.gd` — id классов для `CLASS_ENTRY_NODES` (только чтение).
- `scripts/main.gd` — `record_boss_victory()` интеграция начисления (точка `main.gd:963` ascension).
- `tests/meta_skill_tree_smoke_test.gd` — обновить под новую модель.

## Заметки по lane/изоляции

- Lane=codex. Единоличный владелец `meta_progression.gd` в рамках этой волны (UI-таск НЕ трогает
  `meta_progression.gd`, только зовёт API; арт/QA не трогают логику). Перед сдачей — влить в
  origin/dev (НЕ оставлять на codex/-ветке), см. правило codex-strand.

## QA-Вердикт
Статус: PASSED

QA claude-qa, 2026-06-30. Проверено на HEAD origin/dev (dd43b63e — ancestor origin/dev, не strand).

Тесты (godot_gate flock-семафор, Godot 4.7) — все ЗЕЛЁНЫЕ:
- `res://tests/meta_skill_tree_smoke_test.gd` — граф/adj без висящих id, точки входа всех 17 классов уникальны+валидны, статусы locked/available/purchased по связности, persist, миграция-респек + пересчёт метаочков, полный бюджет дерева.
- `res://tests/meta_points_per_ascension_test.gd` — формула 0..5 = 1/1/2/3/4/5, без фарма повторов, endcap +5 на L5 = 16/класс, общий cap=100, class_boss_wins независим.
- `res://tests/meta_progression_smoke_test.gd` — PASS.
- `res://tests/runtime_smoke_test.gd` — PASS (без регрессий).

Все Acceptance Criteria подтверждены в `scripts/meta_progression.gd` (85 узлов/5 keystone, CLASS_ENTRY_NODES для всех классов, экономика+cap, правила выделения, allocate/reset/skill_modifiers, миграция schema v2, публичный API для SCRUM-698).

## Результат (2026-06-30, backend Codex)

SCRUM-696 backend foundation implemented in `scripts/meta_progression.gd`.

- Replaced the old linear backend model with Skill Tree v2 graph data: 85 nodes, 5 keystones, full-tree cost `100`, node fields `id/branch/tier/cost/kind/title/desc/effects/pos/adj`, symmetric undirected adjacency, and `CLASS_ENTRY_NODES` for every playable class id in `ProgressionDataCharacters.CHARACTER_CONFIGS`.
- Meta point economy is now deterministic from first clears: ascension clear `0..5` awards `1,1,2,3,4,5`, repeats do not farm, and total earned points clamp at `META_POINTS_CAP = 100`. Ascension level unlock behavior remains capped at `MAX_ASCENSION_LEVEL = 5`; first clear of selectable ascension 5 grants the endcap +5 once without increasing the stored ascension level above 5.
- Public UI/API surface: `node_list()`, `entry_map()`, `node_status(state, node_id)`, `allocate_node(state, node_id)`, `reset_skill_tree(state)`, `earned_meta_points`, `available_meta_points`, `allocated_meta_points`, `global_level`, `skill_tree_total_cost`. Compatibility wrappers remain: `buy_skill_node()` delegates to allocation; `skill_points()` returns available meta points for the current UI.
- Save migration: schema `skill_tree_schema = 2`; old saves without v2 schema safely respec `skill_nodes`, reconstruct `meta_point_awards` from `ascension_levels`, and ignore legacy `skill_points` farm values. Existing codex/class challenge/class progression save fields are preserved.
- Docs updated: `docs/design/mechanics_extract.md` and `docs/design/current_game_state.md`.

Verification:
- `python3 tools/godot_gate.py --headless --path . --script res://tests/meta_skill_tree_smoke_test.gd` — PASS.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/meta_points_per_ascension_test.gd` — PASS.
- `python3 tools/godot_gate.py --headless --path . --script res://tests/meta_progression_smoke_test.gd` — PASS.

Disk cleanup: none created.
