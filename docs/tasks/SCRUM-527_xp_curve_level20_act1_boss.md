# SCRUM-527: Кривая опыта: ~20 lvl к боссу 1-го акта

Jira: SCRUM-527 · Роль: backend · Контур: claude · Приоритет: P2 · foma · Эпик: SCRUM-522
Статус: К выполнению

## Что и зачем

Цель — перекалибровать XP-кривую так, чтобы средний забег к боссфайту 1-го акта приводил игрока примерно к **20-му уровню** (а не к 8-9, как сейчас). Уровень — главный источник ощущения роста: каждый level-up даёт выбор усиления (карточка 1-из-3) и редкий рост основной характеристики. Сейчас игрок добегает до босса всего на 8-9 уровне, level-up'ы происходят редко, и забег ощущается «плоским» — мало точек принятия решений, слабая обратная связь по прогрессии.

Дополнительно текущая кривая **взрывается экспоненциально**: требуемый опыт растёт с множителем 1.42 за уровень, поэтому даже если докинуть XP, поздние уровни становятся недостижимы (L19→20 требует 7356 XP за один уровень против 5 на старте). Нужна **плавная** кривая: разрыв между соседними требованиями растёт мягко, без резких скачков.

Ожидаемый результат:
- средний забег (3 репрезентативных маршрута модели) даёт ~20 уровней к/включая boss reward 1-го акта;
- прогрессия плавная — отношение `req(L+1)/req(L)` стабильно невысокое, без экспоненциальных спайков;
- отчёт `build/route_economy_xp_model.md` перегенерён, колонка **Levels** показывает целевые числа;
- progression smoke-тесты зелёные.

## Текущее состояние в коде

### XP-кривая — две константы (источник истины)
`scripts/progression_data_balance.gd`:
- Строка 186: `const XP_CURVE_MULTIPLIER := 1.42`
- Строка 188: `const XP_CURVE_FLAT := 3.0`

Реэкспорт в `scripts/progression_data.gd:51-52` (`const XP_CURVE_MULTIPLIER := BalanceData.XP_CURVE_MULTIPLIER`). **Менять значения нужно в `progression_data_balance.gd`** — `progression_data.gd` подхватит автоматически.

### Формула шага кривой
`scripts/progression_data.gd:368-369`:
```gdscript
static func next_xp_requirement(current_requirement: int) -> int:
	return maxi(1, int(ceil(float(current_requirement) * XP_CURVE_MULTIPLIER + XP_CURVE_FLAT)))
```
То есть требование на следующий уровень = `ceil(req * 1.42 + 3.0)`. Геометрический рост с коэффициентом 1.42 — это и есть причина экспоненты.

### Где кривая применяется в игре
`scripts/player.gd`:
- Строка 149: `var xp_to_next := 5` — стартовое требование (L1→L2).
- Строка 225: тот же `xp_to_next = 5` при сбросе игрока на старте забега.
- Строки 1416-1422 — игровой цикл начисления опыта и level-up:
```gdscript
func gain_xp(amount: int) -> void:
	xp += maxi(1, int(round(float(amount) * float(run_modifiers.get("xp_gain_multiplier", 1.0)))))
	while xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		xp_to_next = ProgressionData.next_xp_requirement(xp_to_next)
		leveled_up.emit()
```
`xp_to_next` пересчитывается рекуррентно от предыдущего значения — стартовая точка `5` плюс множитель/флэт полностью задают всю кривую.

### Сколько узлов в акте до босса
`scripts/main.gd:26`: `const ROUTE_STEPS_TO_BOSS := 10`. Маршрут — 10 шагов (бои/события/магазины/отдых/апгрейды), на 11-й позиции (row 10) — босс (`scripts/route_map_screen.gd:189-214`, `_generate_route()` плюс `_random_boss_route_node()`). Первый шаг гарантированно battle (строки 203-210). Боссы 1-го акта: rift_warden / disk_devourer / bone_archon / brood_mother / ashen_colossus (`route_map_screen.gd:217-247`).

### Откуда берётся XP за забег
`scripts/combat_director.gd` — три точки начисления:
- строки 870-883: за зачистку боевого узла — `xp_reward = 3 + route_stage` (элита: `7 + route_stage*2`), плюс event-множители;
- строка 722: подбор XP-пикапов с убитых врагов (`gain_xp(amount)`), где amount = `reward_xp` из `drop_class_rewards()` (`combat_director.gd:434-441`);
- строки 641-653: boss completion reward — `drop_class_rewards("boss", ...).xp`.

XP per kill считает `ProgressionData.drop_class_rewards(drop_class, route_stage, wave_index)` (`progression_data.gd:376-392`): для boss `xp = round(24.0 * stage_scale)`, для остальных `base_xp = round(1 + max(scale-1,0)*0.35 + wave*0.008)` затем `* DROP_CLASS_MULTIPLIERS[class].xp`. `DROP_CLASS_MULTIPLIERS` — `progression_data_balance.gd:190-197`.

### Канонический симулятор среднего забега (главный инструмент для AC)
`tools/route_economy_xp_model.gd` — детерминированная модель 3 репрезентативных маршрутов (Balanced / Combat-Heavy / Shop-Rest), пишет отчёт `build/route_economy_xp_model.md`. Введён SCRUM-188, расширен SCRUM-507 (тот же эпик).
- `_route_fixtures()` (строки 88-139): три маршрута по 10-11 узлов с финальным `boss`-узлом.
- `_simulate_route()` (строки 142-209): суммирует XP по узлам через `drop_class_rewards()` и считает уровни.
- **`_level_state(expected_xp)` (строки 243-251) — точная копия игрового цикла**: `xp_to_next = 5`, цикл `while xp >= xp_to_next: levels += 1; xp_to_next = ProgressionData.next_xp_requirement(...)`. Колонка **Levels** в отчёте = именно это число. Это и есть «симуляция среднего забега → N lvl на боссе» из acceptance.
- `_tempo_decision()` (строки 278-292): сейчас жёстко зашит вывод «keep the current XP tempo» и фраза про средние level-ups. Этот текст нужно обновить под новую цель (см. шаги).

**Замеренный baseline текущей кривой (1.42 / 3.0) по этой модели:**

| Маршрут | Узлов | Expected XP | Levels (СЕЙЧАС) |
| --- | ---: | ---: | ---: |
| Balanced | 10 | ~497 | **8** |
| Combat-Heavy | 11 | ~708 | **9** |
| Shop/Rest | 10 | ~492 | **8** |

Цель — поднять колонку Levels до ~18-20 (в среднем ≈20).

### Прочие отчёты, печатающие формулу кривой (обновятся автоматически из констант)
- `tools/balance_harness.gd:420` — строка таблицы `| XP curve next-level formula | ... | ceil(req*%.2f+%.0f) | ...`.
- `tools/route_economy_xp_model.gd:338` — `| XP curve | ... | ceil(req*%.2f+%.0f) | guarded |`.
Оба читают `ProgressionData.XP_CURVE_MULTIPLIER/FLAT` — текст подтянется сам после смены констант и перегенерации.

## Что сделать — по шагам

1. **Снять baseline.** Перегенерировать модель текущим кодом (команда в Files), убедиться что колонка Levels = 8/9/8 (Balanced/Combat-Heavy/Shop-Rest). Это точка отсчёта.

2. **Перекалибровать кривую — две константы в `progression_data_balance.gd`:**
   - `XP_CURVE_MULTIPLIER` (строка 186): снизить с `1.42` примерно до **1.05–1.08**. Это убирает экспоненту и делает рост требований плавным.
   - `XP_CURVE_FLAT` (строка 188): снизить с `3.0` примерно до **1.0–2.0**.

   Грубый аналитический ориентир (проверять по факту прогоном модели — числа ниже из реплики `_level_state`/`drop_class_rewards`, без правки XP-дохода, `xp_to_next` старт = 5):

   | mult | flat | Levels [Balanced, Combat-Heavy, Shop/Rest] | среднее |
   | ---: | ---: | --- | ---: |
   | 1.08 | 1.0 | [17, 20, 17] | 18.0 |
   | 1.07 | 1.0 | [17, 20, 17] | 18.0 |
   | 1.06 | 1.0 | [18, 21, 18] | 19.0 |
   | 1.05 | 1.0 | [18, 22, 18] | 19.3 |

   Точное значение подбирать итеративно так, чтобы среднее по трём маршрутам легло в ~18-20, а медленный Balanced/Shop-маршрут не проседал сильно ниже 18. **Менять ТОЛЬКО эти две константы** — это самый хирургический рычаг, целиком отвечающий за форму кривой.

3. **(Опционально, если только curve-правка не дотягивает до ~20)** — допустимы вспомогательные рычаги, но строго после попытки шага 2 и осознанно:
   - снизить стартовое `xp_to_next` с 5 (`player.gd:149` И `player.gd:225` — синхронно оба места; плюс `route_economy_xp_model.gd:6` `START_XP_TO_NEXT`, чтобы модель совпадала с игрой);
   - либо мягко поднять XP-доход (множители `xp` в `DROP_CLASS_MULTIPLIERS`, `progression_data_balance.gd:190-197`, или коэффициент `0.35` в `base_xp`, `progression_data.gd:386`). ВНИМАНИЕ: правка XP-дохода косвенно меняет экономику смежного SCRUM-507 — предпочесть чистую curve-правку (шаг 2) и трогать доход в последнюю очередь.

   Замечание по `xp_to_next` старт: модель `_level_state` использует свою константу `START_XP_TO_NEXT = 5` (`route_economy_xp_model.gd:6`), а игра — литералы `5` в `player.gd:149,225`. Эти значения ОБЯЗАНЫ совпадать, иначе отчёт разойдётся с реальной игрой. Если меняешь старт — меняй во всех трёх местах.

4. **Итеративно перегенерировать отчёт** после каждой правки констант, читать таблицу Route Results → колонка Levels, добиваться среднего ~20. Подбор — компромисс между быстрым Combat-Heavy и медленными Balanced/Shop.

5. **Обновить текст `_tempo_decision()`** (`route_economy_xp_model.gd:278-292`): сейчас он жёстко утверждает «keep the current XP tempo» и называет старые средние level-ups. Переписать под новую цель — констатировать новый средний уровень к боссу (~20) и что кривая перекалибрована под SCRUM-527. Иначе отчёт будет внутренне противоречив (таблица показывает 20, текст говорит «оставляем как есть»).

6. **Проверить плавность кривой.** Распечатать/прикинуть ряд `req(L)` для L=1..22 при новых константах и убедиться, что нет резких скачков: отношение `req(L+1)/req(L)` должно быть ≈ множителю (1.05-1.08) и стабильным, а не расти. Зафиксировать ряд в отчёте/коммите как «цифры в отчёте» из acceptance.

7. **Прогнать progression smoke-тесты** headless, добиться зелёного (команды в Files). Особое внимание — ассерт `next_xp_requirement(5) > 0` (`tests/progression_data_api_surface_test.gd:61-62`): новая формула обязана остаться положительной (она `maxi(1, ...)`, так что safe, но проверить).

8. **Обновить дизайн-доки**, если ссылаются на старую формулу/темп: проверить `docs/design/current_game_state.md` и `docs/design/mechanics_extract.md` на упоминания `XP_CURVE_MULTIPLIER = 1.42` / «8-9 level-ups» и привести в соответствие. (Грепнуть `XP_CURVE`, `1.42`, `level-up`, `опыт`.)

## Acceptance Criteria

- [ ] **AC1.** Симуляция среднего забега через `tools/route_economy_xp_model.gd` → колонка **Levels** в `build/route_economy_xp_model.md` показывает ~20 уровней к/включая boss reward (среднее по трём маршрутам ≈18-20; ни один маршрут не ниже ~17 и не выше ~23). Было 8/9/8.
- [ ] **AC2.** Прогрессия плавная: ряд `next_xp_requirement` для L1..L22 растёт монотонно и мягко, без резких скачков — отношение `req(L+1)/req(L)` ≤ ~1.10 и стабильно (было ×1.42, спайк до 7356 XP на L19→20). Ряд приведён в отчёте/описании коммита.
- [ ] **AC3.** Изменены ровно константы кривой `XP_CURVE_MULTIPLIER` и `XP_CURVE_FLAT` в `scripts/progression_data_balance.gd` (плюс, при необходимости, синхронное стартовое `xp_to_next`). Сигнатура `next_xp_requirement()` и форма формулы не меняются.
- [ ] **AC4.** Отчёт `build/route_economy_xp_model.md` перегенерён; текст `_tempo_decision` приведён в соответствие с новой целью (не противоречит таблице).
- [ ] **AC5.** Progression smoke зелёные headless: `tests/runtime_smoke_progression_economy_test.gd` и `tests/progression_data_api_surface_test.gd` (включая `next_xp_requirement(5) > 0`).
- [ ] **AC6.** Если меняли стартовое `xp_to_next` — значение синхронно во всех трёх местах: `player.gd:149`, `player.gd:225`, `route_economy_xp_model.gd:6` (`START_XP_TO_NEXT`).
- [ ] **AC7.** Дизайн-доки приведены в соответствие, если ссылались на старую формулу/темп прогрессии.

## Files / точки входа

- `scripts/progression_data_balance.gd:186` — `XP_CURVE_MULTIPLIER` (1.42 → ~1.05–1.08). **Главная правка.**
- `scripts/progression_data_balance.gd:188` — `XP_CURVE_FLAT` (3.0 → ~1.0–2.0). **Главная правка.**
- `scripts/progression_data.gd:368-369` — `next_xp_requirement()`: формула, читать для понимания; **значения тут НЕ менять** (реэкспорт из balance-файла). НЕ трогать сигнатуру.
- `scripts/player.gd:149` и `scripts/player.gd:225` — стартовое `xp_to_next := 5` (опц. рычаг шага 3; менять синхронно ОБА).
- `scripts/combat_director.gd:870-883, 722, 641-653` — точки начисления XP (только чтение, чтобы понимать доход; правка дохода — крайний случай).
- `tools/route_economy_xp_model.gd:6` — `START_XP_TO_NEXT` (синхронизировать со стартовым `xp_to_next`, если менялся).
- `tools/route_economy_xp_model.gd:243-251` — `_level_state()`: считает колонку Levels (только чтение).
- `tools/route_economy_xp_model.gd:278-292` — `_tempo_decision()`: обновить текст под новую цель.
- Перегенерация отчёта (headless):
  `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path "/Users/sergeyfomin/Documents/AI Agent" --script res://tools/route_economy_xp_model.gd`
- Smoke (progression/economy):
  `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path "/Users/sergeyfomin/Documents/AI Agent" --script res://tests/runtime_smoke_progression_economy_test.gd`
- Smoke (API surface, ассерт XP-кривой):
  `/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path "/Users/sergeyfomin/Documents/AI Agent" --script res://tests/progression_data_api_surface_test.gd`

## Замечания / подводные камни

- **Anti-collision / locked paths.** `scripts/progression_data.gd` — крупный общий locked-файл, и в `git status` он `M` (незакоммиченные правки). В нём по этой задаче **ничего менять не нужно** (только чтение формулы) — вся правка живёт в `scripts/progression_data_balance.gd`, который тоже `M`: синхронизироваться с актуальным состоянием перед правкой, менять только две XP-константы. `scripts/ui_screens.gd` к задаче не относится — не трогать.
- **Источник истины констант — `progression_data_balance.gd`.** `progression_data.gd:51-52` лишь реэкспортирует; правка значений там не сработает как надо (и нарушит locked-path дисциплину).
- **Прямая коллизия с SCRUM-507 (тот же эпик SCRUM-522).** SCRUM-507 «Откалибровать экономику маршрута» в своём AC4 требует сохранить **8-9 level-ups** и явно пишет «XP не трогать» (`docs/tasks/SCRUM-507_calibrate_route_economy.md:117`, AC4 строка 86). SCRUM-527 **намеренно отменяет** этот старый XP-темп-таргет (новая цель ~20 lvl). Если 507 ещё не закрыт — учесть, что его AC4/AC текст про «8-9» устаревает; при необходимости пометить в 507, что XP-темп пересмотрен в 527. Не воспринимать «XP не трогать» из 507 как блокер — это и есть предмет 527.
- **Экономика vs XP — разные оси, но один симулятор.** `route_economy_xp_model.gd` считает и золото, и уровни. Правка XP-кривой меняет ТОЛЬКО колонки Levels/XP Left, не трогая золото/Affordable Offers/Buying Power (они зависят от money-веток `drop_class_rewards` и `stage_scaled_cost`). Поэтому AC SCRUM-507 по золоту/покупательной способности не должны сдвинуться от чистой curve-правки — проверить, что Buying Power в перегенерённом отчёте не изменилась (если изменилась — значит случайно затронул money-ветку, откатить).
- **Старт `xp_to_next` дублируется.** Значение `5` зашито литералом в двух местах `player.gd` (init и reset) и отдельной константой `START_XP_TO_NEXT` в модели. Рассинхрон → отчёт врёт относительно игры. Если трогаешь старт — синхронь все три (AC6).
- **Плавность важнее точного «20».** Acceptance просит «без резких скачков требуемого опыта». Множитель 1.42 — главный виновник экспоненты; именно его снижение до ~1.05-1.08 даёт плавность. Не компенсировать слишком большим `XP_CURVE_FLAT` (большой флэт делает ранние уровни относительно дорогими, поздние — дешёвыми; держать флэт малым 1-2).
- **`xp_gain_multiplier`.** В `gain_xp` (`player.gd:1417`) доход домножается на `run_modifiers.xp_gain_multiplier` (артефакты/события). Модель `route_economy_xp_model.gd` его НЕ учитывает (берёт «голый» drop XP), поэтому в реальной игре с XP-артефактами уровней будет чуть больше, чем в отчёте — это ожидаемо, целиться по модели (детерминированный baseline).
- **Подбор итеративный.** Заложить несколько циклов «правка двух констант → перегенерация отчёта → чтение колонки Levels». Зафиксировать финальные значения констант и итоговую таблицу Route Results в описании коммита.
- **Связанные тикеты:** SCRUM-188 (исходная route-economy/XP-модель), SCRUM-198 (вынос балансных констант в `progression_data_balance.gd`), SCRUM-507 (калибровка экономики маршрута — пересекается по симулятору и по устаревшему XP-таргету), эпик SCRUM-522.
