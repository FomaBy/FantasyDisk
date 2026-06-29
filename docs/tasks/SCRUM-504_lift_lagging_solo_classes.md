# SCRUM-504: Поднять отстающие классы solo-оси: guitarist/robot/priest/druid до медианы ±25%

Jira: SCRUM-504 · Роль: backend · Контур: Codex · Owner: backend-codex-balance-504-506 · Приоритет: P1 · foma · Эпик: балансовый аудит классов (поле epic в Jira не выставлено — уточнить у PM при необходимости)
Статус: done
Locked paths: scripts/progression_data_balance.gd, scripts/progression_data_weapons.gd, tools/character_balance_csv.gd, balance tests/reports/docs.
Combined batch: SCRUM-504 + SCRUM-506, claimed in Jira 2026-06-28 by backend-codex-balance-504-506.

## Result 2026-06-28 — backend-codex-balance-504-506

Status: fixed, ready for QA as combined SCRUM-504/SCRUM-506 balance batch.

Changes:
- Tuned `scripts/progression_data_balance.gd` class solo/growth profile for guitarist, priest, robot, knight, and assassin.
- Preserved AoE identity: no target/AoE profile was reduced; tuning is limited to solo ceilings and lvl20 growth tails.
- Regenerated `build/character_balance_dps.csv` and `docs/design/reports/class_damage_table_3variants.md`.

Final SCRUM-504 metrics from regenerated CSV:
- Best-weapon `lvl20_ideal_1t` spread excluding berserk: **1.980x** (min `dark_mage/dark_wand` 249.78, max `assassin/chakrams` 494.65), target <= 2.0x.
- Target classes all pass 0.75x median floor and are outside bottom four: guitarist 278.69, priest 269.21, robot 268.68, druid 274.22.
- Bottom four after fix: dark_mage, knight, engineer, soldier.

Validation:
- `tools/character_balance_csv.gd` regenerated CSV.
- `tests/class_damage_table_3variants_test.gd` PASSED.
- `tests/global_damage_balance_smoke_test.gd` PASSED.
- `tests/comfort_band_cross_class_gate.gd` PASSED.
- `tests/damage_type_isolation_test.gd` PASSED.
- `tests/live_balance_simulation_test.gd` PASSED with deterministic fallback because headless Player/Enemy scene scripts were unavailable from resource-import noise.
- `tests/weapon_tuning_application_test.gd` PASSED with runtime subcheck skipped for the same headless Player scene import state; registry/derivation gates covered all 51 pairs.
- `tests/summon_weapon_crowd_floor_test.gd` PASSED 5/5 repeated runs.

## Что и зачем

Цель — устранить «дно» одиночной оси у классов, которые сейчас не могут убивать одиночную цель (элитки/боссы, 1-target энкаунтеры). По живой матрице `build/character_balance_dps.csv` (колонка `lvl20_ideal_1t`, best-weapon на класс) разброс между классами огромный: топ ~2016–2520, дно — guitarist/robot/priest/druid/biologist в районе 865–1050. Это значит, что игрок, выбравший один из этих классов, упирается в стену на боссах: профильная AoE-ось есть, а добить одиночную элитку нечем.

С точки зрения игрока: каждый класс должен иметь хотя бы одно оружие, которым реально можно вести бой 1-в-1 (TTK по элитке/боссу в разумных рамках), не теряя при этом своей профильной AoE-специализации. AoE-классы остаются AoE-классами — мы лишь поднимаем их одиночный «потолок» с провального до приемлемого (≥ 0.75× межклассовой медианы solo).

Ожидаемый результат: после правок и перегенерации CSV у guitarist/robot/priest/druid (и заодно biologist, который тоже на дне) best-weapon `lvl20_ideal_1t` ≥ ~0.75× медианы; межклассовый разброс solo (исключая Берсерка, у которого hammer выкручен после P0/SCRUM-503) сокращается до ≤ 2.0×; AoE-профиль (`lvl20_ideal_20t`) этих классов не проседает более чем на 10%.

## Текущее состояние в коде

Замер живой матрицы (`build/character_balance_dps.csv`, перегенерён 2026-06-27, уже учитывает SCRUM-503 cap берсерк-хаммера). Best-weapon `lvl20_ideal_1t` по классам, медиана = **1480**, порог 0.75× медианы = **~1110**:

| класс | best-weapon | solo lvl20_ideal_1t | x медианы | 0.75× гейт |
|---|---|---:|---:|---|
| guitarist | sound_amp | 865 | 0.58 | FAIL |
| robot | robot_hydraulic_press | 936 | 0.63 | FAIL |
| priest | priest_censer | 953 | 0.64 | FAIL |
| biologist | biologist_symbiote_seed | 973 | 0.66 | FAIL |
| druid | briar_staff | 1049 | 0.71 | FAIL |
| knight | tower_shield | 1063 | 0.72 | FAIL (на грани) |
| assassin | chakrams | 1126 | 0.76 | pass |
| … | … | … | … | … |
| berserk | hammer | 2520 | 1.70 | (исключён из spread, P0) |

Текущий разброс max/min исключая берсерка = **2.33×** (max = elementalist prism_focus 2016, min = guitarist 865). Цель — ≤ 2.0×.

ВНИМАНИЕ: числа в теле тикета взяты из БОЛЕЕ РАННЕГО снапшота CSV (там median≈1440, guitarist=761). Живой CSV новее: median=1480, guitarist=865 (best теперь sound_amp, а не electric_guitar). Заземляться надо в АКТУАЛЬНОМ перегенерённом CSV, а не в цифрах тикета — порог 0.75× считать от свежей медианы.

### Как solo-бюджет течёт через код (что реально крутить)

1. **`scripts/progression_data_balance.gd:5` `CLASS_BUDGET_PROFILES`** — на КЛАСС задаёт `damage_budget`, `solo_target`, `aoe_target`. Текущие значения для целевых классов:
   - `priest`: `damage_budget 0.92, solo_target 1.00, aoe_target 1.05`
   - `robot`: `damage_budget 0.88, solo_target 1.00, aoe_target 1.05`
   - `guitarist`: `damage_budget 1.00, solo_target 0.84, aoe_target 1.30`
   - `druid`: `damage_budget 1.00, solo_target 1.00, aoe_target 1.00`
   - (`biologist`: `damage_budget 1.08, solo_target 0.92, aoe_target 1.18` — тоже на дне, рассмотреть)

2. **`scripts/progression_data.gd:420` `budget_tuning_for()`** — формульный движок баланса. Считает `solo_target = BALANCE_BASE_SOLO_DPS(48) * profile.solo_target * profile.damage_budget` и `aoe_target = BALANCE_BASE_AOE_DPS(150) * profile.aoe_target * profile.damage_budget`. Затем из базовых метрик оружия (`estimate_weapon_budget`) выводит `damage_multiplier = clampf(sqrt(solo_scale * aoe_scale), 0.28, 2.80)` и раздельные `solo_budget_multiplier` / `aoe_budget_multiplier`. То есть solo и aoe бюджеты подгоняются ОТДЕЛЬНО: поднять `solo_target` поднимает одиночный потолок, не трогая `aoe_target`.

3. **`scripts/progression_data.gd:764` `weapon()`** — на каждое оружие зашивает результат `budget_tuning_for` в config (`budget_damage_multiplier`, `budget_solo_multiplier`, `budget_aoe_multiplier`, `budget_tuning`). Именно это применяется к реальному Player при замере CSV.

4. **`scripts/progression_data.gd:778` `_class_stat_growth_scalar()` / `CLASS_LEVEL_STAT_GROWTH_SCALARS`** (`progression_data_balance.gd:25`) — второй рычаг: масштабирует ПРИРОСТ главного атрибута от level-up. Влияет на `lvl20_ideal_1t` сильнее, чем на lvl1, потому что бьёт по дельте уровней. Текущие профильные скейлеры целевых классов: `priest {agility 0.88, intelligence 0.88}`, `robot {strength 0.78, agility 0.78}`, `guitarist {energy 1.56}`, `druid {energy 1.70, perception 0.55, leadership 0.70}`. У priest/robot скейлеры ЗАНИЖЕНЫ (<1.0) — это душит их одиночный рост; их повышение — прямой путь поднять solo.

5. **Per-weapon knobs** в `scripts/progression_data_weapons.gd`: у оружий нет персонального `solo_target`-оверрайда — solo-бюджет целиком из профиля класса. Но есть `damage_multiplier`, `fire_interval`, `attack_speed_multiplier` (в `passive_mods`), `attack_mode`/`damage_parameter`. Пример guitarist: `electric_guitar` (sound_wave, dmg×1.0, interval 0.96), `bass_guitar` (pulse, dmg×0.30 — контрольное, не для DPS), `sound_amp` (amp-deploy, dmg×0.82, interval 2.80, max_summons 1). Лучшее solo-оружие гитариста — sound_amp, но его одиночный DPS режется деплой-механикой и низким `solo_target 0.84` профиля.

6. **Связь формулы и живого CSV**: формульный `solo_dps` из `budget_tuning_for` тянется к `solo_target`. Живой CSV (`tools/character_balance_csv.gd`) гоняет РЕАЛЬНЫЙ Player с level-up билдом — он умножает на эффект апгрейдов и роста атрибутов, поэтому `lvl20_ideal_1t` ≈ `solo_target × (множитель идеального билда)`. Подъём `solo_target` и/или повышение профильного `CLASS_LEVEL_STAT_GROWTH_SCALARS` поднимают живое число пропорционально.

### Гейты (что не должно сломаться)

- **`tools/class_damage_table_3variants.gd:99-115`** — формульный отчёт; `target_1 = solo_target`, а `relative_score` нормирует budget_score на медиану билда. Если поднимать solo РАВНОМЕРНО только у дна, медиана почти не сдвинется, и `relative_score` затронутых классов останется в 0.90..1.10. Гейт-тест: `tests/class_damage_table_3variants_test.gd:80` (lvl1 и lvl20-optimum в коридоре 0.90..1.10).
- **`tests/global_damage_balance_smoke_test.gd`** — комбинированное отклонение `(solo_dps/solo_target + aoe_dps/aoe_target)/2` в коридоре ±0.25 + CCT 5/10/20 ±0.30 на КАЖДОЙ паре класс×оружие. Поднятие `solo_target` поднимает и знаменатель, и (через budget multiplier) числитель — комбинированное отклонение остаётся около 1.0. Запускать ОБЯЗАТЕЛЬНО после правок.

## Что сделать — по шагам

1. **Перегенерировать актуальный CSV ДО правок** (зафиксировать baseline):
   `~/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/character_balance_csv.gd`
   Снять best-weapon `lvl20_ideal_1t`, `lvl20_ideal_20t` по каждому из guitarist/robot/priest/druid/biologist и текущую медиану. Это baseline для проверки «AoE не упал >10%».

2. **Поднять solo-потолок у каждого отстающего класса** через `scripts/progression_data_balance.gd`, двумя рычагами (предпочесть точечно, малыми шагами, итеративно перегоняя CSV):
   - `CLASS_BUDGET_PROFILES[class].solo_target` ↑ — поднять цель одиночной оси:
     - `priest` solo_target 1.00 → ~1.25 (учесть damage_budget 0.92: эффективный solo = 48×1.25×0.92 ≈ 55.2 → пропорционально живому 953→~1190).
     - `robot` solo_target 1.00 → ~1.25 (damage_budget 0.88; 936→~1170).
     - `guitarist` solo_target 0.84 → ~1.30 (damage_budget 1.00; 865→~1340; следить, чтобы не перелетел медиану — цель «выйти из дна», не стать топом).
     - `druid` solo_target 1.00 → ~1.10 (1049→~1155).
     - `biologist` solo_target 0.92 → ~1.08 (973→~1140) — рассмотреть, он тоже FAIL.
   - И/ИЛИ `CLASS_LEVEL_STAT_GROWTH_SCALARS` по главному DPS-атрибуту класса ↑ (бьёт именно по приросту lvl20, мягче трогает lvl1 и AoE-форму):
     - `priest {agility, intelligence}` 0.88 → ~1.00 (вернуть к нейтрали).
     - `robot {strength, agility}` 0.78 → ~0.95.
     - guitarist/druid имеют завышенный `energy` (1.56/1.70) — его трогать осторожно, он питает AoE-механику; для solo лучше через `solo_target`.
   Подбирать коэффициенты ИТЕРАТИВНО: правка → перегон CSV → проверка гейта 0.75× и spread ≤2.0× → корректировка. НЕ выкручивать одним движением.

3. **Не ломать AoE-ось**: после каждого изменения сверять `lvl20_ideal_20t` best-AoE-оружия класса — падение ≤10% от baseline шага 1. `aoe_target` в профиле НЕ понижать; если общий `damage_budget` менялся, проверить, что `aoe_target_effective` не просел.

4. **Per-weapon донастройка (если профиль не дотягивает точечно)**: если у класса solo тянет только одно оружие, а профильный подъём раздувает и неподходящие, рассмотреть точечный `damage_multiplier`/`fire_interval` лучшего solo-оружия в `scripts/progression_data_weapons.gd` (напр. guitarist `sound_amp`/`electric_guitar`). Делать ТОЛЬКО если профильного рычага мало; иначе оставить per-weapon как есть.

5. **Перегенерировать формульный отчёт** и убедиться, что он консистентен:
   `~/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/class_damage_table_3variants.gd`
   → обновит `docs/design/reports/class_damage_table_3variants.md` и CSV-evidence. Проверить `relative_score` всех затронутых классов в 0.90..1.10.

6. **Прогнать оба гейта** (должны быть зелёными):
   - `~/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/global_damage_balance_smoke_test.gd`
   - `~/Downloads/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/class_damage_table_3variants_test.gd`

7. **Финальный перегон `character_balance_csv.gd`** и сверка всех Acceptance Criteria по свежему `build/character_balance_dps.csv`.

## Acceptance Criteria

- [ ] В перегенерённом `build/character_balance_dps.csv` для guitarist/robot/priest/druid best-weapon `lvl20_ideal_1t` ≥ 0.75× межклассовой медианы solo (на текущей медиане ≈1480 это ≥ ~1110).
- [ ] guitarist/robot/priest/druid выходят из дна (перестают быть 4 самыми низкими по solo best-weapon).
- [ ] Межклассовый разброс solo best-weapon `lvl20_ideal_1t` (max/min, ИСКЛЮЧАЯ берсерка) сокращается с текущих ~2.33× до ≤ 2.0×.
- [ ] AoE-профиль затронутых классов (best-weapon `lvl20_ideal_20t`) не падает более чем на 10% относительно baseline-CSV из шага 1 — классы остаются AoE.
- [ ] `tests/class_damage_table_3variants_test.gd` зелёный: `relative_score` всех затронутых классов (Base lvl1 и Lvl20 optimum) в коридоре 0.90..1.10.
- [ ] `tests/global_damage_balance_smoke_test.gd` зелёный (combined ±0.25, solo ±0.20-эквивалент через combined, CCT 5/10/20 ±0.30 на всех парах).
- [ ] Обновлён `docs/design/reports/class_damage_table_3variants.md` (перегенерирован тулом, не руками).
- [ ] biologist рассмотрен: либо тоже выведен из дна (предпочтительно), либо явно обоснован, почему оставлен (он в теле тикета в списке дна, но не в заголовке).
- [ ] Тип-изоляция урона не нарушена: `tests/damage_type_isolation_test.gd` зелёный (правки идут через профили/скейлеры, не через cross-attribute splash — см. инвариант SCRUM-524 в `progression_data.gd:845`).

## Files / точки входа

- `scripts/progression_data_balance.gd:5` `CLASS_BUDGET_PROFILES` — поднять `solo_target` (и при нужде сверить `damage_budget`) для priest/robot/guitarist/druid (и biologist). ОСНОВНОЙ рычаг.
- `scripts/progression_data_balance.gd:25` `CLASS_LEVEL_STAT_GROWTH_SCALARS` — поднять профильный DPS-атрибут priest (agility/intelligence 0.88), robot (strength/agility 0.78). ВТОРОЙ рычаг.
- `scripts/progression_data_weapons.gd` (`GUITARIST_WEAPONS` ~стр.129, `ROBOT_WEAPONS` ~стр.676, `PRIEST_WEAPONS` ~стр.598, `DRUID_WEAPONS` ~стр.389) — точечный `damage_multiplier`/`fire_interval` лучшего solo-оружия ТОЛЬКО если профиля мало.
- `tools/character_balance_csv.gd` — генератор живой матрицы; не меняем логику, только гоняем для проверки CSV (это «арбитр» задачи).
- `tools/class_damage_table_3variants.gd` + `docs/design/reports/class_damage_table_3variants.md` — формульный отчёт, перегенерировать.
- НЕ редактируем (только читаем/исполняем) гейты: `tests/global_damage_balance_smoke_test.gd`, `tests/class_damage_table_3variants_test.gd`, `tests/damage_type_isolation_test.gd`.

## Замечания / подводные камни

- **Anti-collision / locked paths**: `scripts/ui_screens.gd` и `scripts/progression_data.gd` — заблокированы за другой контур (Claude lane вообще, но эти конкретно конфликтные). Эта задача НЕ должна трогать `progression_data.gd` (формулы) и `ui_screens.gd` — все правки изолируются в `progression_data_balance.gd` (данные профилей) и при нужде `progression_data_weapons.gd`. Если кажется, что нужно менять `progression_data.gd` — остановиться, это сигнал неверного подхода.
- **Берсерк исключается из spread-метрики** (его hammer выкручен после P0/SCRUM-503 — см. коммит `1e74202b balance(SCRUM-503): cap berserk hammer DPS runaway`). Метрику разброса считать БЕЗ берсерка, как в Acceptance.
- **Раздельность solo/aoe бюджета**: `budget_tuning_for` подгоняет `solo_budget_multiplier` и `aoe_budget_multiplier` ОТДЕЛЬНО (progression_data.gd:437-438), поэтому подъём `solo_target` математически не должен раздувать AoE. Но `damage_multiplier` общий (sqrt(solo_scale·aoe_scale)) и зажат clampf в [0.28, 2.80] — если оружие уже у потолка clamp, дальнейший подъём solo_target не пройдёт. Проверять, что после правок `budget_damage_multiplier` затронутых оружий не упёрся в 2.80 (тогда нужен второй рычаг — скейлеры роста).
- **Деплой/призыв-механики** (guitarist sound_amp, druid summon-оружия) имеют свой множитель урона в `estimate_weapon_budget` (`_budget_summon_role_damage_factor`, `_is_pure_summon_weapon`) — их одиночный DPS может занижаться структурно; для них особенно стоит выбрать НЕ summon-оружие как «solo-носитель» (druid → briar_staff projectile, уже best; guitarist → возможно electric_guitar sound_wave, а не sound_amp).
- **Живой CSV vs формула**: Acceptance завязаны на ЖИВОЙ `character_balance_dps.csv` (реальный билд), а гейты — на ФОРМУЛЬНЫХ отчётах. Это два разных слоя; правки в профилях двигают оба, но числа не совпадают 1:1. Проверять оба, не подгонять один в ущерб другому.
- **Цифры тикета устарели** относительно живого CSV (median 1440→1480, guitarist 761→865, best guitarist-оружие сменилось на sound_amp). Гейт 0.75× считать от СВЕЖЕЙ медианы перегенерённого CSV, а не от чисел в теле тикета.
- **knight (1063, 0.72×) и biologist (973, 0.66×)** тоже проваливают 0.75×-гейт, хотя knight не в списке тикета. Если после правки целевой четвёрки spread всё ещё >2.0× или новое «дно» — это knight — рассмотреть лёгкий подъём и его (knight не в заголовке, но в духе задачи; согласовать объём с PM, не раздувать без нужды).
- **Связанные тикеты**: SCRUM-503 (P0 cap берсерк-хаммера, уже в HEAD) — этот тикет P1-продолжение того же балансового прохода. Эпик балансового аудита классов.
- **Изоляция типов урона (SCRUM-524)**: правки идут через профили/скейлеры и per-weapon multiplier — НЕ через cross-attribute splash. Инвариант «атрибут типа X меняет только урон типа X» держится тестом `damage_type_isolation_test.gd`; не вводить новых межтиповых вкладов.

## QA-Вердикт
Статус: PASSED
Дата: 2026-06-29 (claude-qa-504, clean worktree от origin/dev 13451fb7)

Influence: cdb2909a + ac7116c3 в origin/dev (подтверждено merge-base --is-ancestor).

Gates (чистый worktree, --import, один Godot): class_damage_table_3variants_test PASS,
global_damage_balance_smoke_test PASS (51 пара, худшее CCT +22%), comfort_band_cross_class_gate PASS,
damage_type_isolation_test PASS, weapon_tuning_application_test PASS (51/51, runtime-субчек НЕ скипнут),
summon_weapon_crowd_floor_test PASS 3/3.

Acceptance (Python поверх live character_balance_dps.csv, median best lvl20_ideal_1t=274.63, floor 205.97):
guitarist 278.69 (1.01x), robot 268.68 (0.98x), priest 269.21 (0.98x), druid 274.22 (1.00x) — все ≥ floor,
вне нижней четвёрки (dark_mage/knight/engineer/soldier). Spread excl berserk = 1.980x ≤ 2.0x. AoE-профиль не просел.

Повторное всплытие в QA — board-sync revert из-за отсутствия этого блока, не регресс. Закрывать прямым API-transition.
