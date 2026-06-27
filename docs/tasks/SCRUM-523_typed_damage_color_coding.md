# SCRUM-523: Суммарный урон по типам + цветовая кодировка в UI

Jira: SCRUM-523 · Роль: backend · Контур: claude · Приоритет: P1 · foma · Эпик: SCRUM-522 (Ребаланс боёвки и прогрессии)
Статус: В работе

## Что и зачем

Урон по монстру в FantasyDisk складывается из РАЗНЫХ типов: физический, магический,
периодический (DoT), звуковой и чистый (true). Игрок должен **видеть вклад каждого
типа** — итоговый урон по цели = сумма всех типизированных попаданий, а каждая боевая
цифра окрашена в СТАБИЛЬНЫЙ цвет своего типа (цвет привязан к типу урона, НЕ к классу/
оружию). Так бой читается одинаково во всех схватках и на всех экранах: золотой удар —
физика, фиолетовый — магия, зелёный — DoT, голубой — звук, белый — чистый.

Зачем это важно продукту:
- читаемость боя: игрок понимает, какой канал урона работает (важно для билда/выбора
  атрибутов — связано с SCRUM-524 «изоляция атрибутов по типу»);
- единая палитра как источник правды: одни и те же цвета в плавающих цифрах над врагом
  и в любых будущих UI-индикаторах урона, без рассинхрона;
- задокументированная палитра, которую переиспользуют все системы (player/enemy/UI).

Ожидаемый результат: при бое цифры урона окрашены по типу из ЕДИНОЙ палитры; класс-
оружие, DoT, ультимейты и рефлекты — все проставляют корректный тип; дубль палитры
устранён; палитра задокументирована; `runtime_smoke` зелёный.

## Текущее состояние в коде

Система типов урона уже ЧАСТИЧНО заложена (предыдущая итерация), но НЕ доведена —
есть дубль палитры, и большинство классовых попаданий не проставляют тип.

**Канонная палитра + типы (источник правды) — `scripts/player.gd:53-77`:**
- константы типов: `DAMAGE_TYPE_PHYSICAL="physical"`, `DAMAGE_TYPE_MAGIC="magic"`,
  `DAMAGE_TYPE_DOT="dot"`, `DAMAGE_TYPE_SOUND="sound"`, `DAMAGE_TYPE_TRUE="true"`;
- `const DAMAGE_TYPE_COLORS := {...}` (строки 65-71): physical `Color(1.0,0.84,0.42,1)`,
  magic `Color(0.68,0.46,1.0,1)`, dot `Color(0.46,1.0,0.42,1)`, sound `Color(0.30,0.86,1.0,1)`,
  true `Color(1,1,1,1)`;
- `static func damage_type_color(damage_type) -> Color` (строки 76-77) — единый доступ,
  fallback на `true` (белый) для неизвестного типа.

**Player наносит типизированный урон и САМ рисует цветную цифру:**
- `_deal_typed_damage(enemy, amount, damage_type)` — `scripts/player.gd:1147-1153`:
  вызывает `enemy.take_damage(amount)` (1 аргумент!) и затем
  `_spawn_combat_number(enemy.global_position, amount, damage_type)`.
- `_spawn_combat_number(world_position, amount, damage_type)` — `scripts/player.gd:1189-1213`:
  создаёт `Label`, `label.modulate = damage_type_color(damage_type)`, твин-всплытие.
- `_apply_ultimate_damage(enemy, amount, damage_type)` — `scripts/player.gd:1230-1237`:
  тоже `enemy.take_damage(final_amount)` (1 арг) + свой `_spawn_combat_number(...)`.
- `_damage_enemies_in_radius(..., damage_type)` — `scripts/player.gd:1138-1140` — прокидывает тип в ultimate.
- Вызовы с типом: counter/thorns `DAMAGE_TYPE_PHYSICAL` (строки 650, 664), ульты магов/
  гитариста `DAMAGE_TYPE_MAGIC`/`DAMAGE_TYPE_SOUND` (строки 904, 915, 947, 952, 976, 995, 1098, 1112).

**ВТОРАЯ (дублирующая) палитра во враге — `scripts/enemy.gd:91-97`:**
- `const COMBAT_FEEDBACK_DAMAGE_COLORS := {...}` — почти копия player-палитры, НО
  расходится: `"true": Color(1.0,0.96,0.82,1.0)` (тёплый белый) против player `Color(1,1,1,1)`.
- `take_damage(amount, feedback := {})` — `scripts/enemy.gd:228-262`: читает
  `feedback["damage_type"]` (строка 274, default `"true"`), красит цифру через
  `COMBAT_FEEDBACK_DAMAGE_COLORS.get(damage_type, ...)` (строка 279). Крит перебивает цвет
  красным `Color(1.0,0.24,0.16,1.0)`.
- `boss.gd` наследует: `take_damage(amount, feedback)` — `scripts/boss.gd:74-81` → `super(...)`.

**Откуда тип НЕ доходит (главные пробелы):**
- Классовое оружие `scripts/class_weapon.gd`: `_damage_enemy(...)` (строки 1955-1968)
  зовёт `_call_take_damage(enemy, amount, {"critical": ...})` — БЕЗ `damage_type` →
  feedback по умолчанию `"true"` (белый). Это основной путь урона почти всех классов.
- DoT-тики оружия `_damage_enemy_with_dot(...)` — `scripts/class_weapon.gd:1995-2018`:
  тики идут через `_damage_enemy(...)` без типа → не окрашены как `dot`.
- Прямые `enemy.take_damage(...)` без feedback: splash/execute/close в class_weapon
  (строки 1974, 1979, 1988); berserk_weapon (строки 188, 193, 206); projectile.gd:89;
  enemy_projectile.gd; ally_minion.gd:172-186; status_effects.gd:55 (DoT-тик статуса).
- ЕДИНСТВЕННЫЙ корректный пример: `scripts/berserk_weapon.gd:177` —
  `_call_take_damage(enemy_node, dealt, {"critical": ..., "damage_type": "physical"})`.
- `_call_take_damage` / `_take_damage_accepts_feedback` есть и в class_weapon
  (строки 2039-2050) и в berserk_weapon (строки 265-275) — feedback прокидывается, только
  если `take_damage` принимает 2-й аргумент (враг/босс — да; player — нет).

**UI (`scripts/ui_screens.gd`):** на текущий момент НЕ содержит НИ ОДНОГО упоминания
`damage_type`/палитры (grep пуст). То есть «цветовая кодировка в UI» сейчас живёт ТОЛЬКО
во всплывающих боевых цифрах над врагом; в самих UI-экранах привязки к палитре нет.

**Тесты:** `tests/damage_type_isolation_test.gd` — это SCRUM-524 (изоляция атрибутов по
типу, чистая формула из `progression_data.derived_parameters`), он НЕ проверяет палитру/
окраску. Палитра/тип в боевых цифрах никаким тестом не закрыт.
Прогон: `tools/run_focused_tests.sh` (umbrella `tests/runtime_smoke_test.gd` включён);
комбат-смоук — `tests/runtime_smoke_combat_test.gd` (стартует Main.tscn, ищет ноды группы
`combat_feedback_labels`). Godot: `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot`.

**Доки:** комментарий в `scripts/player.gd:59` обещает, что палитра задокументирована в
`docs/design/systems/characters_weapons.md` — но раздела про типы урона/палитру там сейчас
НЕТ. `docs/design/systems/combat.md` описывает floating damage numbers (строки 50-53) без
палитры типов.

## Что сделать — по шагам

Цель — довести систему до состояния «единая палитра + тип доходит до каждой боевой
цифры + задокументировано», не сломав текущие зелёные пути.

1. **Единый источник палитры (убрать дубль).** Сделать `player.gd` единственным
   владельцем палитры. В `scripts/enemy.gd` УБРАТЬ локальную `COMBAT_FEEDBACK_DAMAGE_COLORS`
   и красить через канон player:
   - вверху enemy.gd добавить `const PlayerScript := preload("res://scripts/player.gd")`
     (если ещё нет подходящего preload — проверить шапку файла);
   - в `_show_combat_feedback` (enemy.gd:279) заменить
     `COMBAT_FEEDBACK_DAMAGE_COLORS.get(damage_type, ...)` на
     `PlayerScript.damage_type_color(damage_type)` (static-функция, инстанс не нужен).
   - Тем самым `"true"` станет единым (решить какой: канон — player `Color(1,1,1,1)`;
     если тёплый белый враг выглядел лучше — поднять его В player-палитру, чтобы
     остался ОДИН источник). По умолчанию — взять player-значение.
2. **Прокинуть тип из классового оружия.** В `scripts/class_weapon.gd`:
   - `_damage_enemy(enemy, amount, apply_unique_melee_effects)` (строка 1955) — добавить
     параметр `damage_type := "physical"` и передать его в feedback:
     `_call_take_damage(enemy, amount, {"critical": ..., "damage_type": damage_type})`.
   - Определить тип попадания из конфигурации оружия/режима. Большинство классов —
     физика по умолчанию; для магических/звуковых/DoT-режимов проставить `"magic"`/
     `"sound"`/`"dot"`. Источник истины о «канале» — `weapon_config`/режим атаки
     (`beam`, `sound_wave`, `dot_beam`, `aoe_projectile` и т.д., см. combat.md:64).
     Минимально-достаточно: ввести хелпер `_weapon_damage_type()` на оружии, который по
     режиму/конфигу возвращает строковый тип; дефолт `"physical"`.
   - DoT-тики: в `_damage_enemy_with_dot` (строка 1995) тик-вызов
     `_damage_enemy(enemy, tick_damage, false)` (строка 2013) → передать `"dot"`.
   - Прямые `enemy.take_damage(...)` без feedback (splash/execute/close — строки 1974,
     1979, 1988) перевести на `_call_take_damage(..., {"damage_type": <тип>})`, чтобы
     осколки/добивания тоже красились корректно (физика по умолчанию).
3. **status_effects DoT-тик.** `scripts/status_effects.gd:55` — тик статуса
   `target.call("take_damage", dot_damage*stacks)` идёт 1 аргументом. Прокинуть тип:
   если у цели `take_damage` принимает 2-й аргумент — звать с
   `{"damage_type": "dot", "suppress_number": false}`. Использовать ту же проверку
   арности, что и в оружии (наличие 2-арг `take_damage`).
4. **Снаряды/миньоны (по желанию, для полноты).** `projectile.gd:89`,
   `enemy_projectile.gd`, `ally_minion.gd:172-186` — если несут осмысленный тип
   (физика/магия), прокинуть feedback `damage_type`. Враг-урон по игроку типизировать НЕ
   нужно (player.take_damage без feedback). Низкий приоритет — не блокирует AC.
5. **Player-цифры уже типизированы** — НЕ ломать. Проверить, что
   `_deal_typed_damage`/`_apply_ultimate_damage` рисуют цвет корректно после унификации
   палитры (player сам зовёт `damage_type_color`, дубля там нет).
6. **Документация палитры (источник правды).** Дописать в
   `docs/design/systems/characters_weapons.md` (и/или `combat.md`) раздел «Типы урона и
   палитра боевых цифр»: таблица тип → строковый ключ → цвет (RGBA) → семантика, и явно
   указать, что палитра живёт в `player.gd::DAMAGE_TYPE_COLORS` и переиспользуется через
   `Player.damage_type_color()`; что итог по цели = сумма типизированных вызовов; что крит
   перекрывает цвет красным. Привести комментарий `player.gd:59` в соответствие, если
   файл-адресат изменится.
7. **Тест-инвариант (под `runtime_smoke`).** Добавить лёгкую проверку, что цвет цифры
   соответствует типу. Варианты:
   - чистый unit (предпочтительно, без RNG): новый `tests/damage_type_palette_test.gd`
     (`extends SceneTree`) — проверяет, что `Player.damage_type_color("physical"/"magic"/
     "dot"/"sound"/"true")` возвращает ожидаемые цвета палитры, fallback неизвестного типа
     = `true`, и (после унификации) что enemy красит ТЕМ ЖЕ цветом (нет рассинхрона).
   - либо расширить `runtime_smoke_combat_test.gd`: нанести типизированный урон и
     убедиться, что среди `combat_feedback_labels` появляется label с `modulate ==
     damage_type_color(<тип>)`.
   Любой из них должен войти в зелёный прогон `tools/run_focused_tests.sh`.

## Acceptance Criteria

Из тикета:
- [ ] Урон по цели = сумма по всем активным типам (физ/маг/звук/DoT/true): каждый
      типизированный вызов уменьшает HP и порождает отдельную цветную цифру; визуально
      виден вклад каждого типа.
- [ ] Боевые цифры/индикаторы раскрашены по типу из СТАБИЛЬНОЙ палитры (цвет привязан к
      типу урона, не к классу/оружию).
- [ ] Палитра типов задокументирована и переиспользуется (единый источник правды).
- [ ] `runtime_smoke` зелёный (`tools/run_focused_tests.sh`, umbrella включён).

Дополнительно (по коду):
- [ ] Дубль палитры устранён: `enemy.gd` больше НЕ держит свою
      `COMBAT_FEEDBACK_DAMAGE_COLORS`, красит через `Player.damage_type_color(...)`;
      значение `"true"` единое во всех путях.
- [ ] Классовое оружие (`class_weapon.gd::_damage_enemy`) проставляет корректный
      `damage_type` в feedback; магические/звуковые/DoT-режимы НЕ окрашиваются как `true`.
- [ ] DoT-тики (оружие `_damage_enemy_with_dot` и `status_effects` тик) окрашены как `dot`.
- [ ] Крит по-прежнему перекрывает цвет красным (поведение не регрессировало).
- [ ] Новый/расширенный тест проверяет соответствие цвет↔тип и проходит в фокус-прогоне.

## Files / точки входа

- `scripts/player.gd:53-77` — канонные `DAMAGE_TYPE_*`, `DAMAGE_TYPE_COLORS`,
  `damage_type_color()`. ИСТОЧНИК ПРАВДЫ палитры. Здесь при необходимости унифицировать
  значение `"true"`. НЕ ломать `_deal_typed_damage`/`_spawn_combat_number`/`_apply_ultimate_damage`.
- `scripts/enemy.gd:91-97, 265-294` — УБРАТЬ `COMBAT_FEEDBACK_DAMAGE_COLORS`, красить
  `_show_combat_feedback` через `Player.damage_type_color(damage_type)` (строка 279).
- `scripts/class_weapon.gd:1955-1968` — `_damage_enemy`: добавить параметр `damage_type`,
  прокинуть в feedback; `2013` (DoT-тик) → `"dot"`; `1974/1979/1988` (splash/execute/close)
  → feedback с типом; хелпер `_weapon_damage_type()` (новый) по режиму/конфигу.
- `scripts/berserk_weapon.gd:177` — эталон (уже типизирует physical); строки 188/193/206
  — по желанию прокинуть тип в splash/close/execute.
- `scripts/status_effects.gd:50-55` — DoT-тик статуса: прокинуть `{"damage_type":"dot"}`
  если цель принимает 2-арг `take_damage`.
- `scripts/boss.gd:74-81` — наследует enemy `take_damage(amount, feedback)`; правок логики
  не требует (палитра подтянется из enemy после унификации).
- `docs/design/systems/characters_weapons.md` (и/или `combat.md:50-53`) — раздел про типы
  урона и палитру (таблица тип→ключ→RGBA→семантика).
- `tests/damage_type_palette_test.gd` (новый) ИЛИ `tests/runtime_smoke_combat_test.gd`
  (расширение) — инвариант цвет↔тип.

## Замечания / подводные камни

- **ANTI-COLLISION / locked paths.** `scripts/ui_screens.gd` и
  `scripts/progression_data.gd` — заблокированы (Claude-контур, частые конфликты). По этой
  задаче в `progression_data.gd` лезть НЕ нужно (формулы типов уже там, см.
  `progression_data.gd:848` и SCRUM-524). В `ui_screens.gd` сейчас НЕТ привязки к палитре;
  если потребуется UI-индикатор урона по типу — согласовать/делать отдельным шагом, не
  трогая чужие хунки; основная часть AC закрывается боевыми цифрами над врагом (player/
  enemy), а не экранами UI. По возможности избегать правок этих двух файлов целиком.
- **Источник правды = ОДНА палитра.** Главная цель рефактора — чтобы цвет типа жил в
  одном месте (`player.gd`). Не плодить третью копию в оружии/статусах — всегда звать
  static `Player.damage_type_color()` или передавать строковый тип во feedback, а красит
  пусть владелец цифры.
- **Арность `take_damage`.** Враг/босс: `take_damage(amount, feedback)`. Player:
  `take_damage(amount, _source := "")` — 2-й аргумент это СТРОКА-источник, НЕ feedback-
  словарь. НЕ слать врагу-feedback по игроку. Оружие уже защищено `_take_damage_accepts_feedback`
  (проверяет `args.size() >= 2`) — но это не отличает «feedback-врага» от «source-игрока»;
  player-урон феникса/рефлектов оставить как есть (источник-строка).
- **Крит перебивает тип.** В `enemy.gd:279` крит красит красным независимо от типа — это
  ожидаемое поведение, сохранить (док отметить). Не считать «крит-красный» нарушением
  цветовой кодировки.
- **`suppress_number`.** В feedback есть флаг `suppress_number` (enemy.gd:269) — некоторые
  попадания осознанно без цифры; при прокидывании типа не включать цифру там, где она
  была подавлена.
- **Лимит лейблов.** `COMBAT_FEEDBACK_MAX_LABELS = 42` (player.gd:51, enemy.gd:89) —
  цифры дропаются при переполнении; тест на «появилась цветная цифра» гонять на малом
  числе врагов/одном ударе, иначе флак.
- **Связанные тикеты.** SCRUM-524 (`tests/damage_type_isolation_test.gd`) — изоляция
  атрибутов по типу; опирается на ТУ ЖЕ систему типов, но это про формулу урона, не про
  цвет. Не дублировать его проверки. Эпик SCRUM-522 — общий ребаланс боёвки/прогрессии.
- **Дефолт типа.** Неизвестный/непроставленный тип → `true` (белый). После рефактора
  «белая цифра» должна означать именно чистый/нетипизированный урон, а не «забыли
  проставить тип» — поэтому важно протипизировать классовые попадания (иначе вся физика
  останется белой).
- **Не менять gameplay-числа.** Это визуальная/диспетчерская задача: радиусы, тайминги,
  множители, итоговый урон НЕ трогаем — только маршрутизация `damage_type` во feedback и
  единая палитра.
