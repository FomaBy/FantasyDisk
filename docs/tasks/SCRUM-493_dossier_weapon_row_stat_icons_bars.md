# SCRUM-493: Hero Select v4: добавить строку оружия и иконки/бары статов в досье

Jira: SCRUM-493 · Роль: backend (UI/GDScript) · Контур: claude · Приоритет: P2 · foma · Эпик: SCRUM-470 (Hero Select v4)
Статус: done

## Что и зачем

Экран выбора героя v4 (`_build_character_select_v4`) — это центральная витрина ростера. По брифу v4 центральная панель «досье» должна давать игроку мгновенно читаемое сравнение классов: **строку стартового оружия** и **5 равномерных строк характеристик с иконкой и баром/значением**, а не голый текст.

Сейчас досье недоделано относительно брифа:
- Нет строки оружия вообще — игрок не видит, чем класс играет, до экрана выбора оружия.
- 5 статов нарисованы простыми `Label` вида `"Сила: 12"` в `GridContainer` без иконок и без визуального бара. Глазом сравнивать классы тяжело: цифры разной длины, нет масштаба «насколько это много».

Цель: довести досье до брифа v4 — игрок на одном экране понимает «кто это, какие у него характеристики (относительно сильнейшего по этому стату) и каким оружием он стартует», без перехода дальше. Вся графика уже есть в реестре иконок (`UIIconRegistry`), глобальные максимумы статов уже считаются (`_hero_radar_global_maxima`), названия оружия достаются из `PROGRESSION_DATA`. Задача — собрать это в читаемую раскладку без наложений на матрице разрешений.

Ожидаемый результат: в центральной панели досье под описанием класса — строка «Оружие: …», затем 5 строк статов, каждая = [иконка стата] [название] [бар прогресса до глобального максимума] [числовое значение]. Раскладка не ломается и не вылезает за панель/вьюпорт на 1280x720 и 1600x900.

## Текущее состояние в коде

Реальная актуальная реализация — `_build_character_select_v4()` (НЕ строки 792–844 из тикета; тикет ссылается на устаревший легаси-вариант v3, см. ниже).

**`scripts/ui_screens.gd`:**

- `_build_character_select_v4()` — строится начиная со строки **749**. Создаёт `HeroSelectScreen` (root), фон, заголовок, кнопку «Назад», левую панель `portrait_panel` (`HS4Portrait`), центральную `dossier_panel` с VBox `dossier`, правую `radar_panel` (`HS4Radar`), нижнюю карусель (`HS4Carousel`).
- Центральная панель досье (VBox `dossier`) собирается на строках **812–887**:
  - `name_label` (имя класса), `desc_label` (описание).
  - **`stats_grid` (GridContainer, columns=2)** — строки **834–844**. На каждый `sid in HS4_DOSSIER_STATS` создаётся один `Label` `srow`, кладётся в словарь `stat_value_labels[sid]`. Иконок/баров нет.
  - дальше `spacer` (SIZE_EXPAND_FILL), блок «Возвышение» (`asc_box`/`asc_label`/`asc_plus`/`asc_minus`), `asc_mods`, кнопка `HS4ChooseButton`.
- Заполнение значений — внутри замыкания `refresh` (строки **951→**). Конкретно строки **958–960**:
  ```gdscript
  for sid in HS4_DOSSIER_STATS:
      var nm: String = str(game.PROGRESSION_DATA.STAT_NAMES.get(sid, sid))
      (stat_value_labels[sid] as Label).text = "%s: %d" % [nm, int(stats.get(sid, 0))]
  ```
  Здесь же `radar.setup(stats, stat_maxima, ...)` (строка 965) и обновление карусели/портрета.
- `stat_maxima := _hero_radar_global_maxima()` вычисляется на строке **949** (до замыкания) — это словарь `{stat_id: max_по_всем_классам}`, уже доступен в `refresh` через захват.

**Константы (`scripts/ui_screens.gd`, строки 693–701):**
- `HS4_DOSSIER_STATS := ["strength", "agility", "intelligence", "endurance", "perception"]` — порядок строк статов.
- `HS4_DOSSIER := Rect2(0.288, 0.138, 0.362, 0.555)` — координатная спека панели (для QA-верификатора).

**Реестр иконок (`scripts/ui_icon_registry.gd`):**
- `make_icon(icon_id: String, size := Vector2(42,42)) -> Control` (строка 196) — возвращает `TextureRect` с иконкой либо фолбэк-`PanelContainer` с аббревиатурой. Для статов иконки ЕСТЬ: `ICON_PATHS` (строки 50–57) содержит `strength/agility/intelligence/perception/endurance` → `res://assets/sprites/ui/icons/stats/stat_*.png`. `ICON_COLORS` (157–163) даёт цвет на стат — можно красить бар в цвет стата.
- `texture_for(icon_id)` (строка 182) — `Texture2D|null`.
- Существующий эталонный паттерн «иконка + текст в строке стата» уже используется в этом же файле: строки **1951** (атрибут-шоп) и **2943** (кодекс): `game.UIIconRegistry.make_icon(stat_id, Vector2(30,30))`.

**Названия оружия (`scripts/progression_data.gd`):**
- `weapon_ids(character_id) -> Array` (строка 411) — ключи 3 вариантов оружия класса.
- `weapon(character_id, weapon_id) -> Dictionary` (строка 764) — конфиг, есть `title`.
- Готовый хелпер `_hero_weapon_names(character_id) -> String` уже есть в `ui_screens.gd` (строка **1689**): собирает `"title, title, title"` из всех 3 вариантов оружия. Им же пользуется легаси-v3 (строка 1391: `weapons_label.text = "Оружие: %s" % _hero_weapon_names(character_id)`).

**Легаси-ориентир (v3, НЕ трогать как продакшен, но как образец):** строки 1194–1203 создают `weapons_label` («строка оружия»), 1391 заполняют. То есть строка оружия УЖЕ была реализована в v3 — в v4 её просто забыли перенести. Можно переиспользовать тот же текст-формат.

**Тесты:**
- `tests/runtime_smoke_test.gd` — `_open_hero_select` зовёт `_show_character_select`; проверяет наличие `HS4Portrait`, `HS4Radar`, `HS4Carousel`, `HS4ChooseButton`, что у каждого класса ровно 3 оружия (строка 399). Имена существующих узлов менять нельзя.
- `tests/ui_no_overlap_matrix_test.gd` — `_check_screen` для `hero_select` на разрешениях `Vector2i(1280,720)` и `Vector2i(1600,900)` (строки 6–7). Проверяет: viewport-fit, peer-overlap (tolerance 2px), text-overflow, parent-containment. Скан идёт по именованным контролам, включая список из строк 59–61.

## Что сделать — по шагам

1. **Строка оружия.** В сборке досье (после `desc_label`, до `stats_grid`, ~строка 833) добавить `Label` `weapon_label` (имя `"HS4Weapon"`):
   - `autowrap_mode = AUTOWRAP_WORD_SMART`, `max_lines_visible = 1`, `text_overrun_behavior = OVERRUN_TRIM_ELLIPSIS`, `horizontal_alignment = CENTER`.
   - размер шрифта в стиле соседей: `maxi(11, int(round(vp.y * 0.019)))`, цвет как у легаси `Color(0.86, 0.92, 1.0, 1.0)`.
   - заполнять в `refresh`: `weapon_label.text = "Оружие: %s" % _hero_weapon_names(cid)` (использовать существующий хелпер).
   - Если строка из 3 названий слишком длинная на 1280 — оставить ellipsis (overrun уже это покрывает), либо при необходимости показывать только стартовое оружие класса: `_hero_weapon_names` даёт все 3; если по брифу нужно «стартовое оружие» — взять первый из `weapon_ids(cid)` и его `weapon(...).title`. По брифу формулировка «строка стартового оружия класса» — реализовать как читаемый список вариантов (как в v3), что и есть «оружие класса». Сохранить trim-ellipsis, чтобы не вылезало.

2. **Иконки + бары статов.** Заменить плоский `GridContainer` на VBox из 5 однотипных строк. Сделать хелпер-фабрику строки стата (локально или приватный метод), возвращающий `HBoxContainer` + сохраняющий ссылки на изменяемые узлы (бар + значение) в словаре, чтобы `refresh` их обновлял. Каждая строка:
   - `HBoxContainer` `srow` (имя `"HS4StatRow_%s" % sid`), `separation` ~ `maxi(6, int(round(vp.x*0.008)))`, `mouse_filter = IGNORE`, `size_flags_horizontal = SIZE_EXPAND_FILL`.
   - **иконка**: `game.UIIconRegistry.make_icon(sid, Vector2(s, s))`, где `s = maxi(18, int(round(vp.y*0.028)))`. `mouse_filter = IGNORE`.
   - **название** (опционально, по месту): короткий `Label` с `STAT_NAMES[sid]`, фикс. min-width, чтобы бары были выровнены; либо положиться на иконку + tooltip. Решить по влезаемости на 1280.
   - **бар**: `ProgressBar` (`show_percentage = false`), `size_flags_horizontal = SIZE_EXPAND_FILL`, `custom_minimum_size.y = maxi(8, int(round(vp.y*0.016)))`. Стилизовать через `add_theme_stylebox_override("background", ...)` и `("fill", ...)` (`StyleBoxFlat`), цвет fill = `UIIconRegistry.ICON_COLORS.get(sid, …)` для узнаваемости стата (как радар). `mouse_filter = IGNORE`.
   - **значение**: `Label` справа, `STAT_NAMES`-цифра, фикс. min-width (выравнивание правым краем), цвет `Color(0.92,0.94,0.98,1.0)`.
   - сохранить `stat_bars[sid] = bar` и `stat_value_labels[sid] = value_label` в словари (последний словарь уже есть — переиспользовать имя/семантику).

3. **Заполнение в `refresh`.** Заменить блок 958–960 на:
   ```gdscript
   for sid in HS4_DOSSIER_STATS:
       var val := float(stats.get(sid, 0.0))
       var mx_val := maxf(float(stat_maxima.get(sid, 1.0)), 1.0)
       (stat_bars[sid] as ProgressBar).max_value = mx_val
       (stat_bars[sid] as ProgressBar).value = clampf(val, 0.0, mx_val)
       (stat_value_labels[sid] as Label).text = "%d" % int(round(val))
   ```
   `stat_maxima` уже захвачен замыканием (строка 949). НЕ пересчитывать на каждый refresh.

4. **Влезаемость.** `dossier` — это VBox в `dossier_panel` высотой `mid_h`. Добавление строки оружия + утолщённых строк статов (иконка/бар выше плоского лейбла) увеличивает суммарную высоту. Проверить, что на 1280x720 контент не вылезает за панель и не наезжает на `spacer`/`asc_box`/`HS4ChooseButton`. При риске — уменьшить размеры иконки/бара/шрифта через коэффициенты от `vp.y`, либо ужать `separation` досье. `spacer` (SIZE_EXPAND_FILL) поглощает остаток — главное чтобы при минимальной высоте контент строк не превышал доступную область (иначе spacer схлопнется в 0 и пойдут наложения, которые поймает матрица).

5. **Прогон тестов** (Godot 4 headless, `~/Downloads/Godot.app`):
   - `tests/runtime_smoke_test.gd`
   - `tests/ui_no_overlap_matrix_test.gd`
   Оба должны быть зелёными. Матрица пишет дамп в `…/scrum470_hero_select_v4/hero_select_v4_no_overlap_matrix.md` — свериться, что в секции `hero_select` нет overlap/overflow.

## Acceptance Criteria

- [ ] В досье v4 добавлена читаемая строка стартового оружия выбранного класса (узел `HS4Weapon`/аналог), обновляется при смене героя в карусели.
- [ ] 5 строк статов (`HS4_DOSSIER_STATS`) отрисованы каждая с иконкой (`UIIconRegistry.make_icon`) и баром/значением — НЕ только голый текст `"%s: %d"`.
- [ ] Бар каждого стата масштабируется относительно глобального максимума из `_hero_radar_global_maxima()` (`max_value = maxima[sid]`, `value = текущий стат`).
- [ ] Цвет бара/иконки соответствует стату (через `ICON_COLORS`), визуально согласован с радаром.
- [ ] Нет наложений и нет выхода за панель/вьюпорт на 1280x720 и 1600x900 (peer-overlap, viewport-fit, parent-containment).
- [ ] Существующие именованные узлы (`HS4Portrait`, `HS4Radar`, `HS4Carousel`, `HS4ChooseButton`) и поведение карусели/возвышения/кнопки «Выбрать» не сломаны.
- [ ] `tests/runtime_smoke_test.gd` зелёный.
- [ ] `tests/ui_no_overlap_matrix_test.gd` зелёный; дамп секции `hero_select` без ошибок.

## Files / точки входа

- `scripts/ui_screens.gd` :
  - `_build_character_select_v4()` (с ~749): блок сборки досье ~812–887 — добавить строку оружия и заменить `stats_grid` на VBox строк «иконка+название+бар+значение»; завести словарь `stat_bars`.
  - замыкание `refresh` (951→), блок ~958–965 — заполнять `weapon_label`, бары/значения статов из `stats` и захваченного `stat_maxima`.
  - переиспользовать `_hero_weapon_names()` (1689) и `_hero_radar_global_maxima()` (1678) — НЕ дублировать логику.
- `scripts/ui_icon_registry.gd` : `make_icon` / `texture_for` / `ICON_COLORS` / `ICON_PATHS` — только чтение, иконки статов уже есть. Менять НЕ нужно.
- `scripts/progression_data.gd` : `weapon_ids` (411) / `weapon` (764) / `STAT_NAMES` — только чтение. **НЕ менять (locked path).**
- `tests/runtime_smoke_test.gd`, `tests/ui_no_overlap_matrix_test.gd` — прогон; при добавлении новых проверок (опц.) держать совместимость, имена узлов не ломать.

## Замечания / подводные камни

- **Locked / anti-collision:** `scripts/progression_data.gd` — locked, в этой задаче только читать (`weapon`, `weapon_ids`, `STAT_NAMES`). `scripts/ui_screens.gd` — крупный общий файл; правки держать строго внутри `_build_character_select_v4` и его замыкания `refresh`, не задевать соседние экраны (легаси-v3 `_build_character_select_v3`, кодекс, шоп). Не трогать `ui_icon_registry.gd`.
- **Тикет ссылается на устаревшие строки 792–844 / «GridContainer»** — это легаси-v3 описание. Актуальная цель — `_build_character_select_v4`. Не реанимировать v3.
- **`make_icon` может вернуть фолбэк** (PanelContainer с аббревиатурой), если PNG не загрузился — это нормально, раскладка не должна на это полагаться по размеру: всегда задавать `custom_minimum_size`.
- **Влезаемость на 1280x720** — главный риск. Утолщённые строки статов + новая строка оружия съедают вертикаль досье; `spacer` (SIZE_EXPAND_FILL) при переполнении схлопнется и пойдут overlap, которые поймает матрица. Размеры иконки/бара/шрифта вязать к `vp.y`, при необходимости ужать `dossier.separation`.
- **`ProgressBar` и mouse_filter:** ставить `MOUSE_FILTER_IGNORE` на бар, иконки, лейблы и контейнеры строк, чтобы не перехватывать клики карусели/кнопок (как везде в этом экране).
- **Матрица peer-overlap** сравнивает контролы попарно с tolerance 2px — строки статов в одном VBox не пересекаются по построению, но следить, чтобы внутри `HBox` бар (EXPAND_FILL) не «вылезал» за границы строки при экстремально длинном названии стата (использовать min-width у бара/значения, либо clip).
- **Не менять имена** `HS4Portrait/HS4Radar/HS4Carousel/HS4ChooseButton` — на них завязаны оба теста.
- **Связанные тикеты:** эпик SCRUM-470 (Hero Select v4), carry-over из него. Координатная спека панели — `HS4_DOSSIER` (697); если double-проверяется UI-render-verifier (SCRUM-483), убедиться, что новые узлы попадают в безопасную зону панели, а не на орнамент рамки.

## QA-Вердикт (2026-06-28, Codex QA)
Статус: PASSED
Проверено:
- Live Jira: SCRUM-493 был в `Контроль качества`; QA claim: `codex-qa-493-codex190501`.
- Структура `scripts/ui_screens.gd`: `HS4Weapon` добавлен после описания, заполняется через `_hero_weapon_names(cid)`, single-line trim ellipsis.
- 5 строк `HS4StatRow_<sid>` для `strength/agility/intelligence/endurance/perception`: иконка через `UIIconRegistry.make_icon`, имя стата, `ProgressBar`, числовое значение.
- `ProgressBar.max_value` берётся из `_hero_radar_global_maxima()`, `value` = текущий стат с clamp.
- Цвет fill берётся из `UIIconRegistry.ICON_COLORS`.
- Выбор/смена героя обновляет weapon row и значения статов.

Тесты/evidence:
- `Godot_v4.7-stable_win64_console.exe --headless --path . --import` -> PASS.
- `Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/qa_scrum493_check.gd` -> PASS (временный QA-only скрипт удалён после проверки).
- `Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/runtime_smoke_test.gd` -> PASS.
- `Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/ui_no_overlap_matrix_test.gd` -> PASS.

Баги: нет.
