# SCRUM-525: Понятные подсказки характеристик: на что влияет + предпросмотр прокачки

Jira: SCRUM-525 · Роль: backend · Контур: claude · Приоритет: P1 · foma · Эпик: SCRUM-522
Статус: Готово (QA PASSED, dev e2ef8760; QA 2026-06-27)

## QA-Вердикт: PASSED

Статус: PASSED · QA 2026-06-27 (Godot 4.6.3 headless, ветка dev, HEAD e2ef8760)

Green-gate / смоуки — все зелёные: runtime_smoke_test, ui_no_overlap_matrix_test
(overflow-допуск 6px, контракт choice_card, форс attribute_offer=[damage,attack_speed]),
runtime_smoke_ui_test, stat_formulas_smoke_test (35/8/27).

Функциональная проба (экран докачки, base-оффер strength/agility, money=9000):
- Tooltip AttributeOffer_* содержит «Влияет на: …» с RU-подписями производных.
- Живой предпросмотр «было -> станет» через derived_parameters от снапшота игрока:
  Урон 12->13; Скорость атаки 1.75->2.05; Шанс крита 7%->8%; Скорость 313->320; Уклонение 6%->7%.
- Изоляция типов урона (SCRUM-524): berserk показывает только «Урон» (damage_parameter_for).
- Небазовые id ([damage,attack_speed]) — graceful fallback без падения.
- Ветка disabled «Недостаточно золота» сохранена; economy_frame_kind=choice_card цел.
Все acceptance подтверждены фактической проверкой.

## Что и зачем

Сейчас в окне «Докачка» (и в карточках характеристик вообще) игроку ОЧЕНЬ сложно понять,
что даёт +1 к конкретной характеристике. На карточке `AttributeOffer_*` показывается только
классовая интерпретация одной строкой («Прямо усиливает двуручное оружие.») и подпись
«+1 к характеристике», но НЕ видно:
- на какие именно ПРОИЗВОДНЫЕ статы влияет эта характеристика (Урон, Скорость атаки, HP, …);
- какова ДЕЛЬТА конкретного значения при покупке +1 (например `Урон 41 -> 44`).

Цель с точки зрения игрока: при наведении на карточку докачки (и при выборе) он сразу видит
понятный предпросмотр — «эта характеристика влияет на X, Y, Z; при +1 они станут такими-то».
Это снимает главную боль непрозрачности прокачки: выбор перестаёт быть «вслепую», игрок может
осознанно докупать стат под свой билд.

Ожидаемый результат:
- В tooltip карточки докачки перечислено, на какие производные статы влияет характеристика, и
  показана дельта `было -> станет` хотя бы по ключевым из них (предпросмотр до подтверждения покупки).
- Производные параметры считаются ВЖИВУЮ от текущего состояния игрока (а не статичный текст),
  через тот же путь, что и боевые формулы (`derived_parameters`), чтобы предпросмотр был честным.
- Нет overflow текста в подсказке (узкие вьюпорты 1280x720 и меньше).
- Зелёные `runtime_smoke` и UI-смоуки (особенно `tests/ui_no_overlap_matrix_test.gd`).

Важно: на level-up экране («Повышение уровня», выбор 1 из 3) предпросмотр дельты УЖЕ есть
(`_level_up_reward_preview`). Эта задача — перенести/переиспользовать тот же качественный
предпросмотр в окно ДОКАЧКИ за золото и добавить блок «на что влияет».

## Текущее состояние в коде

Окно докачки (за золото) строится в `scripts/ui_screens.gd`:
- `_show_attribute_shop(on_done)` — `ui_screens.gd:1800` — создаёт экран `AttributeShopScreen`,
  панель `AttributeShopPanel`, грид `AttributeOffers`, фиксирует `game.attribute_offer`
  (через `_random_attribute_pair()` — только БАЗОВЫЕ статы: strength…leadership).
- `_refresh_attribute_shop(root, on_done)` — `ui_screens.gd:1922` — перерисовывает карточки.
  Текущая логика подписи/тултипа (строки 1939–1950):
  ```gdscript
  for stat_id in game.attribute_offer:
      var stat_title := str(game.PROGRESSION_DATA.STAT_NAMES.get(stat_id, stat_id))
      var interpretation := str(game.PROGRESSION_DATA.class_interpretation_text(game.selected_character_id, stat_id))
      var offer_button := _make_economy_choice_card(stat_title, "%s\n+1 к характеристике" % interpretation, "%d зол." % buy_cost, ...)
      ...
      offer_button.tooltip_text = "%s +1\n%s" % [stat_title, interpretation]
      if offer_button.disabled:
          offer_button.tooltip_text += "\nНедостаточно золота: нужно %d, есть %d." % [buy_cost, money]
  ```
  То есть подпись/тултип = только название + классовая интерпретация. НЕТ списка влияемых
  производных и НЕТ дельты `было -> станет`.
- Покупка применяет `_apply_reward_to_run({"stats": {stat_id: 1.0}})` (`ui_screens.gd:1958`).

Готовый предпросмотр-движок (использовать как образец и переиспользовать):
- `_level_up_reward_preview(reward)` — `ui_screens.gd:5614` — для награды со `stats`/`mods`
  снимает текущее состояние, прибавляет дельту и считает `derived_parameters` ДО и ПОСЛЕ:
  ```gdscript
  var before_stats := _active_stats_snapshot()
  var before_mods := _active_modifiers_snapshot()
  ... after_stats[stat_id] += reward delta ...
  var weapon_config = game.PROGRESSION_DATA.weapon(game.selected_character_id, game.selected_weapon_id)
  var before_parameters := game.PROGRESSION_DATA.derived_parameters(before_stats, before_mods, weapon_config)
  var after_parameters := game.PROGRESSION_DATA.derived_parameters(after_stats, after_mods, weapon_config)
  ```
  Но текущая реализация для веток со `stats` возвращает дельту ТОЛЬКО самого базового стата
  (`Сила 10 -> 11`, строки 5635–5643), а для производных параметров дифф считается только в
  ветке `mods`. Для докачки нам нужен дифф именно ПРОИЗВОДНЫХ при +1 базового стата.
- `_active_stats_snapshot()` / `_active_modifiers_snapshot()` — `ui_screens.gd:5683` / `:5691` —
  достают `stats`/`run_modifiers` из живого игрока, иначе из `run_player_snapshot`, иначе из
  `base_stats`. Снимок безопасен и вне боя (меню).
- `_level_up_parameter_label(parameter_id)` — `ui_screens.gd:5699` — RU-подписи производных
  («Урон», «Скорость атаки», «Макс. здоровье», …). Готовый словарь — переиспользовать.
- `_format_level_up_value(parameter_id, value)` — `ui_screens.gd:5753` — формат значения
  (%, x2, целое) по параметру. Переиспользовать.
- `damage_parameter_for(character_id)` — `progression_data.gd:107` — у класса свой «свой»
  damage-параметр (`damage` / `magic_damage` / `sound_wave_damage`). Учитывать, чтобы превью
  урона показывало правильный тип (как сделано на level-up, строки 5650–5651).

Источник «на что влияет» (текст-описание связей характеристики с производными):
- `StatFormulas.STAT_DEFINITIONS[<stat>]["influences"]` — `scripts/stat_formulas.gd:54+`
  (например strength → `"Damage, силовые melee-эффекты."`, agility → `"Attack Speed, Move Speed,
  Crit Chance, Crit Damage, Dodge."`). Это статический текст по атрибуту.
- Образец богатого тултипа со строкой «Влияет на» уже есть в меню статов:
  `scripts/pause_stats_menu.gd:647` `_tooltip_for_entry(entry)` собирает description + formula +
  influences; кастомный tooltip `_make_custom_tooltip` (`pause_stats_menu.gd:630`) — панель
  фикс. ширины `TOOLTIP_MAX_WIDTH = 430`, высота по контенту, label с autowrap (overflow-safe).

Формулы производных (для понимания, какие параметры реально двигаются от стата) —
`progression_data.gd:793` `derived_parameters(stats, run_modifiers, weapon_config)`. Сводка
вкладов базовых статов в производные (для выбора, что показать в превью):
- strength → damage; intelligence → magic_damage; perception+energy → sound_wave_damage;
- agility → attack_speed, crit_chance, crit_damage_multiplier, move_speed, dodge;
- endurance → health_point, defense, absorb, knockback_*;
- perception → attack_range, aoe_radius, pickup_radius, projectile_speed;
- knowledge → dot_damage, dot_speed, regeneration;
- leadership → summon_amount, aura_radius, buff_power; energy → ultimate_multiplier, vampiric.

Тесты, которые ЭТО уже трогают (anti-collision / гейт):
- `tests/ui_no_overlap_matrix_test.gd`:
  - `_open_attribute_shop` (`:292`) форсит `attribute_offer = ["damage", "attack_speed"]` —
    ВНИМАНИЕ: тест подсовывает в оффер ПРОИЗВОДНЫЕ id (`damage`, `attack_speed`), а не базовые.
    Значит код карточки обязан корректно отрабатывать и для id, которых нет в `STAT_NAMES`.
  - `_screen_specific_assertions` (`:326`) при нулевом золоте требует, чтобы все
    `AttributeOffer_*` были `disabled` и их `tooltip_text` содержал «Недостаточно золота».
  - `_text_control_contract_error` (`:452`) + `TEXT_OVERFLOW_TOLERANCE = 6.0` (`:13`) — любой
    Label карточки не должен вылезать за родителя и за свою высоту → отсюда требование «нет overflow».
  - `_economy_choice_card_contract_error` (`:358`) — карточка обязана сохранить мета-рамку
    `economy_frame_kind = "choice_card"` (не ломать через `_make_economy_choice_card`).
- `tests/runtime_smoke_ui_test.gd` — общий smoke прохода UI (должен оставаться зелёным).

## Что сделать — по шагам

1. Добавить хелпер, возвращающий предпросмотр производных при +1 к базовому стату, например
   `func _attribute_upgrade_preview_lines(stat_id: String, delta := 1.0) -> Array[String]` в
   `scripts/ui_screens.gd` (рядом с `_level_up_reward_preview`, ~`:5614`):
   - Снять `before_stats = _active_stats_snapshot()`, `before_mods = _active_modifiers_snapshot()`.
   - `after_stats = before_stats.duplicate(true)`; `after_stats[stat_id] += delta`.
   - `weapon_config = game.PROGRESSION_DATA.weapon(game.selected_character_id, game.selected_weapon_id)`.
   - `before = derived_parameters(before_stats, before_mods, weapon_config)`;
     `after = derived_parameters(after_stats, before_mods, weapon_config)`.
   - Определить набор ЗАТРОНУТЫХ производных для данного стата (см. сводку выше). Реализовать как
     словарь `STAT_DERIVED_PREVIEW := { "strength": ["damage"], "agility": ["attack_speed",
     "crit_chance", "move_speed", "dodge"], "endurance": ["health_point", "defense"], ... }`.
     Для `damage`-параметра использовать `damage_parameter_for(character_id)` (класс-зависимо).
   - Для каждого затронутого параметра, где `after != before` (с эпсилоном), собрать строку
     `"%s: %s -> %s" % [_level_up_parameter_label(p), _format_level_up_value(p, before[p]),
     _format_level_up_value(p, after[p])]`. Ограничить список 3–4 самыми значимыми, чтобы тултип
     не разрастался (иначе overflow на 720p).
   - Edge-case: если `stat_id` не базовый (нет в `STAT_NAMES` / в словаре превью — как `damage`,
     `attack_speed` из теста) — НЕ падать: вернуть пустой массив (или одну строку из
     `_level_up_parameter_label`), карточка просто покажет интерпретацию как раньше.

2. В `_refresh_attribute_shop` (`ui_screens.gd:1922`, цикл `for stat_id in game.attribute_offer`)
   собрать обогащённый текст карточки и тултип:
   - Влияние (на что влияет): взять `StatFormulas.STAT_DEFINITIONS.get(stat_id, {}).get(
     "influences", "")` ИЛИ RU-список из шага 1 (предпочесть RU-подписи `_level_up_parameter_label`,
     чтобы не мешать EN-термины из `influences`). Сформировать строку «Влияет на: …».
   - Предпросмотр: строки из `_attribute_upgrade_preview_lines(stat_id)`.
   - Описание карточки (2-й аргумент `_make_economy_choice_card`) оставить компактным
     (интерпретация + «+1 к характеристике»); подробности (влияние + дельты) положить в `tooltip_text`,
     чтобы не раздувать тело карточки (на карточке мало места, тест ловит overflow).
   - Итоговый `offer_button.tooltip_text` собрать как многострочный, например:
     ```
     <Название> +1
     <классовая интерпретация>
     Влияет на: <производные>
     Предпросмотр: <param> <было> -> <станет>; <param2> ...
     ```
     СОХРАНИТЬ существующую ветку для disabled: при нехватке золота дописать
     «Недостаточно золота: нужно %d, есть %d.» (тест `ui_no_overlap_matrix_test` это проверяет —
     НЕ удалять).

3. Overflow-контроль:
   - Подробный многострочный текст держать в стандартном `tooltip_text` (движок Godot клампит
     tooltip в экран сам) — это безопаснее, чем выводить всё на тело карточки.
   - Если решено выводить часть превью на тело карточки (desc/доп.Label) — убедиться, что Label
     имеет `autowrap_mode = AUTOWRAP_WORD_SMART` и помещается в safe-rect карточки; число строк
     превью ограничить (3–4). Проверять через `ui_no_overlap_matrix_test` на минимальном вьюпорте.
   - Не превышать ширину/высоту контента карточки `_economy_attribute_choice_display_size()`.

4. (Опционально, если просто и в рамках) Сделать тот же блок «Влияет на + дельта» консистентным с
   level-up карточками: на level-up для ветки `stats` сейчас показывается только дельта самого
   базового стата (`Сила 10 -> 11`). Можно дополнить тем же `_attribute_upgrade_preview_lines`,
   чтобы и там был виден эффект на производные. НЕ обязательно для AC, но усиливает ценность.
   Если делать — не ломать существующий формат, который проверяют тесты на level-up.

5. Прогнать гейты (см. ниже) и убедиться, что текст помещается на 1280x720 и на узких окнах.

## Acceptance Criteria

- [ ] Tooltip карточки докачки (`AttributeOffer_*`) показывает, на какие производные статы влияет
      характеристика (блок «Влияет на: …»).
- [ ] Tooltip/предпросмотр показывает дельту `было -> станет` хотя бы по ключевым производным при +1
      (предпросмотр ДО подтверждения покупки).
- [ ] Производные пересчитываются ВЖИВУЮ от текущего состояния игрока через `derived_parameters`
      (а не статичная строка); значения соответствуют реальным боевым формулам.
- [ ] Предпросмотр корректен и вне боя (через `_active_stats_snapshot` / снапшот игрока), и в бою
      (через живого `current_player`).
- [ ] Нет overflow текста в подсказке/на карточке на 1280x720 и более узких вьюпортах
      (`ui_no_overlap_matrix_test` зелёный, в т.ч. `_text_control_contract_error`).
- [ ] Для disabled-оффера (нет золота) тултип по-прежнему содержит «Недостаточно золота: нужно …,
      есть …» и карточка `disabled` (контракт `ui_no_overlap_matrix_test._screen_specific_assertions`).
- [ ] Карточка не теряет economy-рамку (`economy_frame_kind = "choice_card"`,
      `_economy_choice_card_contract_error` зелёный).
- [ ] Код не падает, когда в `attribute_offer` попадает id, которого нет в `STAT_NAMES`
      (тест форсит `["damage", "attack_speed"]`) — graceful fallback.
- [ ] `runtime_smoke` зелёный; UI-смоуки зелёные.

## Files / точки входа

- scripts/ui_screens.gd:1922 `_refresh_attribute_shop` — основное место: собрать «Влияет на» +
  строки предпросмотра, обновить `description` карточки и `offer_button.tooltip_text`; сохранить
  ветку disabled/«Недостаточно золота».
- scripts/ui_screens.gd (~:5614, рядом с `_level_up_reward_preview`) — добавить
  `_attribute_upgrade_preview_lines(stat_id, delta)` + словарь `STAT_DERIVED_PREVIEW`
  (стат → список затронутых производных).
- scripts/ui_screens.gd:5699 `_level_up_parameter_label`, :5753 `_format_level_up_value` —
  ПЕРЕИСПОЛЬЗОВАТЬ для RU-подписей и формата значений (не дублировать).
- scripts/ui_screens.gd:5683/:5691 `_active_stats_snapshot` / `_active_modifiers_snapshot` —
  ПЕРЕИСПОЛЬЗОВАТЬ для снятия текущего состояния.
- scripts/stat_formulas.gd:54+ `STAT_DEFINITIONS[*]["influences"]` — источник текста «на что влияет»
  (опционально; предпочесть RU-подписи производных).
- scripts/progression_data.gd:793 `derived_parameters`, :107 `damage_parameter_for`,
  :764 `weapon` — пересчёт производных и выбор damage-параметра класса. ТОЛЬКО ЧИТАТЬ/ВЫЗЫВАТЬ.

## Замечания / подводные камни

- ANTI-COLLISION: задача обязательно правит `scripts/ui_screens.gd` (locked path). Координируй,
  чтобы параллельные задачи не редактировали те же зоны (`_refresh_attribute_shop` ~1922–1963 и
  блок level-up превью ~5590–5760). `scripts/progression_data.gd` (locked path) и
  `scripts/stat_formulas.gd` — только ЧИТАТЬ/ВЫЗЫВАТЬ существующие функции, НЕ менять.
- Изоляция типов урона (SCRUM-524): не показывай в предпросмотре «чужой» урон. Для damage бери
  `damage_parameter_for(character_id)` — иначе у мага/гитариста превью покажет нерелевантный
  физический `damage`.
- Снимок состояния безопасен и вне боя: `_active_stats_snapshot` падает в `run_player_snapshot`,
  затем в `base_stats`. Не дёргай `_snapshot_player_for_menu()` ради предпросмотра (это для покупки),
  чтобы не плодить временных игроков на каждый refresh/наведение.
- Длина тултипа: на 720p длинный многострочный текст на ТЕЛЕ карточки = overflow (тест с
  допуском 6px поймает). Безопасный путь — подробности в `tooltip_text` (Godot клампит сам), на
  карточке держать кратко. Ограничивай число строк превью (3–4 параметра max).
- Тест `ui_no_overlap_matrix_test._open_attribute_shop` подсовывает `["damage", "attack_speed"]` —
  это НЕ базовые статы. Карточка/превью должны не падать и давать осмысленный fallback
  (просто без блока дельты или с подписью параметра). Проверь `STAT_NAMES.get(stat_id, stat_id)`
  и словарь превью на отсутствие ключа.
- Reroll/переоткрытие окна (FAB) не должны давать бесплатные действия — это уже учтено в
  `_show_attribute_shop` (offer/rerolls в game-state); новый код только читает `attribute_offer`.
- Связанные тикеты: эпик SCRUM-522 (прозрачность прогрессии); SCRUM-524/523 (изоляция типов урона —
  учитывать в выборе damage-параметра); образец богатого тултипа — `scripts/pause_stats_menu.gd`
  (`_tooltip_for_entry`, `_make_custom_tooltip`), можно опереться на его подход к «Влияет на».
- Гейты для прогона (QA/исполнитель), Godot 4.6.3 headless:
  `tests/ui_no_overlap_matrix_test.gd`, `tests/runtime_smoke_ui_test.gd`, `tests/runtime_smoke_test.gd`,
  и при желании `tests/stat_formulas_smoke_test.gd` (формулы) — все должны быть зелёными.
