# FAN-1031 Stage 3d-final — доводка коридора по v7 + 3 структурных решения

Финальный слайс балансировки по приёмочному **v7** (координатор, коммит `615b596c`,
среднее двух честных прогонов). Метрика — `tools/class_trio_table.py` (скор = метрика
класса / медиана ростера по осям solo=1t / aoe=5t / crowd=20t / defense=EHP; total =
среднее 4 осей; коридор ±15%). Медианы ростера v7: **solo 820 / aoe 2656 / crowd 8556 / EHP 85**.

**Разделение труда (контракт координатора):** этот слайс — направленные правки рычагов,
подтверждённые **детерминированным дампом** `ProgressionData.budget_tuning_for` (budget_dm +
effective per-hit = `raw × budget_dm`). **Финальный v8 double-reshoot + точная приёмка коридоров —
за координатором** (roster-relative median дрейфует вниз от нерфов верхов и вверх от буста дна —
статикой это не учесть; полный live-trio-пересъём вне лейна исполнителя: live-симы зависают
в тайм-аутах, как в 3a–3d). Каданс-кап (priest) и яд-спред (assassin) — ClassWeapon-live-механики,
невидимые формульному fast-эстимейту, поэтому их направление гарантировано детерминированно
(каданс: DPS ∝ 1/cooldown; спред: добавляет капнутый крауд-канал), а величина — за v8.

## v7 «до» (trio-модель)

| класс | solo | aoe | crowd | def | total | вердикт | правка |
|---|--:|--:|--:|--:|--:|:--:|---|
| chemist | 1.27 | 2.16 | 1.38 | 0.63 | **1.36** | FAIL+ | db↓ (малый шаг) |
| robot | 0.84 | 1.05 | 1.30 | 2.12 | **1.33** | FAIL+ | db↓ — остаток = ТАНК-identity |
| priest | 0.75 | 1.22 | 1.89 | 1.01 | **1.22** | FAIL+ | каданс-кап reliquary/censer |
| soldier | 1.42 | 0.98 | 1.14 | 1.22 | **1.19** | FAIL+ | db↓ |
| dark_mage | 1.04 | 1.69 | 1.33 | 0.59 | **1.16** | FAIL+ | db↓ (малый шаг) |
| elementalist | 1.00 | 1.27 | 1.75 | 0.60 | **1.16** | FAIL+ | db↓ (малый шаг) |
| sniper | 0.84 | 0.69 | 0.48 | 1.45 | **0.86** | FAIL | db↑ + deadeye |
| assassin | 1.44 | 0.64 | **0.31** | 1.03 | **0.85** | FAIL | venom_wire яд-спред |
| guitarist | 0.36 | 0.56 | 0.73 | 0.80 | **0.61** | FAIL+ | RAW↑ identity-капы (продукт-решение) |

## Три структурных решения координатора (v7)

### 1. Guitarist — ПРОДУКТОВОЕ решение (DoD FAN-1028), НЕ тихое ослабление гейта
Класс `survival: control` несёт часть бюджета в CC амп-сети, а trio-модель контроль НЕ считает
(ось defense = EHP, не CC) → кит структурно недооценён. **Решение:** поднять identity-капы кита,
задокументировано (не двойной зачёт — компенсация НЕсчитаемого контроля). Ramp/амп-control
identity (warmup 0.02/сек / кап 0.20, амп-сеть) сохранены; относительная «ранняя слабость баса»
сохранена новым пином `бас < рифф`.

| оружие | raw v7→3d-final | budget_dm | eff per-hit (было→стало) | ×  |
|---|---|--:|---|--:|
| electric_guitar | 0.80→**1.28** | 2.80 (clamped) | 2.24→**3.58** | ×1.60 |
| bass_guitar | 0.30→**0.48** | 2.80 (clamped) | 0.84→**1.34** | ×1.60 |
| sound_amp | 1.00→**1.60** | 2.40 | ~2.6→**3.84** | частично |

db `1.00→1.50` держит кит клампнутым на ceil ПОСЛЕ raw-буста → raw лендится 1:1 (иначе тюнер
частично компенсирует; при db 1.25 electric распинался budget_dm 2.33 → eff лишь 2.99). Гейты
`class_budget_profiles_integrity` + `global_damage_balance_smoke` (worst CCT +20% без изменений)
зелёные при db=1.50. Кит-гейт: `guitarist_kit_test` рифф ≤1.30 / бас ≤0.50 / бас<рифф. Статик-
проекция: solo/aoe/crowd ×1.60 → ~0.58/0.90/1.17, total ≈0.86 + median-дрейф вниз (нерфы верхов) → ≥0.85.

### 2. Priest — каданс-кап (НЕ width), цель crowd_norm ≤1.25
crowd 1.89 = каденс-driven (storm-бланкет толпы: reliquary storm_ticks=3 покрывают весь falloff-круг
каждый каст). **Рычаг:** `_fire_interval_artifact_factor()` (та же «точка потребления», что mode-
переработки) замедляет БАЗОВЫЙ fire_interval: **reliquary ×1.30, censer ×1.15** → throughput всех
осей ↓ пропорционально (DPS ∝ 1/cooldown). WIDTH (falloff_full/diminish) и pack-clear-breadth
identity НЕ трогаем. Ideal-крауд-билд НЕ включает mode-артефакты (reliquary_salvo/censer_vow имеют
только `mods`, без `stats` → `_dps_score`=0 → не в топ-N ideal-оффера) → базовый тэ применяется к
замеру без offset'а этими режимами. **Проекция (деттерм., без median-дрейфа):** reliquary 20t ×0.77,
censer ×0.87 → crowd mean (20435/11964/15987)→(15735/10409/15987), norm 1.89→~1.64. Остаток к ≤1.25:
chime (1.87× медианы) по указанию НЕ тронут (reliquary/censer only) — median-дрейф от буста дна +
решение координатора по chime на v8. Пин + A/B-контроль: `priest_kit_test._check_cadence_tax`.

### 3. Assassin — crowd-ниша venom_wire «яд-спред по толпе в существующих капах», цель crowd_norm ≥0.45
venom 20t=1376 ≈ 1t=1233 (пирс-4 почти не масштабируется толпой; узкий beam_width 32 ловит мало).
**Механизм (сентинел-контракт):** новое поле `dot_beam_spread_ratio` (0.0 → no-op / нулевой A/B).
После пирса струна брызгает ядом по врагам ВНЕ пробитой линии (`_venom_crowd_spread`), ядро — самая
глубокая пробитая (там плотнее толпа). Кап ШИРИНЫ — **существующие** поля прямого AoE (`aoe_max_targets
6 / aoe_full_targets 2 / aoe_target_diminish 1.6`; venom иначе их не использует), та же диминиш-формула
по рангу. **ОРТОГОНАЛЬНОСТЬ solo:** пробитые исключены → на 1 цели она пробита → спреда нет → solo-ось
(assassin solo 1.44, уже над профилем) НЕ раздувается. venom config: `dot_beam_spread_ratio 0.55`.
Chakram widen (3d) остаётся ОТКАЧЕН — геометрия не рычаг. Величину калибрует координатор по v8.
Тесты: пирс-лимит-сабтест изолирован (`dot_beam_spread_ratio=0` — спред тестируется отдельно), новый
`_test_venom_wire_crowd_spread` (solo A/B-ортогональность + крауд-хит не-пробитых + жёсткий кап ширины).

## Numeric-трим (db, budget-дамп-подтверждён)

| класс | db v7→v8 | измеренная реакция eff per-hit | примечание |
|---|---|---|---|
| chemist | 0.95→**0.85** | blast 5.02→4.49, acid 0.415→0.372 | остаток aoe-лид = profile-identity (aoe_target 1.30, aoe_max 3) |
| robot | 0.88→**0.80** | magnetic 4.30→3.91, press 2.86→2.60 (reactor clamped) | ⚠️ остаток total>1.15 = ТАНК def 2.12; survival НЕ режем |
| soldier | 0.82→**0.76** | bayonet 0.93→0.86, rifle 0.96→0.89 | uniform |
| dark_mage | 0.58→**0.52** | dark_book 1.72→1.54, dark_wand 1.63→1.46 | cursed_skull curse_only — db не трогает |
| elementalist | 0.70→**0.63** | prism 2.76→2.49, orb 1.02→0.92 | остаток crowd-лид = prism (orbit уже капнут) |
| sniper | 1.15→**1.35** ↑ | deadeye 1.35→1.58, spotter 3.46→4.07, shatter 0.54→0.64 | + `DEADEYE_ENDPOINT_BLAST_RATIO 0.35→0.42` (вне budget-комп.) |

## Гейты

**Зелёные (24):** kit — guitarist/priest/assassin/sniper/chemist/robot/soldier/dark_mage/elementalist/
biologist/doctor/druid; cap — aoe_target/coverage/orbit_falloff/status_fanout/pool_target/boss_hazard;
`class_budget_profiles_integrity`, `global_damage_balance_smoke` (worst CCT **+20% — без изменений**),
`damage_type_isolation`, `content_registry_consistency`, `progression_data_api_surface`,
`contact_damage_softcap`. **Гейтов НЕ ослаблял.**

**Известный-красный ДО правок:** `comfort_band_cross_class_gate` — v7 baseline уже 7 нарушений
(проверено git-stash'ем на чистом `615b596c`); после моих db-сдвигов 18 (стейл comfort-веса
`class_mean_raw/median` следуют за db). Это Stage-4 перекалибровка comfort-весов, которую координатор
явно оставил себе ПОСЛЕ фиксации db на v8 (см. его план: «Stage 4 = … comfort-веса»). Премейчур-
рекалибровка под ещё-двигающиеся db была бы сразу устаревшей. НЕ в приёмочном наборе «15/15».

## За координатором (v8 + решения)

1. **v8 double-reshoot** всего ростера — точные after-totals ±15% (median-дрейф; live-полный вне лейна).
2. **priest** — величина каданс-тэ + решение по chime (остаток crowd к ≤1.25 после median-дрейфа).
3. **assassin** — калибровка `dot_beam_spread_ratio` до crowd_norm ≥0.45.
4. **guitarist** — если v8 <0.85: db↑ ещё (re-clamp лендит больше raw) или identity-кап ещё выше.
5. **robot** — судить по damage-осям, не total (tank-price); нужен ли отдельный проход — решение.
6. **Stage 4** — перекалибровка comfort-весов под финальные db; формальный ascension-гейт тестом.
