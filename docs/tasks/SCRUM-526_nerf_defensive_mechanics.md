# SCRUM-526: Нерф защитных механик: вампиризм / реген / абсорб (имба)

> Историческая справка: упоминания `sound_wave_damage` в этом документе описывают состояние ДО SCRUM-898 (2026-07-10). Звуковая ось урона удалена; оружия Гитариста/Друида бьют магией (`magic_damage`).

Jira: SCRUM-526 · Роль: backend · Контур: claude · Приоритет: P1 · foma · Эпик: SCRUM-522 (Ребаланс боёвки и прогрессии)
Статус: done (QA PASSED; PM sprint audit restored Jira Готово 2026-06-29)

## QA-Вердикт: PASSED

Статус: PASSED · QA 2026-06-27 (Godot 4.6.3 headless, ветка dev, HEAD 8ebe4d20)

Green-gate / balance-смоуки — все зелёные: runtime_smoke_test,
global_survivability_balance_smoke_test (16 строк: TTD<=600с, митигация<98%, бессмертие
недостижимо), global_damage_balance_smoke_test (51 пара), survivability_scenario_test
(якорь take_damage 33.055 == формула 33.055), live_balance_simulation_test,
ascension_curve_balance_test, damage_type_isolation_test (изоляция SCRUM-523/524 цела).

HEAD-изоляция: ключевые гейты перепрогнаны в чистом worktree на коммите 8ebe4d20 (после
`--import`) — все зелёные; правки SCRUM-526 не зависят от чужих незакоммиченных хунков
(SCRUM-517/503 WIP в рабочем дереве не трогает absorb/regen/vampiric-константы).

Acceptance подтверждён фактической проверкой:
- Absorb ослаблен: min-fraction 0.35→0.42, flat-diminish 0.08→0.11, база END*0.16→*0.145.
- Regen ослаблен: база 0.22→0.16, flat-mult 0.45→0.35 → effective regen tank 0.30→0.20/с.
- Вампиризм ослаблен (оба канала): chance-cap 0.22→0.20, damage-ratio 0.035→0.025 (−29%),
  base-mult 0.55→0.48, per-sec капы 1.4→1.1 / 2.6→2.0, оружейный drain 0.45→0.35.
- Защитная ось не доминирует: харнесс перегенерён, tank/contact_swarm TTD 38.5→33.4с (−13%),
  разрыв tank↔sturdy 2.79×→2.57×; монотонность fragile<steady<sturdy<tank во всех 4 сценариях.
- Инвариант «бессмертие недостижимо» держится с запасом по всем 16 строкам; fragile не задет.
- Изоляция типов урона (SCRUM-523/524) не нарушена — правки только в защитной оси.

## Результат (до→после, 2026-06-27)

Правки — только в защитной оси (absorb/regen/vampiric), формула урона не тронута (изоляция SCRUM-523/524 держится, `damage_type_isolation_test` зелёный).

**Константы** (`progression_data_balance.gd`):
| Knob | До | После |
| --- | ---: | ---: |
| ABSORB_MIN_DAMAGE_FRACTION | 0.35 | 0.42 |
| ABSORB_FLAT_DIMINISH | 0.08 | 0.11 |
| REGEN_FLAT_MULTIPLIER | 0.45 | 0.35 |
| VAMPIRIC_CHANCE_CAP | 0.22 | 0.20 |
| VAMPIRIC_DAMAGE_HEAL_RATIO | 0.035 | 0.025 |
| VAMPIRIC_BASE_HEAL_MULTIPLIER | 0.55 | 0.48 |
| VAMPIRIC_HEAL_CAP_DEFAULT | 1.4 | 1.1 |
| VAMPIRIC_HEAL_CAP_HARD | 2.6 | 2.0 |
| WEAPON_DRAIN_HEAL_MULTIPLIER | 0.45 | 0.35 |

**Формулы** (`progression_data.gd`): absorb-база `endurance*0.16→*0.145`; regen-база `0.22→0.16`.

**Survivability-харнесс — TTD по профилям (contact_swarm — главный кейс absorb):**
| Профиль/сценарий | TTD до | TTD после | Δ |
| --- | ---: | ---: | ---: |
| tank/contact_swarm | 38.5с | 33.4с | −13% (главный outlier) |
| tank/shooter | 22.4с | 21.5с | −4% |
| tank/elite_burst | 18.8с | 18.5с | −2% |
| tank/boss_hazard | 16.8с | 16.4с | −2% |
| sturdy/contact_swarm | 13.8с | 13.0с | −6% |
| fragile/* | 1.4–1.6с | 1.4–1.6с | ~0 (fragile не задет) |

Доминирование защитной оси сжато: разрыв tank↔sturdy в худшем кейсе 2.79×→2.57×. Реген tank 0.30→0.20/с, absorb (dps срезан) 17.6→15.9. Монотонность TTD (fragile<steady<sturdy<tank) сохранена во всех 4 сценариях, инвариант «бессмертие недостижимо» держится с запасом по всем 16 строкам.

**Вампиризм** (харнесс не моделирует — измеримость по константам): главный канал «лечусь от урона» −29% (ratio 0.035→0.025), per-second cap −21%/−23%, оружейный drain −22%.

**Смоуки (все зелёные):** global_survivability_balance, global_damage_balance, survivability_scenario (якорь), live_balance_simulation, ascension_curve_balance, damage_type_isolation, runtime_smoke.

## Что и зачем

Защитные механики — **вампиризм** (heal-on-hit), **регенерация** (HP/сек) и **абсорб** (плоский срез урона до защиты) — сейчас слишком сильны. На survivability/DPS-харнессе видно, что «защитная ось» позволяет выживать почти бесконечно, из-за чего билд «закопаться в выживаемость» доминирует над агрессивными билдами: игроку выгоднее стакать защиту, чем урон, и забег превращается в неубиваемость.

Цель с точки зрения продукта: сделать выживаемость **полезной, но не доминирующей стратегией**. Игрок должен ощущать, что защита продлевает жизнь и сглаживает спайки, но не отменяет необходимость убивать врагов и не делает персонажа бессмертным. Это часть общего ребаланса боёвки эпика SCRUM-522 (пункт «Защитные механики ослаблены»).

Ожидаемый результат:
- Вампиризм, реген и абсорб **измеримо ослаблены** — конкретные значения «до/после» зафиксированы в отчёте харнесса.
- На survivability-харнессе защитная ось перестаёт доминировать (TTD/митигация в коридоре, инвариант «бессмертие недостижимо» держится с заметным запасом, а не на грани).
- Базовая играбельность **отстающих/танковых** классов (robot/knight/doctor — survival tank, см. `CLASS_BUDGET_PROFILES`) не ломается: они остаются крепче fragile-классов, монотонность TTD по стойкости сохраняется.
- Все balance-смоуки зелёные.

## Текущее состояние в коде

Все три механики уже централизованы: числовые константы — в `scripts/progression_data_balance.gd`, формулы «raw → effective» — в `scripts/progression_data.gd`, применение в рантайме — в `scripts/player.gd` и `scripts/class_weapon.gd`. **Менять надо в первую очередь константы баланса и формулы, а не рантайм-циклы.**

### 1. Вампиризм (heal-on-hit, sustain)
Константы — `scripts/progression_data_balance.gd:60-65`:
```
const VAMPIRIC_CHANCE_CAP := 0.22            # кап шанса вампиризма
const VAMPIRIC_DAMAGE_HEAL_RATIO := 0.035    # доля нанесённого урона в лечение
const VAMPIRIC_BASE_HEAL_MULTIPLIER := 0.55  # множитель плоского vampiric_amount
const VAMPIRIC_HEAL_CAP_DEFAULT := 1.4       # дефолтный per-second cap бюджета лечения
const VAMPIRIC_HEAL_CAP_HARD := 2.6          # жёсткий потолок per-second cap
const WEAPON_DRAIN_HEAL_MULTIPLIER := 0.45   # множитель weapon-drain (heal_percent_of_damage/on_attack)
```
Формулы — `scripts/progression_data.gd`:
- `effective_vampiric_chance(raw)` (268-269) — `clampf(raw, 0, VAMPIRIC_CHANCE_CAP)`.
- `effective_vampiric_cap(raw)` (272-273) — `clampf(raw, 0, VAMPIRIC_HEAL_CAP_HARD)`.
- В `derived_parameters` (887-888): `"vampiric_chance"` и `"vampiric_amount" = vampiric_amount_flat * VAMPIRIC_BASE_HEAL_MULTIPLIER`.

Рантайм — `scripts/player.gd`:
- Поле `_vampiric_heal_budget` (178), стартовый cap `vampiric_heal_per_second_cap` (142, 220).
- `_apply_regeneration(delta)` (776-782) ПОПОЛНЯЕТ бюджет: `_vampiric_heal_budget = minf(budget + vampiric_cap*delta, vampiric_cap)`.
- `on_weapon_hit(enemy, dealt_damage)` (785-793) ТРАТИТ бюджет: при `randf() < vampiric_chance` лечит `raw_heal = vampiric_amount + dealt_damage*VAMPIRIC_DAMAGE_HEAL_RATIO`, ограничено остатком бюджета и домножено на `healing_multiplier`.

Weapon-drain (отдельный канал вампиризма у оружия) — `scripts/class_weapon.gd`:
- `heal_percent_on_attack` (260-261): лечит `% * WEAPON_DRAIN_HEAL_MULTIPLIER` при каждой атаке.
- `_heal_owner_from_damage` (776-786): лечит `dealt_damage * heal_percent_of_damage * WEAPON_DRAIN_HEAL_MULTIPLIER`.
- Значения `heal_percent_of_damage` по оружию — `scripts/progression_data_weapons.gd` (напр. 270 = 0.34, 281 = 0.26, 292 = 0.18; мелкие 0.03–0.08), `heal_percent_on_attack` (619 = 0.012).

### 2. Регенерация (HP/сек)
Константа — `scripts/progression_data_balance.gd:59`:
```
const SURVIVABILITY_REGEN_FLAT_MULTIPLIER := 0.45
```
Формула — `scripts/progression_data.gd:260-265` `effective_regeneration(knowledge, flat)`:
```
positive_flat := max(flat,0)*SURVIVABILITY_REGEN_FLAT_MULTIPLIER
negative_flat := min(flat,0)
regen_base := max(0, 0.22 + positive_flat + negative_flat)   # базовый реген 0.22 захардкожен
knowledge_scale := 0.45 + max(knowledge,0)/12.0              # масштаб от Знания
return regen_base * knowledge_scale
```
Подставляется в `derived_parameters["regeneration"]` (886), `regeneration_flat` собирается из run+passive модов (833).
Рантайм — `scripts/player.gd:_apply_regeneration` (779-782): `health += regeneration * healing_multiplier * delta`, вызывается каждый кадр из `_physics_process`-цепочки (417).

### 3. Абсорб (плоский срез урона)
Константы — `scripts/progression_data_balance.gd:57-58`:
```
const SURVIVABILITY_ABSORB_MIN_DAMAGE_FRACTION := 0.35  # минимум 35% удара ВСЕГДА проходит
const SURVIVABILITY_ABSORB_FLAT_DIMINISH := 0.08        # diminishing на плоский absorb_flat
```
Формула — `scripts/progression_data.gd:252-257` `effective_absorb(endurance, flat)`:
```
base_absorb := max(endurance,0)*0.16
softened_flat := positive_flat / (1 + positive_flat*SURVIVABILITY_ABSORB_FLAT_DIMINISH)
return max(0, base_absorb + softened_flat + negative_flat)
```
Подставляется в `derived_parameters["absorb"]` (885), `absorb_flat` из run+passive модов (832).
Рантайм-применение — `scripts/player.gd:take_damage` (581-583), порядок митигейта **absorb → defense → dodge**:
```
absorbed_amount = max(defended_amount - absorb, defended_amount*SURVIVABILITY_ABSORB_MIN_DAMAGE_FRACTION)
final_damage = absorbed_amount * (1 - defense)
```

### Источники защитных модов (что качает эти стат-ключи)
- Артефакты/апгрейды — `scripts/progression_data_content.gd`: `leech_fang` (111: `vampiric_chance_flat 0.14`, `vampiric_amount_flat 1.0`, `vampiric_heal_per_second_cap 1.0`), `absorb_up` (134: `absorb_flat 4.0`), `regeneration_up` (135: `regeneration_flat 1.3`), `vampiric_amount_up` (136), `vampiric_chance_up` (137: `0.05`).
- Мета-древо — `scripts/meta_progression.gd:51-52`: `endure_regen_1/2` по `regeneration_flat 0.4`.
- Оружейные пассивки — `scripts/progression_data_weapons.gd`: `passive_mods` с `regeneration_flat` (609, 716, 749) и `absorb_flat` (689).

### Харнесс и гейт (источник «до/после» и проверки доминирования)
- Модель — `tools/survivability_harness.gd`: профили fragile/steady/sturdy/tank × 4 сценария урона. Берёт `ProgressionData.derived_parameters` (significant: `health/defense/absorb/dodge/regeneration`) и считает `effective_dps = max(after_dodge - regen, 0.05)`, `ttd = health/effective_dps`. Отчёт → `build/survivability_report.md`.
- ВАЖНО: текущий харнесс НЕ моделирует вампиризм/weapon-drain (учитывает только regen/absorb/defense/dodge). Вклад вампиризма виден только в `_budget_ehp` (`scripts/progression_data.gd:751-761`, поля `heal_percent_of_damage/on_attack`) — это бюджетная EHP-модель оружия, отдельная от survivability-харнесса.
- Гейт — `tests/global_survivability_balance_smoke_test.gd`: коридоры `MAX_TTD=600с`, `MAX_MITIG=0.98`, инвариант `(mitigated - regen) > NET_DAMAGE_FLOOR(0.05)` («бессмертие недостижимо»), монотонность TTD по стойкости. Отчёт → `build/global_survivability_balance_report.md`.
- Смежные тесты: `tests/survivability_scenario_test.gd` (якорит формулу харнесса к реальному `Player.take_damage`), `tests/global_damage_balance_smoke_test.gd`, `tests/live_balance_simulation_test.gd`, `tests/ascension_curve_balance_test.gd`.

История: SCRUM-255 уже один раз ослаблял реген/вампиризм и переводил defense/dodge/absorb на diminishing returns (см. комментарии в харнессе и `player.gd:579`). SCRUM-526 — следующий шаг того же направления.

## Что сделать — по шагам

1. **Снять baseline («до»).** Прогнать оба харнесса ДО правок и сохранить отчёты как опорные значения:
   - `Godot --headless --path . --script res://tools/survivability_harness.gd` → `build/survivability_report.md`
   - `Godot --headless --path . --script res://tests/global_survivability_balance_smoke_test.gd` → `build/global_survivability_balance_report.md`
   Зафиксировать в отчёте задачи ключевые числа «до»: TTD/regen-share по профилям (особенно tank/sturdy), `effective_regeneration` и `effective_absorb` для tank-профиля, `effective_vampiric_chance/cap`.

2. **Ослабить вампиризм** — правки числовые, в `scripts/progression_data_balance.gd`. Кандидаты (подобрать величину по харнессу/EHP-модели, не «на глаз»):
   - Снизить `VAMPIRIC_DAMAGE_HEAL_RATIO` (0.035 → меньше) — главный канал «лечусь от своего урона».
   - Снизить per-second потолки `VAMPIRIC_HEAL_CAP_DEFAULT` (1.4) и `VAMPIRIC_HEAL_CAP_HARD` (2.6) — режет sustain-потолок.
   - При необходимости — `VAMPIRIC_CHANCE_CAP` (0.22) и/или `VAMPIRIC_BASE_HEAL_MULTIPLIER` (0.55), `WEAPON_DRAIN_HEAL_MULTIPLIER` (0.45) для оружейного дрейна.
   Логику в `player.gd`/`class_weapon.gd` НЕ переписывать — только если потребуется уточнить порядок/клампы.

3. **Ослабить регенерацию** — `scripts/progression_data.gd:effective_regeneration` и/или `SURVIVABILITY_REGEN_FLAT_MULTIPLIER`:
   - Снизить базу `0.22` (захардкожена в формуле, строка 263) и/или `SURVIVABILITY_REGEN_FLAT_MULTIPLIER` (0.45) — вклад плоских наград.
   - При необходимости — поджать `knowledge_scale` (0.45 + knowledge/12), чтобы knowledge-стак не давал слишком высокий реген у tank-профиля.
   Цель: на survivability-гейте `(mitigated - regen)` должно превышать порог с **запасом**, а не впритык.

4. **Ослабить абсорб** — `scripts/progression_data.gd:effective_absorb` и/или константы:
   - Поднять `SURVIVABILITY_ABSORB_MIN_DAMAGE_FRACTION` (0.35 → выше, напр. 0.40) — больше доля удара всегда проходит, прямой нерф против роя мелких ударов (`contact_swarm`).
   - И/или усилить `SURVIVABILITY_ABSORB_FLAT_DIMINISH` (0.08 → выше) — быстрее насыщение стака `absorb_flat`.
   - И/или снизить коэффициент `endurance*0.16` (строка 253), но осторожно — это базовый absorb танков, не уронить играбельность tank-классов.

5. **Прогнать харнессы «после»**, сравнить с baseline, занести числа «до/после» в отчёт задачи / `build/*report.md`. Убедиться: TTD у tank/sturdy заметно снизился, монотонность по стойкости держится, fragile-классы не стали неиграбельными.

6. **Прогнать все balance-смоуки headless** и убедиться, что зелёные (см. список в Acceptance). Если survivability-смоук падает из-за смежной формулы (`survivability_scenario_test.gd` якорит харнесс к `take_damage`) — синхронизировать модель харнесса с реальной формулой, не глуша гейт.

7. **(Опционально, по согласованию)** Подтянуть значения наград/артефактов под новый баланс, если они стали тривиально-сильными или бесполезными: `leech_fang`, `absorb_up`, `regeneration_up`, оружейные `passive_mods` в `progression_data_weapons.gd`. Не обязательно для закрытия, но желательно для консистентности.

## Acceptance Criteria

- [ ] Вампиризм ослаблен измеримо: снижены минимум `VAMPIRIC_DAMAGE_HEAL_RATIO` и/или per-second капы; значения «до/после» зафиксированы в отчёте.
- [ ] Реген ослаблен измеримо: снижена база/множитель `effective_regeneration`; значения «до/после» зафиксированы.
- [ ] Абсорб ослаблен измеримо: повышен min-damage-fraction и/или усилен diminishing; значения «до/после» зафиксированы.
- [ ] На survivability-харнессе защитная ось НЕ доминирует: TTD tank/sturdy профилей снижен относительно baseline, инвариант «бессмертие недостижимо» (`mitigated - regen > NET_DAMAGE_FLOOR`) держится с запасом по всем 16 строкам.
- [ ] Монотонность TTD по стойкости (fragile < steady < sturdy < tank) сохраняется во всех сценариях — отстающие/танковые классы не сломаны, базовая играбельность tank-классов (robot/knight/doctor) сохранена.
- [ ] `tests/global_survivability_balance_smoke_test.gd` зелёный (TTD<=600с, митигация<98%, бессмертие недостижимо, монотонность).
- [ ] `tests/global_damage_balance_smoke_test.gd`, `tests/survivability_scenario_test.gd`, `tests/live_balance_simulation_test.gd`, `tests/ascension_curve_balance_test.gd` зелёные.
- [ ] Отчёты `build/survivability_report.md` и `build/global_survivability_balance_report.md` перегенерированы и приложены/зафиксированы (числа до/после).
- [ ] Изоляция типов урона (SCRUM-523/524) не нарушена — правки только в защитной оси, формула `derived_parameters` по урону не тронута.

## Files / точки входа

- `scripts/progression_data_balance.gd:57-65` — константы absorb/regen/vampiric (главные knobs): `SURVIVABILITY_ABSORB_MIN_DAMAGE_FRACTION`, `SURVIVABILITY_ABSORB_FLAT_DIMINISH`, `SURVIVABILITY_REGEN_FLAT_MULTIPLIER`, `VAMPIRIC_*`, `WEAPON_DRAIN_HEAL_MULTIPLIER` — снизить/поджать.
- `scripts/progression_data.gd:252-273` — формулы `effective_absorb`, `effective_regeneration`, `effective_vampiric_chance`, `effective_vampiric_cap` — при необходимости подправить базовые коэффициенты (напр. `0.22` реген-база, `endurance*0.16` absorb-база).
- `scripts/progression_data.gd:885-888` — сборка `absorb/regeneration/vampiric_chance/vampiric_amount` в `derived_parameters` (трогать только если меняется состав параметров).
- `scripts/player.gd:776-793` — `_apply_regeneration` (реген + пополнение vampiric-бюджета) и `on_weapon_hit` (трата vampiric-бюджета). Менять только при необходимости уточнить порядок/клампы.
- `scripts/player.gd:581-583` — порядок митигейта absorb→defense в `take_damage` (трогать осторожно, есть якорный тест).
- `scripts/class_weapon.gd:260-261, 776-786` — weapon-drain heal (`heal_percent_on_attack`, `_heal_owner_from_damage`).
- `scripts/event_data.gd` — указан в тикете, НО прямых vampiric/regen/absorb-механик не содержит (только `heal_percent`/`health_percent_cost` события). Менять не требуется; если правится баланс лечащих событий — здесь, но это вне ядра задачи.
- `tools/survivability_harness.gd` + `tests/global_survivability_balance_smoke_test.gd` — модель и гейт для проверки/отчёта «до-после».
- `scripts/progression_data_content.gd:111,134-137`, `scripts/meta_progression.gd:51-52`, `scripts/progression_data_weapons.gd` (passive_mods) — источники защитных модов (опциональная подстройка наград, шаг 7).

## Замечания / подводные камни

- **Anti-collision / locked paths:** глобального хардкод-списка locked нет — каждый исполнитель сам фиксирует свои locked paths при claim (Jira comment/status = lock, см. `docs/process/agent_role_boundaries_and_handoffs.md`). Перед стартом записать locked paths этой задачи: `scripts/progression_data_balance.gd`, `scripts/progression_data.gd`, `scripts/player.gd`, `scripts/class_weapon.gd`. ВАЖНО: `scripts/progression_data.gd` и `scripts/ui_screens.gd` — горячие коллизионные файлы; `ui_screens.gd` эта задача НЕ трогает вообще, а `progression_data.gd` касаться минимально. Бóльшую часть правок держать в `progression_data_balance.gd` (узкий, безопасный файл констант). Если другой lane уже держит `progression_data.gd` — не начинать, пометить `blocked`/оставить note и взять следующую.
- **Параллельные балансные тикеты эпика SCRUM-522:** недавно закоммичены SCRUM-503 (cap berserk hammer DPS) и SCRUM-524 (удаление архетип-множителя урона). Не пересекаться с их зонами; защитная ось изолирована от урон-формулы — следить, чтобы правки не утекли в DPS.
- **Инвариант изоляции типов урона (SCRUM-523/524):** НИ В КОЕМ случае не трогать `damage/magic_damage/sound_wave_damage`-ветви `derived_parameters` — есть гейт `tests/damage_type_isolation_test.gd`. Эта задача — только про absorb/regen/vampiric.
- **Два независимых канала вампиризма:** (1) стат-вампиризм через `_vampiric_heal_budget`/`on_weapon_hit` (управляется `VAMPIRIC_*`), (2) оружейный drain через `heal_percent_of_damage/on_attack` (управляется `WEAPON_DRAIN_HEAL_MULTIPLIER` + значения оружия). Чтобы «ослабить вампиризм измеримо», учесть ОБА; иначе оружейный дрейн (напр. 0.34 у одного из оружий, строка 270) останется имбой.
- **Харнесс не видит вампиризм:** `tools/survivability_harness.gd` моделирует только regen/absorb/defense/dodge. Нерф вампиризма НЕ отразится в `survivability_report.md` напрямую. Для измеримого «до/после» по вампиризму использовать `_budget_ehp` (EHP-модель оружия с `heal_percent_*`) или ручной расчёт по `VAMPIRIC_DAMAGE_HEAL_RATIO`/cap, либо (лучше) расширить харнесс полем lifesteal — но это уже бóльший объём, согласовать.
- **Не сломать tank-классы (играбельность отстающих):** robot/knight/doctor имеют `survival: "tank"` и пониженный `damage_budget` (0.85–0.88) — их выживаемость компенсирует низкий урон. Слишком резкий нерф absorb/regen сделает их неиграбельными. Проверять монотонность TTD и оставлять tank заметно крепче fragile.
- **Floor’ы маскируют бессмертие:** в гейте `effective_dps` зафлорен `0.05`, absorb — `min_damage_fraction`. Цель — чтобы `(mitigated - regen)` превышало порог за счёт реального ослабления, а не упиралось во floor. Если после правок строка проходит только из-за floor — нерф недостаточен.
- **Detерминизм отчётов:** harness детерминирован (без `randf`), поэтому «до/после» сравнимы построчно. Рантайм-вампиризм стохастичен (`randf() < chance`) — для измеримости опираться на ожидаемые значения (chance×amount×cadence), не на отдельный прогон игры.
- **Версионирование/патчноуты:** если правки войдут в релиз — отразить в in-game патч-нотах (`scripts/patch_notes_data.gd`) и changelog по обычному релизному процессу (вне ядра задачи, но не забыть при сборке версии).
