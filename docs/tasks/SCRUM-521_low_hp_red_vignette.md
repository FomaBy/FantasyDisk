# SCRUM-521: Low HP warning: лёгкая красная виньетка при HP < 30%

Jira: SCRUM-521 · Роль: backend (codex) · Контур: codex · Приоритет: P1 · foma · Эпик: SCRUM-215
Статус: done

Owner: backend/codex-background-backend-agent
Locked paths: `scripts/ui_screens.gd`, `tests/runtime_smoke_test.gd`, `docs/design/systems/menus_ui.md`, `docs/design/current_game_state.md`, `docs/tasks/SCRUM-521_low_hp_red_vignette.md`

## Что и зачем

Игрок должен «чувствовать» опасную просадку здоровья периферийным зрением, не отвлекаясь на чтение цифр HP в углу HUD. Пользователь попросил мягкую красную виньетку по краям экрана, когда текущее HP падает ниже 30% от максимума.

Цель с точки зрения игрока: в напряжённый момент боя (много мобов, снаряды, нужно микрить позицию) взгляд прикован к центру арены — к своему персонажу и врагам. Красное свечение по периметру экрана — это атмосферный сигнал «ты на грани», который читается боковым зрением мгновенно. Эффект должен быть лёгким и стильным (dark fantasy), а не агрессивным «red screen of death»: он не должен перекрывать монстров, снаряды, loot, HUD-элементы и flow level-up/reward.

Ожидаемый результат:
- HP опускается ниже 30% → по краям экрана плавно проявляется мягкая красная виньетка.
- HP восстанавливается до 30%+ → виньетка плавно гаснет.
- Эффект стабилен у самого порога (нет мигания при дёргающемся HP — regen/тики/вампиризм).
- Ничего в балансе/уроне/regen/death-flow/input не меняется — это чисто визуальный оверлей.

## Текущее состояние в коде

Боевой HUD строится как отдельный `CanvasLayer` и обновляется каждый кадр — туда и встраивается виньетка.

- `scripts/ui_screens.gd:7553` `_create_hud()` — создаёт `game.hud_layer` (`CanvasLayer`, `PROCESS_MODE_ALWAYS`), внутри — `Control` с `name = "CombatHudRoot"`, `PRESET_FULL_RECT`, `mouse_filter = MOUSE_FILTER_IGNORE`. Дальше дёргает `_create_resource_hud_panel`, `_create_combat_timer_panel`, `_create_artifact_hud_row`, `_create_damage_flash_overlay(root)`. Это точка, куда добавляем создание узла виньетки.
- `scripts/ui_screens.gd:7843` `_create_damage_flash_overlay(root)` — ЭТАЛОННЫЙ ПАТТЕРН. Создаёт `ColorRect` с `name = "DamageFlashOverlay"`, `PRESET_FULL_RECT`, `color = Color(0.85, 0.08, 0.06, 1.0)`, `modulate.a = 0.0`, `mouse_filter = MOUSE_FILTER_IGNORE`, `process_mode = PROCESS_MODE_PAUSABLE`. Это сплошная заливка-вспышка на весь экран по одному событию урона. Виньетка отличается: (1) свечение только по краям, а не сплошняком, (2) управляется порогом HP, а не разовым твином.
- `scripts/ui_screens.gd:7855` `_on_player_damaged(_amount)` — обработчик сигнала `damaged`: гасит/перезапускает твин у `DamageFlashOverlay` (пик `a = 0.20`, спад до `0.0` за `0.32с`). Подключается в `scripts/combat_director.gd:48-49` (`game.current_player.damaged.connect(game.ui._on_player_damaged)`). НЕ использовать как драйвер виньетки: урон может уронить HP ниже порога, но это разовое событие, а виньетка должна держаться, пока HP ниже порога.
- `scripts/ui_screens.gd:8026` `_update_hud()` — вызывается КАЖДЫЙ КАДР из `scripts/main.gd:761` (`ui._update_hud()` внутри `_process`, который ранним `return` выходит при паузе и вне боя). Это естественный per-frame драйвер виньетки. В начале функции уже считаются `max_hp` и `hp`:
  - `var values: Dictionary = _run_resource_values()`
  - `var max_hp: float = max(float(values["max_hp"]), 1.0)`
  - `var hp: float = clamp(float(values["hp"]), 0.0, max_hp)`
  Важно: функция делает раннюю отсечку по снапшоту `if game._last_hud_snapshot == next_snapshot: return` (строки 8052-8053). Снапшот хранит HP, ОКРУГЛЁННЫЙ до int (`"hp": int(ceil(hp))`). Значит обновление виньетки нельзя ставить ПОСЛЕ этого `return`, иначе при стабильном HP оно не отработает. Ставить обновление виньетки ДО снапшот-отсечки (сразу после вычисления `hp`/`max_hp`).
- `scripts/ui_screens.gd:7993` `_run_resource_values()` — источник HP. Если есть живой `game.current_player` — берёт `health`/`max_health` с него; ИНАЧЕ фоллбэчит на `game.run_player_snapshot` (там HP может быть равно max или прошлому значению). Меню-HUD (`_create_menu_run_hud`, `scripts/ui_screens.gd:7871`) тоже использует `_update_hud`, но НЕ создаёт боевой `CombatHudRoot`/`DamageFlashOverlay` — там виньетки нет. Поэтому код обновления виньетки должен gracefully ничего не делать, если узел виньетки не найден (см. `_on_player_damaged`, который ровно так и выходит: `find_child(...) == null -> return`).
- `scripts/ui_screens.gd:7856` показывает идиому доступа к оверлею: `game.hud_layer.find_child("DamageFlashOverlay", true, false) as ColorRect`, с guard `if game.hud_layer == null or not is_instance_valid(game.hud_layer): return`.
- `scripts/player.gd:1216` `_combat_feedback_enabled()` → `bool(get_tree().root.get_meta("combat_feedback", true))`. Настройка доступности «боевой фидбек» (тумблер в настройках, `scripts/ui_screens.gd:3296-3302`, дублируется в `root` meta `combat_feedback`). Виньетку логично гейтить этим же тумблером — это интенсивный экранный эффект.

ВАЖНО — НЕ путать с уже существующим `_low_hp_active`:
- `scripts/player.gd:173` `var _low_hp_active := false`, `scripts/player.gd:682` `_update_low_hp_state()` (зовётся из `_physics_process`, `scripts/player.gd:416`) — это механика артефакта «Кровавый Рубеж» (`blood_pact`, `low_hp_damage_bonus`): даёт +урон, пока HP < 30%. Функция РАНО выходит, если у игрока нет мода `low_hp_damage_bonus` (`scripts/player.gd:683-684`), поэтому её НЕЛЬЗЯ переиспользовать как универсальный «player at low HP» флаг для визуала — у большинства ранов мода нет, и `_low_hp_active` останется `false`. Порог 30% совпадает (`max_health * 0.3`), но это совпадение значения, а не общий источник истины. Визуальную виньетку считать НЕЗАВИСИМО по `hp < max_hp * 0.3` в HUD-слое.

## Что сделать — по шагам

1. **Создать узел виньетки в боевом HUD.** В `scripts/ui_screens.gd` добавить функцию `_create_low_hp_vignette(root: Control)` по образцу `_create_damage_flash_overlay` и вызвать её из `_create_hud()` (рядом со строкой 7568, после `_create_damage_flash_overlay(root)`). Узел:
   - `name = "LowHpVignetteOverlay"`, `PRESET_FULL_RECT`, `mouse_filter = MOUSE_FILTER_IGNORE`, `process_mode = PROCESS_MODE_PAUSABLE` (как у flash — затухание/проявление замирает на паузе).
   - Эффект «по краям, не по центру»: НЕ делать сплошной `ColorRect` на весь экран (это перекроет монстров/loot). Варианты (выбрать один, проще — A):
     - **(A) Радиальный градиент через шейдер.** `ColorRect` на весь экран с `ShaderMaterial`. Фрагмент: `UV` → расстояние от центра `d = distance(UV, vec2(0.5))`; альфа растёт к краям, например `a = smoothstep(inner, outer, d)` с `inner ≈ 0.55`, `outer ≈ 0.95`, цвет `vec3(0.7, 0.04, 0.04)`. Итоговый `COLOR = vec4(color, a * intensity)`, где `intensity` — `uniform`, который HUD анимирует. Центр экрана остаётся прозрачным → монстры/loot видны. Шейдер можно встроить как `Shader.new()` с `code = "..."` прямо в GDScript (без отдельного .gdshader файла) либо положить `.gdshader` в `assets/shaders/` — на усмотрение исполнителя; инлайн проще и держит изменения в одном locked-файле.
     - **(B) Текстура-рамка.** Заранее сгенерированный PNG с прозрачным центром и красным свечением по периметру через `TextureRect` (`expand_mode = EXPAND_IGNORE_SIZE`, `stretch_mode = STRETCH_SCALE`). Требует ассета — тяжелее, согласовывать с asset-pipeline. Для P1-задачи предпочесть (A).
   - Стартовая видимость: невидимая. Для шейдерного варианта — `intensity = 0.0`; либо держать `modulate.a = 0.0` и анимировать его (как flash). Хранить «целевую» силу/состояние через `set_meta`, как делает flash (`flash.set_meta("flash_tween", tween)`).
   - Пиковая альфа — ЛЁГКАЯ. Ориентир: максимум `a ≈ 0.22–0.30` у самого края, к центру → 0. Не делать «кровавый экран».

2. **Драйвить виньетку из `_update_hud()` по порогу с гистерезисом.** Сразу после вычисления `hp`/`max_hp` (после `scripts/ui_screens.gd:8032`, но ДО снапшот-отсечки на 8052) вызвать новый хелпер `_update_low_hp_vignette(hp, max_hp)`. Логика хелпера:
   - Guard: `if game.hud_layer == null or not is_instance_valid(game.hud_layer): return`. Найти узел `find_child("LowHpVignetteOverlay", true, false)`; если `null` (меню-HUD) → `return`.
   - Гейт по настройке: если `not bool(get_tree().root.get_meta("combat_feedback", true))` → принудительно погасить (target intensity = 0, можно мгновенно) и `return`.
   - **Гистерезис** (анти-мигание у порога): два порога вместо одного.
     - Включение: `hp < max_hp * 0.30`.
     - Выключение: `hp >= max_hp * 0.34` (запас ~4% над порогом).
     - Между порогами — сохранять текущее состояние. Хранить `bool` состояние в `set_meta("vignette_active", ...)` на узле (или в переменной поля класса; не плодить новых полей в `main.gd` без нужды — meta достаточно).
   - **Плавность (fade):** при смене состояния запускать `create_tween()` на параметр интенсивности/`modulate:a`:
     - Появление: к пиковой силе за ~`0.35–0.5с`, `TRANS_SINE`/`TRANS_QUAD`, `EASE_OUT`.
     - Исчезновение: к 0 за ~`0.4–0.6с`, `EASE_IN`/`EASE_OUT`.
     - Перед запуском нового твина гасить предыдущий: `var t: Tween = node.get_meta("vignette_tween") if node.has_meta("vignette_tween") else null; if t != null and t.is_valid(): t.kill()`, затем `node.set_meta("vignette_tween", new_tween)` — ровно как во flash (`scripts/ui_screens.gd:7861-7868`).
     - Опционально: лёгкая «дышащая» пульсация интенсивности в активном состоянии (loop-твин ±10–15%) для атмосферы — но это nice-to-have, не делать, если рискует мигать или усложнять. По умолчанию — ровная статичная виньетка.
   - НЕ переключать состояние/не перезапускать твин, если целевое состояние не изменилось (как `if active == _low_hp_active: return` в player.gd) — иначе твин будет дёргаться каждый кадр.

3. **Не ломать z-order и читаемость.** Узел виньетки добавляется в `CombatHudRoot`. Проверить порядок дочерних узлов: виньетка должна быть НИЖЕ интерактивных/информационных HUD-панелей (таймер, ресурс-карты HP/XP/gold, артефакты, кнопка level-up), чтобы не «затуманивать» цифры и иконки. Поскольку это градиент с прозрачным центром, панели по углам всё равно частично попадают в зону свечения — убедиться, что свечение мягкое и текст HUD остаётся читаемым (свечение по самому периметру, панели чуть внутрь). Виньетка НЕ должна перехватывать ввод (`MOUSE_FILTER_IGNORE`) и не должна жить в слоях level-up/reward/pause (она в `hud_layer`, который и так чистится при выходе из боя через `_clear_hud`, `scripts/main.gd:884`).

4. **Тест/доказательство.** Добавить focused-проверку в существующий smoke (предпочтительно `tests/runtime_smoke_ui_test.gd` рядом с `_test_hud_no_overlap_layouts`, либо в combat-секцию `tests/runtime_smoke_test.gd` рядом с проверкой `DamageFlashOverlay`, `scripts/...test.gd:659-667`). Сценарий:
   - Поднять combat-HUD c живым player (см. паттерн `_assert_shop_wall_layout_at_size`/`_test_hud_no_overlap_layouts`: `main_scene.instantiate()`, `Player.tscn`, `configure_character("berserk","sword")`), убедиться что виньетка есть: `main.find_child("LowHpVignetteOverlay", true, false) != null`.
   - **Выше порога:** `player.set("health", max_health * 0.9)`, дёрнуть `main.call("_update_hud")` (или прокрутить пару `await process_frame` с `combat_active`), убедиться что виньетка скрыта (intensity/`modulate.a` ≈ 0, ниже малого эпсилона). Учесть, что появление идёт через твин — либо проверять «целевое» состояние/meta `vignette_active == false`, либо домотать твин (`await` достаточного числа кадров / напрямую выставить значение в тесте). Проще — ассертить флаг `vignette_active`/целевую интенсивность, а не сиюминутную альфу в момент анимации.
   - **Ниже порога:** `player.set("health", max_health * 0.1)`, прокрутить HUD, убедиться что виньетка активна (`vignette_active == true`, целевая интенсивность > 0; либо `modulate.a` дорос до пика после доигрывания твина).
   - **Гистерезис:** между 0.30 и 0.34 состояние не дёргается (опционально, если просто).
   - Эффект гейта: при `root.set_meta("combat_feedback", false)` виньетка гаснет/не появляется (опционально).
   - Тест должен PASS headless (Godot 4.6.3, `~/Downloads/Godot.app`, headless smoke-прогон по QA-памятке).

## Acceptance Criteria

- [x] При HP игрока ниже 30% (`hp < max_hp * 0.30`) по краям экрана плавно проявляется лёгкая красная виньетка.
- [x] При восстановлении HP до 30%+ (с гистерезисом — до 34%) виньетка плавно исчезает.
- [x] Эффект — градиент с прозрачным центром: НЕ перекрывает монстров, projectiles, loot и критичные HUD-элементы (таймер, HP/XP/gold карты, артефакты, кнопка level-up); текст HUD остаётся читаемым.
- [x] Виньетка не появляется/не висит на экранах level-up, reward-flow, pause, route-map и в главном меню (живёт только в боевом `hud_layer`, чистится `_clear_hud` при выходе из боя).
- [x] Виньетка не мигает при частых изменениях HP около порога: гистерезис (30%/34%) + fade-твин на появление и исчезновение; состояние не перезапускается каждый кадр.
- [x] Эффект уважает тумблер «боевой фидбек» (`root` meta `combat_feedback`): при выключенном — виньетки нет.
- [x] Пиковая интенсивность лёгкая (альфа края ≈ 0.22–0.30, к центру → 0); это не «red screen», а атмосферный периферийный сигнал.
- [x] Runtime/UI smoke (или focused low-HP visual smoke) подтверждает: виньетка активна ниже порога и отсутствует выше порога. Тест PASS headless.
- [x] Баланс, урон, regen, вампиризм, death-flow и input-handling НЕ изменены. Существующий `_low_hp_active`/`blood_pact` (`scripts/player.gd:682`) не тронут и не конфликтует.
- [x] Существующие smoke-тесты (включая проверку `DamageFlashOverlay`) не сломаны.

## Результат

2026-06-27, backend/codex-background-backend-agent:

- Добавлен `LowHpVignetteOverlay` в боевой `CombatHudRoot`: полноэкранный `ColorRect` с инлайн radial-vignette `ShaderMaterial`, прозрачным центром и мягкими красными краями.
- Виньетка включается при `hp / max_hp < 0.30`, выключается при `>= 0.34`, хранит target-state в meta и не перезапускает fade-твин каждый кадр.
- Overlay рисуется за HUD-карточками (`root.move_child(vignette, 0)`), игнорирует мышь, использует `PROCESS_MODE_PAUSABLE`, уважает `combat_feedback=false` и гасится сразу при отключённом боевом фидбеке.
- `_update_hud()` вызывает `_update_low_hp_vignette(hp, max_hp)` до snapshot early-return; HP/XP/reward/death/balance логика не менялась, `player.gd` не тронут.
- UI-director note: нового mockup/art pass не делалось, потому что задача реализует процедурный runtime combat overlay без frame/content placement и без новых raster assets; применён существующий HUD safe-zone contract, overlay находится за HUD content.
- Документация обновлена: `docs/design/systems/menus_ui.md`, `docs/design/current_game_state.md`.

Проверки:

- PASS: `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path "/Users/sergeyfomin/Documents/AI Agent" --script res://tests/runtime_smoke_test.gd`
- PASS: `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path "/Users/sergeyfomin/Documents/AI Agent" --script res://tests/runtime_smoke_ui_test.gd`

## QA-Вердикт (2026-06-28)
Статус: PASSED
Проверено:
- Jira SCRUM-521 comments/evidence прочитаны: executor указал pushed origin/dev commit `2bad5510`, но этот SHA больше не доступен в локальных/remote refs; независимая QA выполнена на текущем `origin/dev` HEAD `bef946b8`, где реализация SCRUM-521 присутствует.
- Static inspection: `LowHpVignetteOverlay` создаётся только в combat HUD, расположен за HUD-картами (`move_child(vignette, 0)`), `mouse_filter = MOUSE_FILTER_IGNORE`, прозрачный центр задаётся radial shader; пороги `0.30`/`0.34`, alpha `0.26`, fade-in/out `0.42`/`0.50`.
- Threshold behavior: automated smoke проверяет inactive at 90% HP, active at 20% HP, hysteresis stays active at 32%, fades out at 36%, and `combat_feedback=false` forces off.
- UI/no-overlap: HUD smoke matrix покрывает 1152x648, 1280x720, 2560x1440 в battle и boss HUD; overlay не участвует в layout и расположен под карточками, поэтому не создаёт пересечений controls.
- Obstruction/perf: прозрачный центр и мягкий edge alpha не закрывают центр боя; shader/material создаются один раз, tween запускается только при смене состояния, per-frame allocation loop не найден.
Команды:
- PASS: `Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/runtime_smoke_ui_test.gd`
- PASS: `Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/runtime_smoke_combat_test.gd`
- PASS: `Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tests/runtime_smoke_test.gd`
Краевые случаи:
- Cold disposable worktree сначала требовал import-cache warm-up (`--editor --quit`); после прогрева все required smokes прошли.
- Проверены HP above/below threshold, heal/damage-style threshold transitions, hysteresis band, disabled combat feedback, z-order, input ignore.
Баги: нет.

## Files / точки входа

- `scripts/ui_screens.gd:7553` `_create_hud()` — добавить вызов `_create_low_hp_vignette(root)` после `_create_damage_flash_overlay(root)` (рядом со строкой 7568).
- `scripts/ui_screens.gd` (новая функция, рядом с 7843 `_create_damage_flash_overlay`) `_create_low_hp_vignette(root: Control)` — создать `ColorRect`/`TextureRect` `LowHpVignetteOverlay` (предпочтительно `ColorRect` + инлайн `ShaderMaterial` с радиальным градиентом), невидимый на старте, `MOUSE_FILTER_IGNORE`, `PROCESS_MODE_PAUSABLE`.
- `scripts/ui_screens.gd:8026` `_update_hud()` — после вычисления `hp`/`max_hp` (~строка 8032) и ДО снапшот-отсечки (~строка 8052) вызвать `_update_low_hp_vignette(hp, max_hp)`.
- `scripts/ui_screens.gd` (новая функция) `_update_low_hp_vignette(hp: float, max_hp: float)` — guard на `hud_layer` и наличие узла; гейт `combat_feedback`; гистерезис 30%/34%; fade-твин с `kill()` предыдущего; хранение состояния в meta. Образец твин-идиомы — `_on_player_damaged` (`scripts/ui_screens.gd:7855-7868`).
- `tests/runtime_smoke_ui_test.gd` (или combat-секция `tests/runtime_smoke_test.gd` рядом с 659) — focused low-HP visual smoke: поднять combat-HUD, проверить наличие узла, состояние ниже/выше порога.

## Замечания / подводные камни

- **LOCKED PATHS.** Задача целиком ложится в locked-файлы `scripts/ui_screens.gd` и `scripts/player.gd` (последний — только для чтения паттерна `_combat_feedback_enabled`; менять player.gd НЕ требуется). Координироваться по anti-collision: не брать параллельно с другими задачами, трогающими `ui_screens.gd` (HUD/боевой оверлей). `scripts/progression_data.gd` НЕ трогать (там `blood_pact` definition — только чтение).
- **НЕ переиспользовать `_update_low_hp_state`/`_low_hp_active`** из `player.gd` как источник истины для визуала — он завязан на мод `low_hp_damage_bonus` и для большинства ранов всегда `false` (`scripts/player.gd:683-684`). Виньетку считать независимо в HUD по `hp < max_hp * 0.3`.
- **Снапшот-отсечка в `_update_hud`.** `if game._last_hud_snapshot == next_snapshot: return` (строки 8052-8053) и тот факт, что HP в снапшоте округлён до int, означают: (1) обновление виньетки ставить ДО этого return; (2) около порога HP может «застывать» на одном int-значении — гистерезис всё равно нужен из-за тиков regen/урона, которые сдвигают дробный HP.
- **Меню-HUD.** `_create_menu_run_hud` (`scripts/ui_screens.gd:7871`) тоже зовёт `_update_hud`, но НЕ создаёт `LowHpVignetteOverlay`. Хелпер обязан gracefully выходить, если узел не найден (как `_on_player_damaged`). Иначе — краш/ошибки в меню.
- **`_run_resource_values` фоллбэк на снапшот.** Вне боя (нет `current_player`) HP берётся из `run_player_snapshot` и может быть низким (после боя). Поскольку виньетка живёт только в боевом `hud_layer` и `_process` рано выходит вне боя (`scripts/main.gd:747-748`), ложного срабатывания в меню быть не должно — но это ещё одна причина строго привязать узел к combat-HUD и выходить, если узла нет.
- **Пауза.** `hud_layer` — `PROCESS_MODE_ALWAYS`, но узлу виньетки задать `PROCESS_MODE_PAUSABLE`, чтобы fade-твин замирал на паузе (как у `DamageFlashOverlay`, `scripts/ui_screens.gd:7851`). `_process` в `main.gd` всё равно рано выходит на паузе, так что во время level-up/pause `_update_hud` из основного цикла не дёргается — состояние виньетки замрёт корректно.
- **Шейдер vs текстура.** Инлайн-шейдер (`Shader.new()` + `code`) держит всё в одном locked-файле и не требует прохода через asset-generator; предпочтительно для P1. Если выбран текстурный вариант — согласовать ассет через fantasydisk-asset-generator (прозрачный фон), но это расширяет scope.
- **Производительность.** Полноэкранный `ColorRect` с простым радиальным шейдером дёшев; не плодить твины каждый кадр (запускать только при смене состояния). Не аллоцировать новый шейдер/материал каждый кадр — создать один раз в `_create_low_hp_vignette`.
- **Связанные тикеты/эпик:** SCRUM-215 (combat feel/feedback эпик). Родственный визуал — `DamageFlashOverlay` (вспышка по урону) и `_shake_camera` (`scripts/combat_director.gd:74`); виньетка — третий слой того же «боевого фидбека» и логично гейтится тем же тумблером `combat_feedback`.
- **Метки тикета:** backend, codex, combat, p1, ui, visual-feedback, health-warning, foma.
