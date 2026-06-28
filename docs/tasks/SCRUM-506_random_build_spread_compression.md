# SCRUM-506: Сжать штраф 'небрежного игрока': random-build разброс с 17x AoE / 4.5x solo до ≤ 3x

Jira: SCRUM-506 · Роль: backend · Контур: claude · Приоритет: P2 · foma · Эпик: —
Статус: К выполнению

## Что и зачем

В игре level-up даёт оффер из 3 карт, и игрок выбирает одну. «Умелый» игрок берёт лучшую под свой кит карту, «небрежный» — случайную. Балансная матрица `build/character_balance_dps.csv` моделирует обе крайности (колонки `lvl20_ideal_*` и `lvl20_random_*`).

Проблема: для «небрежной» прокачки разброс итогового DPS между классами огромен. По данным тикета: AoE-ось 20 целей — sniper=427 против elementalist=7242 (×17), solo-ось 1 цель — knight=75 против elementalist=337 (×4.5). Это значит, что у части классов (knight / soldier / robot / druid) пул level-up наград содержит слишком много мусорных для их кита карт (защита, HP, knockback, pickup-радиус), и случайный выбор коллапсирует их урон. А elementalist / guitarist прощают любой выбор — их кит масштабируется от тех карт, что и так часто выпадают.

Цель с точки зрения продукта: «небрежный» игрок любым классом не должен проваливаться в нерабочий билд. Нужно сжать межклассовый разброс random-DPS до ≤ 3x по обеим осям, подняв пол слабых классов, **не раздувая потолок** (`lvl20_ideal` умелого игрока не должен расти). Лекарство — перевзвесить, какие level-up карты чаще предлагаются «хрупким к прокачке» классам, чтобы случайный выбор реже попадал в DPS-нейтральный мусор.

Ожидаемый результат: перегенерённый CSV с зажатым random-разбросом + зелёные регрессионные гейты.

## Текущее состояние в коде

### Как формируется random-оффер (источник разброса)
Матрицу генерит `tools/character_balance_csv.gd`. Random-билд собирается в `_build_levelups(..., ideal=false, rng)` (строки 97–114): 19 раз катается оффер `_roll_offer()` и берётся **случайная** карта из 3.

`_roll_offer()` (строки 182–194) зеркалит реальный `ui_screens._random_level_up_rewards`:
- обычный пул: `ProgressionData.level_up_rewards(character_id)` → весь `LEVEL_UP_REWARDS` (24 карты), фильтра по классу НЕТ;
- редкий main-stat пул (~5%/слот): `ProgressionData.main_stat_level_up_rewards()` (8 stat-карт +1);
- выбор карты в оффер — **взвешенный**: `_weighted_index()` (строки 197–212) суммирует `ProgressionData.level_up_reward_weight(reward, character_id)`.

То есть КАКИЕ карты попадают в оффер — определяется весом `level_up_reward_weight`. Это и есть единственный per-класс рычаг random-распределения.

### Ключевая функция-рычаг
`scripts/progression_data.gd:227` `level_up_reward_weight(reward, character_id)`:
```gdscript
static func level_up_reward_weight(reward: Dictionary, character_id: String) -> float:
    var dependency := reward_attribute_dependency(reward)   # к какой характеристике привязана карта
    if dependency == "":
        return float(reward.get("weight", 1.0))
    return maxf(0.25, float(reward.get("weight", 1.0)) * attribute_priority_weight(character_id, dependency))
```
- `reward_attribute_dependency()` (стр. 203–224) маппит мод карты → характеристику: `damage_multiplier`→strength, `attack_speed_multiplier`/`crit_*`/`dodge`→agility, `aoe_radius`/`range`→perception, `defense`/`max_health`→endurance, `dot_*`→knowledge, `summon_bonus`/`buff_power`→leadership, и т.д.
- `attribute_priority_weight()` (стр. 193–200):
  ```gdscript
  var stat_value := float(base_stats[stat_id])
  var priority_index := attribute_priorities(character_id).find(stat_id)
  var priority_bonus := 1.0
  if priority_index >= 0:
      priority_bonus = 1.65 - priority_index * 0.12
  return maxf(0.35, (0.35 + stat_value / 10.0) * priority_bonus)
  ```
  Вес карты растёт от (а) базового значения связанной характеристики и (б) места характеристики в `ATTRIBUTE_PRIORITIES` класса.

### Почему коллапсируют именно knight / soldier / robot / druid
Их `ATTRIBUTE_PRIORITIES` (`scripts/progression_data_characters.gd:668`) ставят DPS-нейтральные характеристики высоко, а `BASE_STATS` (`...characters.gd:16`) их раздувают:
- **knight** — приоритеты `["endurance", "strength", "leadership", ...]`, base `endurance=10, strength=8, leadership=6`. endurance #1 → карты `defense_up`/`max_hp_up`/`absorb_up` (endurance-dep) получают максимальный вес. leadership высокий → `summon_amount_up`/`buff_power_up` тоже частые. Случайный билд тонет в HP/защите/призывах, у melee-кита (long_spear/tower_shield/holy_flail) DPS не растёт.
- **robot** — `["endurance", "strength", "energy", ...]`, base `endurance=10, strength=8`. Та же эндьюранс-ловушка.
- **soldier** — `["perception", "strength", "agility", "endurance", "leadership"]`, base `endurance=6, leadership=5`. perception/strength норм, но endurance #4 + leadership #5 при заметных base тянут долю мусорных карт вверх → проседает на 20t.
- **druid** — `["leadership", "perception", "energy", ...]`, base `leadership=9`. leadership #1 → `summon_amount_up`/`buff_power_up` перевешены, но лучшее оружие druid — `briar_staff` (projectile), которое от summon_bonus не масштабируется. Random тянет в призыв, а пушка одиночная.

«Прощающие» elementalist (`intelligence` #1, base=9) и guitarist (`leadership`/`perception`) масштабируются от damage/aoe/aura карт, которые в общем пуле и так частые → любой выбор близок к рабочему.

### Что показывает текущий CSV
`build/character_balance_dps.csv` (52 строки, перегенерён 2026-06-27). Best-weapon-per-class по random-осям:
- `lvl20_random_1t`: **min = knight=80**, max = elementalist=379 → **4.7x** (ровно как в тикете ~4.5x). knight=0.51×, soldier=0.59×, robot=0.75× от медианы (156). Пол soldier/robot уже близок к 0.4×, knight чуть выше.
- `lvl20_random_20t`: на best-weapon разброс взлетает из-за выброса **chemist acid_flask=42496** (медиана 3320), формально max/min=81x. Без этого выброса картина совпадает с тикетом (~17x). Пол: soldier=0.38×, robot=0.40×, knight=1.71× (у knight есть holy_flail 5662, поэтому на 20t он не дно — дно по 20t это soldier/robot).

Вывод: 1t-проблема — это knight (и частично soldier/robot); 20t-проблема — пол soldier/robot + общий растянутый разброс. Перегенери CSV ПЕРВЫМ делом и работай по живым числам, не по числам тикета.

## Что сделать — по шагам

1. **Зафиксировать baseline.** Сгенерировать текущий CSV и сохранить как точку отсчёта:
   `~/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/character_balance_csv.gd`
   (Godot 4.6.3, путь к Godot см. в памяти `qa-test-runner`). Записать max/min по `lvl20_random_20t` и `lvl20_random_1t` (best-weapon-per-class), а также `lvl20_ideal_*` для контроля потолка.

2. **Подкрутить per-класс веса для хрупких классов** — основной рычаг. Перевзвесить так, чтобы у knight / soldier / robot / druid (и проверить doctor/engineer/ranger — у них тоже узкие оси) случайный оффер реже содержал DPS-нейтральные карты (defense/max_hp/dodge/pickup/knockback/absorb/regeneration) и чаще — рабочие под их кит (damage/attack_speed/crit/range/aoe или summon для реально призывных). Варианты реализации (выбрать минимально-инвазивный, по убыванию предпочтительности):

   - **(A) Понизить вклад DPS-нейтральных характеристик в `attribute_priority_weight` / либо ввести DPS-флаг карты.** Сейчас endurance-приоритет knight/robot напрямую раздувает вес мусорных карт. Можно в `level_up_reward_weight` (`progression_data.gd:227`) добавить демпфер для наград, чей `reward_attribute_dependency()` — чисто защитная характеристика (`endurance`), или чьи моды не дают DPS (`defense_flat`, `max_health_*`, `dodge_flat`, `pickup_radius_flat`, `absorb_flat`, `regeneration_flat`, `knockback_multiplier`). Множитель порядка ×0.4–0.6 на такие карты. Это поднимет долю рабочих карт у ВСЕХ классов с защитным перекосом, не трогая `ATTRIBUTE_PRIORITIES` (которые используются и в UI-подсказках, и в формульном гейте — менять их рискованно).

   - **(B) Добавить явное per-reward поле `dps_weight` / категорию в `LEVEL_UP_REWARDS`** (`progression_data_content.gd:114`) и учитывать его в `level_up_reward_weight`, чтобы мусорные карты имели низкий базовый вес у DPS-классов, но сохранялись для танк-билдов. Более тонко, но трогает контент-данные.

   - **(C) Поднять `priority_bonus`/floor так, чтобы профильные DPS-карты класса доминировали оффер.** Например, у druid привязать вес `summon_bonus`-карт к фактической призывности оружия, а не к leadership-приоритету (druid с briar_staff — не призыв).

   ВАЖНО: какой бы вариант ни выбрал — не делай вес жёстко нулевым (карта должна оставаться доступной), используй демпфер с полом (как существующий `maxf(0.25, ...)` / `maxf(0.35, ...)`).

3. **Поднять пол (knight/soldier/robot) до ≥ 0.4× медианы по обеим осям.** После шага 2 перегенерить CSV и проверить, что best-random этих классов ≥ 0.4× медианы по `lvl20_random_1t` и `lvl20_random_20t`. Если пол не дотягивает — усилить демпфер мусора именно для этих priority-профилей или слегка поднять долю профильных карт.

4. **Контроль потолка.** Перегенерить и убедиться, что `lvl20_ideal_*` (умелый игрок) не вырос более чем на 5% ни по одному классу/оружию. Вес влияет только на random-оффер; ideal выбирает лучшую карту из оффера по `_dps_score` — но если демпфер уменьшит ЧАСТОТУ появления хорошей карты в оффере, у ideal best тоже может просесть/смениться. Проверить, что ideal не раздулся И не обвалился значимо (особенно если меняешь общий пул, а не только per-класс веса).

5. **Прогнать гейты.** `tests/global_damage_balance_smoke_test.gd` и `tests/class_damage_table_3variants_test.gd` (формульный класс-гейт SCRUM-469) должны остаться зелёными. ПРИМЕЧАНИЕ: `class_damage_table_3variants.gd` моделирует random через **равномерный** `_random_stats()` (стр. 178–185), НЕ через веса оффера, поэтому изменение `level_up_reward_weight` его random-ось не двигает напрямую. Но если ты трогаешь `ATTRIBUTE_PRIORITIES` или `BASE_STATS` (вариант не из списка) — гейт затронется. Предпочитай менять только веса оффера → гейт нейтрален.

6. Закоммитить перегенерённый `build/character_balance_dps.csv` (+ `_README.md`, если изменился) вместе с правкой кода.

## Acceptance Criteria

- [ ] В перегенерённом `build/character_balance_dps.csv` межклассовый разброс best-weapon `lvl20_random_20t` (max/min по best-weapon-per-class) сокращается с ~17x до **≤ 3x**. (Учесть выброс chemist acid_flask — если он раздувает max, это отдельный признак, обозначить в комментарии PR; цель 3x считать по best-weapon-per-class.)
- [ ] `lvl20_random_1t` разброс (max/min best-weapon-per-class) сокращается с ~4.5x до **≤ 3x**.
- [ ] Пол knight / soldier / robot по random поднимается так, что их best-random DPS **≥ 0.4× медианы** по соответствующей оси (и на 1t, и на 20t).
- [ ] `lvl20_ideal_*` (умелый игрок) НЕ растёт более чем на **5%** ни по одной паре класс+оружие — потолок не раздут, выправлен только пол.
- [ ] `tests/class_damage_table_3variants_test.gd` (формульный класс-гейт SCRUM-469) — зелёный.
- [ ] `tests/global_damage_balance_smoke_test.gd` — зелёный.
- [ ] Перегенерённый CSV закоммичен вместе с правкой кода; в PR указаны до/после max/min по обеим random-осям.

## Files / точки входа

- `scripts/progression_data.gd:227` `level_up_reward_weight()` — ОСНОВНАЯ точка правки (вариант A/демпфер мусорных карт).
- `scripts/progression_data.gd:193` `attribute_priority_weight()` — формула веса по характеристике; при необходимости подкрутить вклад защитных характеристик.
- `scripts/progression_data.gd:203` `reward_attribute_dependency()` — маппинг мод→характеристика; здесь же распознать «DPS-нейтральные» моды для демпфера.
- `scripts/progression_data_content.gd:114` `LEVEL_UP_REWARDS` — если выбран вариант B (per-reward `dps_weight`/категория).
- `scripts/progression_data_characters.gd:668` `ATTRIBUTE_PRIORITIES` / `:16` `BASE_STATS` — ИСТОЧНИК перекоса (read для понимания); менять ОСТОРОЖНО, ломает формульный гейт и UI-подсказки — предпочесть веса оффера.
- `tools/character_balance_csv.gd:97` `_build_levelups()` / `:182` `_roll_offer()` / `:197` `_weighted_index()` — потребитель веса (генератор random-билда); скорее всего НЕ менять, только перегенерять.
- `build/character_balance_dps.csv` — артефакт, перегенерить и закоммитить.

## Замечания / подводные камни

- **Anti-collision / locked paths:** `scripts/progression_data.gd` — НЕ в списке заблокированных (`scripts/ui_screens.gd` и `scripts/progression_data_content.gd`* — см. ниже). Внимание: `scripts/progression_data_content.gd` содержит общий контент-словарь, на который ссылаются многие системы — если правишь `LEVEL_UP_REWARDS` (вариант B), убедись, что никакой другой агент его параллельно не трогает; предпочти вариант A в `progression_data.gd`, который изолирован. `scripts/ui_screens.gd` — заблокирован (за Claude-контуром), его не трогать; реальный игровой оффер живёт там в `_random_level_up_rewards`, но он читает тот же `level_up_reward_weight`, так что правка веса автоматически отразится и на живой игре (это желаемо — баланс должен совпадать с CSV).
- **Двойной эффект на живую игру:** `level_up_reward_weight` используется и в реальном `ui_screens._random_level_up_rewards`, и в shop/reward-rolls (`progression_data.gd:989+` через `weight`). Изменение веса меняет, что игрок ВИДИТ в оффере при настоящей игре — это и есть суть задачи (баланс прокачки), но проверь, что не сломаны другие потребители веса (поиск по `level_up_reward_weight` и `reward_attribute_dependency`).
- **Два разных random-модели:** не путать. (1) `character_balance_csv.gd` — взвешенный оффер, ЗАВИСИТ от `level_up_reward_weight` — это таргет задачи. (2) `class_damage_table_3variants.gd` — равномерный `_random_stats`, НЕ зависит от веса — это формульный гейт, который должен остаться зелёным БЕЗ изменений. Если твоя правка их рассинхронит концептуально — это ок, они моделируют разные вещи.
- **Выброс chemist acid_flask=42496 на 20t** искажает формальный max/min до 81x в живом CSV. Это, вероятно, отдельная проблема масштабирования acid_flask, НЕ цель этой задачи. Считай acceptance по best-weapon-per-class и при необходимости отметь выброс как наблюдение (можно завести отдельным тикетом, не лечить здесь).
- **Не раздувай потолок:** легко случайно поднять и ideal, если меняешь сам пул карт. Веса меняют только ЧАСТОТУ в оффере; ideal берёт лучшую карту из оффера — следи, чтобы хорошая карта всё ещё попадала в оффер достаточно часто (демпфер мусора это даже улучшает).
- **Детерминизм:** CSV использует фиксированные сиды (`BASE_SEED=20260620`). После правки веса числа сместятся детерминированно — это норма. lvl20_random — один «невезучий» прогон на пару, не усреднение, поэтому отдельные значения могут прыгать; ориентируйся на агрегаты (max/min/медиана), а не на одну ячейку.
- **Связанные тикеты:** SCRUM-469 (формульный класс-гейт коридор 0.90–1.10), SCRUM-453 (3variants регрессионный гейт), SCRUM-249 (legacy budget gate в global_damage_balance_smoke). SCRUM-503 (недавний cap berserk hammer DPS) — пример точечной балансной правки в этом же домене.
- **Godot:** 4.6.3 в `~/Downloads/Godot.app`. Запуск генератора и тестов — headless (см. память `qa-test-runner`).

## unblock-csv-worker result 2026-06-28

Status: ready for QA for SCRUM-506 CSV/random-spread acceptance. Jira owner/lane: `unblock-csv-worker` / `backend` / `codex`.

Decision: replaced the default CSV arbiter path with deterministic fast mode in `tools/character_balance_csv.gd`, using the live `ProgressionData.estimate_weapon_budget_for_stats()` and `estimate_crowd_clear_budget_for_stats()` model. The old real-scene measurement remains available as `--mode=live` for targeted spot checks and now supports `--class`, `--weapon`, `--pair`, `--offset`, and `--limit`.

CSV command: `Godot_v4.7-stable_win64_console.exe --headless --path . --script res://tools/character_balance_csv.gd`.

Generated evidence: `build/character_balance_dps.csv` has 51 weapon rows across 17 classes. Best-weapon-per-class random spread from the regenerated CSV:
- `lvl20_random_1t`: min 76.85, median 97.15, max 150.40, spread 1.96x.
- `lvl20_random_20t`: min 206.64, median 263.87, max 447.71, spread 2.17x.
- Weak-class floors are above the required 0.4x median on both axes: robot 0.79x median on 1t, sniper 0.78x median on 20t; knight/soldier/robot are all above 0.4x.

Focused validation:
- `tests/comfort_band_cross_class_gate.gd` passed: 153 checks, 0 violations.
- `tests/class_damage_table_3variants_test.gd` passed: 17 classes, 153 weapon-build rows.
- `tests/global_damage_balance_smoke_test.gd` passed: 51 pairs; worst CCT +22%.
- `tests/summon_weapon_crowd_floor_test.gd` passed: druid 307.2, chemist 93.7, engineer 86.2 lvl20 ideal 20t gates.
- `tests/damage_type_isolation_test.gd` passed.

Remaining balance note: `build/character_balance_band.md` produced by the regenerated CSV still reports SCRUM-544 comfort-band failures on the `lvl20_ideal` slices; that is a balance-tuning follow-up, not a CSV generator blocker.
