# FAN-1031 Stage 3 v9-финал — 2 финальных пункта + закрытие Stage 3 (исполнитель)

Последний слайс Stage 3 по приёмочному **v9** координатора (ростер `0.87…1.19`, сжатие
`15×→1.37×` от v2 `0.49…10.80`, мёртвых слотов `0/51`; координатор: «дальше гоняться за
шумом ±0.1 бессмысленно»). Даны 2 финальных пункта.

**Метод приёмки этого слайса (по указанию координатора):** budget-дамп (детерминированный
per-hit A/B через `ProgressionData.budget_tuning_for`) + по одному `--pair` live (soldier,
priest) + kit-тесты. **Полный v10-пересъём НЕ гоним** — направления детерминированы,
координатор принимает по дампу/парным замерам. Live-полный trio вне лейна исполнителя
(acid/homunculus persistent-pool sim зависает >150с).

## 1. Soldier — per-hit вниз (solo 1.50 bayonet-driven → профиль 1.00)

`CLASS_BUDGET_PROFILES["soldier"].damage_budget 0.72→0.68` — малый uniform per-hit шаг всех
трёх оружий (все unclamped → лендится 1:1).

**Budget-дамп A/B (`budget_damage_multiplier`, детерминированно):**

| оружие | dm v9 (0.72) | dm после (0.68) | Δ per-hit | клампа |
|---|--:|--:|--:|:--:|
| soldier_rifle | 1.405 | 1.327 | −5.6% | нет (в (0.28,2.80)) |
| soldier_grenade | 1.194 | 1.128 | −5.5% | нет |
| soldier_bayonet | 0.889 | 0.839 | −5.6% | нет |

Δ = ratio `0.68/0.72 = 0.944` на всех — равномерный per-hit срез, давит solo-спайк 1.50 к
профилю. `def 1.22` (steady, in-profile) не тронут.

## 2. Priest — NET-ZERO power-shift крауд→base/solo (random-A1 0.87 < 1.0)

`random-A1 0.87` — единственный fail ascension-гейта. Диагноз координатора: сила Жреца заперта
в крауд-ширине кадила (crowd 1.59), а RANDOM-билд её не добирает надёжно. Переносим силу С
крауд-ширины НА base/solo, `total 1.14` держим (net-zero).

### base/solo ВВЕРХ — reliquary (соло-бурст, unclamped)

Два ортогональных рычага, оба лендятся на reliquary:

1. **Каденс-налог `_fire_interval_artifact_factor` reliquary `1.18→1.08`** — throughput
   `×(1.18/1.08)≈+9.3%` по ВСЕМ осям. Каденс = live-множитель вне budget-формулы →
   **НЕ** компенсируется тюнером (в отличие от per-hit).
2. **`solo_target 1.03→1.10`** — budget-дамп A/B: reliquary `dm 1.755→1.813 (+3.3%)` per-hit
   (unclamped лендит). **censer/chime clamped на ceil 2.80 → solo_target их НЕ двигает** (дамп:
   оба `dm=2.800` до и после) — лифт хирургически reliquary-only, не трогает крауд-оружие.

**Суммарный reliquary-лифт ≈ `1.093 × 1.033 = +12.9%`** на solo/aoe/crowd. reliquary crowd
hard-капнут falloff (`3/2.2`) → крауд-леак лифта минимален (лифт идёт в base/solo).

**Live `--pair` подтверждение (reliquary, чистый сигнал):**

| ось | rnd до→после | id до→после | l1(1t) до→после |
|---|--:|--:|--:|
| 1t | 80.0→90.8 (+13.5%) | 775→942 (+21%) | 63.7→71.7 (+13%) |
| 5t | 477→532 (+11.5%) | 3912→4385 (+12%) | 266→283 |
| 20t | 2366→2853 (+21%) | 17549→19390 (+10%) | 975→1124 |

Все 6 чисел вверх ~+11…21% — совпадает с проекцией +12.9%. Это лифт random-floor.

### crowd ВНИЗ — censer (крауд-оружие)

Width-кап хвоста `aoe_full_targets 4→3` + `aoe_target_diminish 1.2→1.7`. Крауд-хвост душится
круче (детерминированная формула `amount/(1+(rank−full+1)·diminish)`, gated `coverage_cap_gate`):

| rank | factor 4/1.2 | factor 3/1.7 | срез |
|--:|--:|--:|--:|
| 3 | 1.000 (в full) | 0.370 | −63% |
| 4 | 0.455 | 0.227 | −50% |
| 5 | 0.294 | 0.164 | −44% |
| 6 | 0.217 | 0.128 | −41% |

Censer per-hit clamped → width НЕ трогает solo (1 цель = rank 0 = полный). Жёсткого max НЕТ →
identity «выжигают ВСЁ вокруг» цела → **player-facing описание кадила НЕ меняем**. Это net-zero
компенсация лифта base/solo на крауд-оси.

**⚠️ live censer/soldier single-`--pair` НЕЧИТАЕМ по направлению — слишком шумны** (кадило —
tween-пульсы, байонет — мили-позиционка): censer 1t качнулся `37.5→72.4` при том, что ширина
на 1 цели НЕактивна — чистый run-to-run шум. Их направление держит **детерминированный
дамп/формула**, не live (координаторская доктрина: live=направление, шум усредняют 2–4 прогонами).

## Пины (документированная правка, НЕ ослабление)

- `priest_kit_test._check_cadence_tax`: reliquary `1.18→1.08` (censer 1.15 / chime 1.0 не тронуты).
- `coverage_cap_gate` real-config pin кадила `4/1.2→3/1.7`. Интеграционный
  `_test_censer_width_integration` читает реальный конфиг → формула диминиша проверяется
  поведенчески (адаптивно к full/diminish).

## Гейты — 11 прогнано зелёными, гейтов НЕ ослаблял

`priest_kit` · `soldier_kit` · `coverage_cap_gate` · `class_budget_profiles_integrity`
(solo_target 1.10 / soldier db 0.68 в границах (0,2]; priest profile 'balanced' → ordering
solo>aoe допустим) · `global_damage_balance_smoke` (**worst CCT +20% — БЕЗ изменений**,
sniper/deadeye/20t — priest-сдвиги worst не двигают) · `runtime_smoke` (base) ·
`runtime_smoke_weapon_mechanics` (живой censer/reliquary путь) · `damage_type_isolation` ·
`priest_sustain_softcap` · `content_registry_consistency` · `contact_damage_softcap`.

## За координатором

- Авторитетный v10-контроль (если решит) + подтверждение `random-A1 ≥1.0` по live-полам
  (reliquary-лифт +12.9% + S4 offer-гарантия + median-дрейф).
- Stage 4 (FAN-1032): перекалибровка comfort-весов под финальные db; формальный ascension-гейт
  тестом; сводный before/after v2→v9; проверка вклада S4 random-floor в live-полы.

Со стороны исполнителя **Stage 3 закрыт**.
