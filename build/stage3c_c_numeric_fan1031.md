# FAN-1031 Stage 3c-c — numeric down-tune верхов + druid rebuild + рычаг/coverage findings

Автор: Claude (headless-полоса), 2026-07-13. Ветка off `agent/claude/53f2a056` @ `5c347ae1`
(CSV v4). Вход: план FAN-1030 §2.2/§3, финальный пакет координатора («numeric верхов к total
≤1.15 + druid amulet вниз / raven из мёртвых; метод — детерминированные пропорции/A-B, НЕ один
live-прогон»), живой v4 CSV (`build/character_balance_dps.csv`).

Валидировано ЛЁГКИМИ детерминированными гейтами + формульной пробой `budget_tuning_for` (Godot
4.7 локально). Тяжёлый live 20t-пересъём (16 мин) headless-лейн не тянет — за интерактивной
полосой, как в 3a/3c-a/3c-b/3c-b2.

## 0. Главная находка: где на самом деле рычаг per-hit (и почему часть numeric — no-op)

Прежде чем тюнить, протрассировал путь урона по коду и проверил пробой. **Диагноз координатора
«остаток чисто numeric (per-hit blast_powder)» неточен по рычагу.**

- Живой урон direct-канала: `derived_parameters` (`progression_data.gd:2033`) =
  `damage_multiplier × budget_damage_multiplier`.
- `budget_tuning_for` (`:1124`) считает `budget_damage_multiplier = clampf(sqrt(solo_target/solo_dps
  × aoe_target/aoe_dps), 0.28, 2.80)`, где `solo_dps/aoe_dps` берутся из estimate БЕЗ бюджета (т.е.
  ∝ `damage_multiplier`). Значит `budget_damage_multiplier ∝ 1/damage_multiplier`.
- **Итог: `weapon.damage_multiplier × budget_damage_multiplier ≈ const` — правка
  `weapon.damage_multiplier` сама по себе живой DPS почти НЕ двигает**, авто-тюнер её съедает.
  Исключение — когда тюнер упёрся в кламп `[0.28, 2.80]` (тогда компенсация неполная).

Пруф (проба `budget_tuning_for`, halve `damage_multiplier` → отношение эффективного per-hit):

| оружие | dm | bdm | halve→bdm2 | eff2/eff1 | кламп после halve |
| --- | --- | --- | --- | --- | --- |
| chemist/blast_powder | 2.60 | 2.322 | 2.800 | **0.60** | да (upper) |
| dark_mage/dark_book | 0.95 | **2.800** | 2.800 | 0.50 | уже клампнут |
| dark_mage/dark_wand | 0.95 | **2.800** | 2.800 | 0.50 | уже клампнут |
| elementalist/prism_focus | 1.90 | 2.340 | 2.800 | 0.60 | да |
| elementalist/orb_ring | 1.35 | 1.211 | 1.708 | 0.71 | нет |
| druid/summon_amulet | 1.00 | **0.280** | 0.280 | 0.50 | уже клампнут (lower) |
| biologist/sample_injector | 0.85 | 1.623 | 2.687 | **0.83** | нет |

**Вывод:** правильный per-hit рычаг для перекормленных верхов — **сдвиг ЦЕЛИ профиля**
(`CLASS_BUDGET_PROFILES.solo_target/aoe_target/damage_budget`): он двигает `budget_damage_multiplier`
(значит живой per-hit по solo/aoe/crowd) И реебейзит формульный smoke-гейт (тот остаётся зелёным,
т.к. цель для сравнения тоже сдвигается). Для curse-only / pure-summon оружий budget-direct не
ведёт (bdm клампнут) — там живые рычаги = channel-множители (`curse_tick_multiplier`,
`summon_damage_multiplier`, `briar_hit_multiplier`, `raven_damage_multiplier`).

Проба и проектор (детерминированная проекция trio по CSV × eff-ratio) переиспользуемы —
скрипты в теле коммита разработки (одноразовые, в дерево не кладу; логика в
`tests/stage3c_c_numeric_gate.gd`).

## 1. Реализованные правки (все гейты зелёные)

| Класс | Правка | Файл | Проекция total (v4→) |
| --- | --- | --- | --- |
| **dark_mage** | `damage_budget 1.15→0.72`, `solo_target 0.84→0.66` (+ `cursed_skull curse_tick_multiplier 0.58→0.36`) | `progression_data_balance.gd`, `progression_data_weapons.gd` | **1.82 → ~1.39** (solo 1.33→1.05, aoe 2.58→1.97, crowd 2.80→1.96) |
| **elementalist** | `damage_budget 1.08→0.88`, `solo_target 1.00→0.92` | `progression_data_balance.gd` | **3.41 → ~2.71** (solo 1.20→0.97, aoe 2.02→1.58; crowd 7.68 coverage-остаток) |
| **druid** | амулет `summon_damage_multiplier 1.85→0.85` + `summon_role 1.45→1.15`; briar `briar_hit_multiplier 0.34→0.46` + `cap 5→6`; raven `raven_damage_multiplier 0.85→1.35` + `amp_pulse_interval 1.10→0.95` | `progression_data_weapons.gd` | **4.91 → ~2.18** (crowd 11.22→4.36; briar/raven перестают быть мёртвыми) |

Проекции — детерминированные, direct-канал (`eff`-ratio) + channel-ratio для curse/summon;
crowd частично coverage → живой 20t может отличаться (как урок restore_potion −24% в 3c-a). Величины
выбраны КОНСЕРВАТИВНО (не ниже 1.0 в проекции) — чтобы re-shoot фаинтюнил ВНИЗ, а не разгребал
overshoot. dark_mage ближе всех к коридору; при live>коридор — дожать `damage_budget` ещё.

**Identity сохранена:** dark_mage — «чистое проклятие» цело (int-скейл 0.08 не тронут, срезана
только величина тика); druid амулет остаётся crowd-лидером кита, briar = area-denial зона, raven =
деплой-бурст ниша; elementalist доли magic/phys/ожог не тронуты.

## 2. chemist / biologist — сознательно НЕ тронуты numeric'ом (нужно РЕШЕНИЕ)

Формульно доказано, что их crowd одним numeric в коридор не привести без нарушения DoD:

- **Модель скоринга (`tools/class_trio_table.py`) детерминирована:** axis = mean(3 оружия по оси)
  / медиана ростера; total = mean(4 осей). Медианы v4: solo 379, aoe 1122, crowd 6194.
- **chemist** crowd 29.90 = mean(blast 478802, acid 71215, homunc 5597)/6194. Один acid_flask
  (71215) уже держит crowd ≥4.1 даже при blast=0. Чтобы crowd→~1.3, нужно ×0.05 на blast И acid —
  это гробит их solo/aoe (blast 1t=685 → 34, оружие игнорируемо) → нарушение DoD.
- **biologist** crowd = инфекция-DoT = его **identity** («урон приходит со временем»).
  `biologist_kit_test` защищает контракт `seed DoT > impact` и `инфекция unamplified` — попытка
  срезать `curse_tick_multiplier` перевернула DoT<impact и провалила гейт (откатил).
- Корень crowd-разбега — **UNBUDGETED coverage** (формула бюджетит solo+aoe, не 20t): манекены
  харнеса стоят фи-таксис-диском R≈171px, а AoE-радиусы верхов покрывают почти весь диск, поэтому
  залп-по-цели (`_fire_aoe_projectile` → `_find_closest_enemies(projectile_count+extra)`) и
  инфекция-блэнкет раздают урон всей толпе. Пул/status/orbit/falloff-капы это частично сняли, но
  **прямой залп-по-цели blast_powder и прямой пирс-луч injector'а — последние некапнутые coverage-каналы.**

**Развилка (за координатором/лидером):**
- **(а) coverage-кап** на залп-по-цели / пирс-луч (новый data-driven механизм по образцу
  S1/пул/status — сентинел-контракт), следующий mechanic-slice. Закрывает crowd БЕЗ гроба solo.
- **(б) принять** crowd-лид AoE-специалистов как их профиль-identity (`chemist/biologist aoe_target
  1.30/1.18` уже санкционируют лид) и судить их по PROFILE-нормированному total + comfort-cap на
  crowd, а не по raw crowd-оси. Тогда 3c-c для них = не нужен.

Рекомендация headless: **(а)** — единственный путь, который и crowd закрывает, и identity/солo
бережёт; согласуется со всей data-driven-cap философией пакета. Но это НОВЫЙ механизм, а не numeric
(вопреки «капы исчерпаны») — поэтому отдаю решение с пруфом, а не делаю блайндом.

## 3. Что за интерактивной полосой (§4-контракт)

1. **Живой v5-пересъём** (направление проекций §1): dark_mage/elementalist (per-hit ↓ по профилю),
   druid (амулет ↓, briar/raven ↑ — самый шумный суммон-замер, брать среднее 2 прогонов).
2. **Доводка** `damage_budget` dark_mage/elementalist по live (если ещё вне коридора — дожать; клампы
   dark_book/dark_wand делают отклик суб-пропорциональным, поэтому проекция ~1.39, не 1.15).
3. **Решение по §2** (coverage-кап vs profile-identity) для chemist/biologist (+ druid amulet crowd,
   если live покажет остаток) — потом закрыть последний slice.
4. **3b дно-киты** (guitarist/sniper/assassin/thief) — mechanic-first, план §2.2, всё ещё не начаты
   (отдельный slice; их numeric-«raw выше сатурации» тоже упирается в тот же budget-тюнер — там
   рычаги = профиль-цели + сатурация тюнера гитариста, отдельная калибровка по live).

## 4. Ветка / коммиты / команды

Off `5c347ae1` (v4). Файлы: `scripts/progression_data_balance.gd` (профили dark_mage/elementalist +
шапка-коммент про рычаг), `scripts/progression_data_weapons.gd` (cursed_skull DoT, druid amulet/
briar/raven), `tests/stage3c_c_numeric_gate.gd` (+`.uid`), `docs/design/systems/progression_balance.md`
(no-silent-retune), этот handoff.

```
GODOT=~/Downloads/Godot.app/Contents/MacOS/Godot
$GODOT --headless --path . --import                                          # свежий checkout (один раз)
$GODOT --headless --path . --script res://tests/stage3c_c_numeric_gate.gd    # 3c-c A/B
$GODOT --headless --path . --script res://tests/dark_mage_kit_test.gd
$GODOT --headless --path . --script res://tests/druid_kit_test.gd
$GODOT --headless --path . --script res://tests/global_damage_balance_smoke_test.gd   # worst CCT +21% без изменений
```
Калибровочная полоса: живой v5 CSV, class-trio after (dark_mage/elementalist/druid), матрица возвышений.
