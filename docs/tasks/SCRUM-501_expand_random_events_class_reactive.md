# SCRUM-501: Расширение пула случайных событий +5 сценариев с классовой реактивностью

Jira: SCRUM-501 · Роль: backend · Контур: claude · Приоритет: P2 · foma · Эпик: (не указан в тикете)
Статус: done (QA PASSED, Codex QA `codex-qa-501-20260628190507`, 2026-06-28)

## QA-Вердикт 2026-06-28

Статус: PASSED

Verdict: PASSED on a clean worktree from `origin/dev` (`C:\Users\FomaE\FantasyDisk_agents\qa_501_20260628190507`); fresh SCRUM-501 commit `cce17cbf` is present.

Checks:
- `tests/event_data_contract_check.gd` PASS: `pool=28`, `combat=17`, `reward=20`, `rest=10`, `check=30`, `class_reactive=5`.
- `tests/event_data_smoke_test.gd` PASS: 28 events, EV invariant checked on 12 risky/safe pairs.
- `tests/event_choices_empty_pool_test.gd` PASS.
- `tests/event_random_artifact_empty_pool_test.gd` PASS.
- `tests/event_risk_reward_ev_test.gd` PASS: 17 risky/safe pairs, 0 violations.

Full `tests/runtime_smoke_test.gd` was run after headless import and failed on an unrelated autosave check: `Expected New Game choice to clear existing autosave` (`tests/runtime_smoke_test.gd:2452`). Separate bug created: `SCRUM-653`; this does not block SCRUM-501 event-data acceptance.

## Что и зачем

Цель — сделать event-узлы менее предсказуемыми и более «персональными».

Сейчас в пуле ровно 12 сценариев (`scripts/event_data.gd`). За один акт маршрут даёт до ~10 рядов активностей, события встречаются регулярно, и пул исчерпывается за один-два акта. После исчерпания `pick_event` сбрасывает список использованных id — игрок начинает видеть те же 12 сценариев по кругу, исходы запоминаются, событие перестаёт быть «решением» и превращается в рутинный клик.

Что нужно игроку:
1. Больше разнообразия — добавить 5 новых сценариев (пул 12 → 17), чтобы повтор внутри акта стал реже, а узнавание исхода — медленнее.
2. Персональность — минимум 2 новых сценария должны давать РАЗНЫЙ исход в зависимости от архетипа/главного атрибута героя. Танк, маг и призыватель должны проходить «свою» проверку легче (бонус сильнее для своего архетипа), мискласс — рисковать или получать слабее. Это создаёт ощущение, что мир реагирует на то, КЕМ ты играешь, а не только на цифры.

Ожидаемый результат: 17 уникальных data-driven событий, из которых ≥2 ветвят исход по главному атрибуту класса, все новые платные/риск/check-варианты следуют существующим контрактам экономики и безопасности, документация и smoke-тест обновлены, runtime smoke зелёный.

## Текущее состояние в коде

### Источник данных — `scripts/event_data.gd`
- `const RANDOM_EVENTS := [...]` (строки 3–115) — массив из 12 событий. Каждое событие: `{id, title, story, choices: [...]}`.
- Каждый choice — словарь с подмножеством поддерживаемых ключей (см. контракт ниже).
- Хелперы (статические):
  - `event_ids()` (118) — список id.
  - `event_by_id(event_id)` (125) — глубокая копия события по id.
  - `pick_event(used_ids, rng)` (132) — выбирает событие, которого нет в `used_ids`; если все использованы — `used_ids.clear()` и берётся из полного пула. Non-repeat-логика «на акт» держится именно здесь через `used_ids`.

### Поддерживаемые механики choice (контракт резолвера) — `scripts/ui_screens.gd` (LOCKED PATH, не редактировать без необходимости)
Резолвер `_resolve_event_choice_outcome(event_choice, temp_player)` (5289) и применение `_apply_event_outcome_to_player(outcome, temp_player)` (5308) понимают ТОЛЬКО эти ключи. Любой новый ключ в данных будет проигнорирован.

- `cost_money: int` — списывается через `PROGRESSION_DATA.stage_scaled_cost(cost, route_stage)`. Если денег не хватает — outcome возвращает `false`, run-деньги сохраняются (см. `_apply_event_outcome_to_player`, 5309–5311).
- `money: int` — `gain_money`.
- `stats: {stat_id: delta}` — применяется через `apply_reward({kind:"event", stats, mods, heal_percent})` (5316–5323).
- `mods: {mod_id: value}` — run_modifiers; поддержанные id см. `player.gd:run_modifiers` (124–145): `damage_multiplier`, `attack_speed_multiplier`, `xp_gain_multiplier`, `money_gain_multiplier`, `healing_multiplier`, `defense_flat`, `summon_bonus`, `move_speed_multiplier`, `max_health_multiplier`, `enemy_health_multiplier` и т.д.
- `heal_percent: float` — лечение в долях max_health.
- `health_percent_cost: float` — потеря HP в долях max_health, минимум 1 HP остаётся (5330–5332).
- `random_artifact: true` — берёт 1 артефакт из `PROGRESSION_DATA.reward_pool(character_id)` (filter kind=="artifact") через `_weighted_sample` (5324–5329).
- `reward: {...}` — прямой `apply_reward`.
- `check: {stat, difficulty}` + `success: {...}` / `failure: {...}` — `passed = stats[stat] >= difficulty`; merge соответствующей ветки в outcome; ставит `check_passed` (5296–5304). ВАЖНО: `stat` — ЛИТЕРАЛЬНЫЙ id атрибута, резолвер НЕ преобразует его в «главный атрибут класса» динамически.
- `combat: {type, enemy_health_multiplier, money_multiplier, xp_multiplier}` + `post_combat: {...}` — стартует обычный/элитный бой с `pending_event_combat`; post_combat применяется после победы (`combat_director.gd:885–886`).
- `risk: true` — только UI-метка («Риск: …»), на исход не влияет.
- `random_outcomes: [ {...}, ... ]` — резолвер выбирает один случайно и merge'ит в outcome (5291–5295). Может содержать любой из ключей выше, включая `combat`.

### UI/безопасность — `scripts/ui_screens.gd`
- `_show_event_screen(route_node)` (4996) рисует экран. Платный choice дизейблится при нехватке золота и дописывает tooltip «Недостаточно золота: нужно X, есть Y» (5030–5034).
- `_event_choice_scaled_cost` (5241) — stage-scaled цена только из `cost_money`.
- Anti-soft-lock + клавиатура/геймпад фокус (SCRUM-477): все доступные опции фокусируемы, фокус-цепочка стрелками, фокус ставится на первую выбираемую опцию (5070–5079). Кнопка «Назад» disabled, если skip не разрешён и есть хоть один доступный выбор.
- `class_main_attribute(character_id)` (`progression_data.gd:151`) ВОЗВРАЩАЕТ главный атрибут класса (data из `progression_data_characters.gd:CLASS_MECHANIC_IDENTITIES`), но в event-резолвере СЕЙЧАС НЕ используется (grep: единственное упоминание — само определение). То есть динамической «реакции на главный атрибут» в коде нет; класс-реактивность придётся выразить через ЛИТЕРАЛЬНЫЕ stat-checks (см. план).

### Главные атрибуты классов (источник класс-реактивности) — `progression_data_characters.gd:CLASS_MECHANIC_IDENTITIES` (288+)
- strength: `berserk`
- agility: `thief`, `assassin`, `druid`(нет — druid=leadership), `guitarist`(нет)… точные:
  - strength → berserk
  - perception → soldier, sniper, ranger
  - agility → thief, assassin
  - intelligence → elementalist, dark_mage, chemist
  - knowledge → priest, biologist, doctor
  - endurance → robot, knight
  - leadership → engineer, guitarist, druid
- Базовые характеристики (current_game_state.md, табл. ~761): танки (knight/robot) End 10; маги (elementalist/chemist Int 9, dark_mage Int высок.) Int 8–9; призыватели (engineer/druid Lead 10) Lead 10. Это значит: check по `endurance`/`intelligence`/`leadership` с difficulty 7–8 «свой» класс проходит почти всегда, а чужой — часто валит. Это и есть рабочий способ сделать класс-реактивность БЕЗ изменения резолвера.

### Smoke-тест — `tests/runtime_smoke_test.gd`
- `_test_random_event_data_and_outcomes` (2228) — ГЛАВНЫЙ контракт-гейт для данных. Жёсткие требования:
  - `RANDOM_EVENTS.size() >= 10` (2229) — с 17 ок.
  - id непустые и уникальные (2238–2242).
  - title непустой; `story.length() >= 40` символов (2243–2244).
  - у каждого события `choices.size() >= 2` (2246–2249).
  - суммарно по пулу: `combat_outcomes >= 3`, `reward_outcomes >= 3` (random_artifact/reward/money, в т.ч. nested), `rest_outcomes >= 1` (heal_percent), `check_outcomes >= 2` (2250–2261). Новые события не должны это ломать (это нижние границы — добавление только помогает).
  - non-repeat picker: прогон на весь размер пула без повторов (2263–2272).
  - дубль-префикс «Риск: Риск:» запрещён; risk-choice должен начинаться с «Риск:» (2332–2340) — для risk-варианта НЕ начинай `description` со слова «Риск:» (резолвер добавит сам) ИЛИ начни ровно с «Риск:».
  - проверка success/failure ветвления (2341–2362): тест ставит все статы = 12 (success) и обнуляет проверяемый стат (failure). Любой новый `check` обязан проходить при стате 12 и валиться при 0 → difficulty держи в диапазоне 1..12.
- Тест клиента события `_test_event_route_node_click` (1839) использует фикс. `event_id: "hot_spring"` — НЕ переименовывать существующие id.

### Документация
- `docs/design/content_registry.md` (705–718) — таблица событий, сейчас 12 строк. Заголовочный текст 703.
- `docs/design/current_game_state.md` (265) — «В пуле 12 сценариев: …» + полный список id. Правила 267–275.

## Что сделать — по шагам

1. **Спроектировать 5 новых событий** под существующий контракт. Уникальные `id` (latin snake_case, не пересекаются с 12 текущими), `title`, `story` ≥40 символов, 2–3 choices каждое. Покрыть разные типы исходов (cost_money/money/stats/mods/heal_percent/health_percent_cost/random_artifact/check/combat/random_outcomes), чтобы пул оставался разнообразным и smoke-границы держались с запасом.

2. **Сделать ≥2 события класс-реактивными через литеральные stat-checks по главным атрибутам.** Поскольку резолвер не умеет «главный атрибут класса», реактивность выражается так:
   - Дать в одном событии несколько параллельных choice-веток, каждая — `check` по разному «архетипному» атрибуту (например выбор «Силовой путь» = check `strength`, «Магический путь» = check `intelligence`, «Командный путь» = check `leadership`), где «свой» класс проходит легко, чужой — рискует. Текст ветки явно адресует архетип («Танк держит удар», «Маг распутывает формулу», «Призыватель командует стаей»).
   - И/ИЛИ: один `check` по атрибуту, где `success` даёт усиленный профильный бонус (mods под архетип: `defense_flat` для танка / `damage_multiplier` для мага / `summon_bonus` для призывателя), а `failure` — мягкий штраф/слабая награда. Бонус сильнее для своего архетипа достигается тем, что свой класс почти гарантированно в success.
   - Difficulty держать 1..12 (требование smoke), целиться в 7–8: при базе End/Int/Lead 8–10 у профильных классов success почти всегда, у чужих — нет.
   - Тексты choices должны явно различать архетипы (танк vs маг vs призыватель) в `description`/`title`, чтобы «персональность» читалась игроком (AC #2).

3. **Соблюсти экономические/безопасные контракты** во всех новых платных/риск/check вариантах:
   - Платные опции — только через `cost_money` (stage-scaled и дизейбл при нехватке золота работают автоматически; новых полей цены НЕ вводить).
   - Risk-варианты: `risk: true` + корректный текст (не дублировать «Риск:»).
   - HP-жертвы — через `health_percent_cost` (доля max_health).
   - Никаких «бесплатных» обходов продвижения маршрута — не добавлять новых ключей, которые резолвер не понимает; полагаться на существующий `_apply_event_outcome_to_player`, который возвращает `false` при невозможности оплатить.

4. **Сохранить non-repeat-логику.** Ничего в `pick_event`/`event_ids`/`event_by_id` менять не нужно — они итерируют по `RANDOM_EVENTS` динамически. Просто добавить элементы в массив.

5. **Обновить документацию (пул 12 → 17):**
   - `docs/design/content_registry.md`: добавить 5 строк в таблицу событий (705–718) по образцу существующих колонок (ID / Игровое имя / Типы исходов / Ключевая роль / Статус «Реализовано»).
   - `docs/design/current_game_state.md` (265): заменить «В пуле 12 сценариев: …» на «В пуле 17 сценариев: …» и дописать 5 новых id в список. При желании дополнить правило про класс-реактивность (что часть событий ветвит исход по архетипному атрибуту).

6. **Усилить/обновить smoke (по необходимости).** Минимум — убедиться, что `_test_random_event_data_and_outcomes` проходит. Опционально добавить точечную проверку, что ≥2 события содержат архетипные check-ветки (например по наличию ≥2 разных `check.stat` среди choices одного события) — но НЕ обязателен, если усиление ломает другие фикстуры. `scripts/player.gd` менять не требуется (резолвер уже всё поддерживает) — правка player.gd допустима ТОЛЬКО если понадобится новый mod-id, но это нежелательно (см. подводные камни).

7. **Прогнать runtime smoke headless** (Godot 4.6.3 в `~/Downloads/Godot.app`, см. memory qa-test-runner) — событийный тест и event-route-click тест должны быть зелёными; grey/unclickable hardening (SCRUM-477) не нарушен.

## Acceptance Criteria

- [ ] В `scripts/event_data.gd` добавлено 5 новых сценариев с уникальными `id`, непустыми `title` и `story` (≥40 симв.), по 2–3 choice; пул стал 17.
- [ ] Non-repeat-логика на акт сохранена (`pick_event` без изменений; прогон picker по 17 элементам без повторов).
- [ ] ≥2 новых сценария ветвят исход по главному атрибуту/архетипу игрока: «свой» класс проходит профильную проверку легче и/или получает усиленный профильный бонус, текст явно различает танка/мага/призывателя.
- [ ] Все новые платные варианты используют `cost_money` (stage-scaled цена; дизейбл с tooltip при нехватке золота); HP-жертвы — `health_percent_cost`; risk-варианты помечены и без дубля «Риск: Риск:».
- [ ] Прямой вызов неоплатного платного choice безопасно возвращает `false` и не продвигает маршрут / не тратит несуществующее золото (контракт `_apply_event_outcome_to_player`).
- [ ] Никаких новых ключей в данных, которые резолвер не понимает (нет «мёртвых» полей); все исходы реально применяются.
- [ ] Каждое новое событие добавлено в таблицу `docs/design/content_registry.md` и отражено в `docs/design/current_game_state.md` (пул 12 → 17, обновлён список id).
- [ ] `tests/runtime_smoke_test.gd::_test_random_event_data_and_outcomes` проходит: combat≥3, reward≥3, rest≥1, check≥2, все check проходят при стате 12 и валятся при 0 (difficulty 1..12).
- [ ] Event grey/unclickable hardening (SCRUM-477) не нарушен: опции фокусируемы и выбираемы, фокус-цепочка работает, «Назад» корректна.
- [ ] Runtime smoke (headless Godot) зелёный целиком; существующая фикстура `event_id: "hot_spring"` не сломана (id существующих 12 событий не переименованы).

## Files / точки входа

- `scripts/event_data.gd` — добавить 5 элементов в `RANDOM_EVENTS` (3–115). Хелперы (118–144) не трогать.
- `docs/design/content_registry.md` — таблица событий (705–718): +5 строк.
- `docs/design/current_game_state.md` — строка 265 («В пуле 12 сценариев…»): счётчик 12→17 и список id; опц. правило про класс-реактивность (267–275).
- `tests/runtime_smoke_test.gd` — `_test_random_event_data_and_outcomes` (2228): убедиться, что проходит; опц. точечная проверка класс-реактивности.
- (Справочно, НЕ менять без крайней необходимости) `scripts/ui_screens.gd` — резолвер событий (`_resolve_event_choice_outcome` 5289, `_apply_event_outcome_to_player` 5308, `_show_event_screen` 4996); `scripts/player.gd:apply_reward` (693), `run_modifiers` (124).
- (Справочно) `scripts/progression_data.gd:class_main_attribute` (151), `scripts/progression_data_characters.gd:CLASS_MECHANIC_IDENTITIES` (288) — таблица главных атрибутов для проектирования класс-реактивных веток.

## Замечания / подводные камни

- **LOCKED PATHS (anti-collision):** `scripts/ui_screens.gd` и `scripts/progression_data.gd` — заблокированные/конфликтные пути; задача решается в данных (`event_data.gd`) и не требует их правок. НЕ редактировать эти файлы — резолвер уже поддерживает все нужные механики. Если кажется, что нужна правка резолвера, скорее всего исход можно выразить существующими ключами.
- **Класс-реактивность без поддержки резолвера:** резолвер НЕ умеет `check.stat == "main_attribute"` — это литеральный id атрибута. Реактивность достигается выбором атрибута проверки, совпадающего с главным атрибутом архетипа (endurance=танк, intelligence=маг, leadership=призыватель), и текстом веток. `class_main_attribute()` существует, но завязываться на него = править locked резолвер; этого избегаем.
- **Smoke difficulty-гейт:** все `check.difficulty` строго в 1..12 (тест ставит стат 12 для success и 0 для failure). Difficulty 7–8 даёт лучший «архетипный» контраст по базовым статам.
- **Risk-текст:** не начинать `description` risk-варианта со слова «Риск:» (резолвер добавит префикс) либо начать ровно с «Риск:» — иначе тест на дубль/префикс упадёт.
- **story ≥40 символов** — короткие истории валят smoke; писать атмосферно, как в существующих 12.
- **mods:** использовать только id, реально присутствующие в `player.gd:run_modifiers` (124–145). Несуществующий mod-id будет проигнорирован (мёртвое поле) и нарушит AC «нет мёртвых полей».
- **Не переименовывать существующие 12 id** — `hot_spring` зашит в `_test_event_route_node_click` (1848, 2297) и `goblin_lottery` — в тесте недоступной платной опции (2297–2312).
- **Stage-scaled экономика:** цены через `cost_money`; реальная стоимость = `stage_scaled_cost(cost, route_stage)` с `ECONOMY_PRICE_MULTIPLIER`. Базовые цены держать в диапазоне существующих событий (8–30 зол.).
- **Связанные тикеты:** SCRUM-477 (event grey/unclickable hardening — фокус/выбираемость опций), SCRUM-256 (CLASS_MECHANIC_IDENTITIES / class_main_attribute как data contract для классовой идентичности), SCRUM-188/0.1.4 экономика (stage_scaled_cost). Фриз 0.1.5 активен — это контентное расширение существующих механик, не новая фича-система, вписывается в добивание борда.
- **QA:** после правок прогнать headless runtime smoke (Godot 4.6.3 в `~/Downloads/Godot.app`), затем `jira_board_sync.py` при смене статуса.
