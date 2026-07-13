# FAN-1031 Stage 3d v8-микротрим — последний заход коридора ±15% + S4 random-floor

Последний балансировочный слайс по приёмочному **v8** координатора (ростер сошёлся
0.84…1.23, середина 0.91–1.11; в v2 было 0.49…10.80). Метрика — `tools/class_trio_table.py`
(скор = метрика класса / медиана ростера по осям solo=1t / aoe=5t / crowd=20t / defense=EHP;
total = среднее 4 осей; коридор ±15%).

**Разделение труда:** этот слайс — направленные правки рычагов (детерминированный дамп
`budget_tuning_for` / формула / cadence-математика). **Финальный v9 double-reshoot + точная
приёмка коридоров — за координатором**: roster-relative median дрейфует ВНИЗ от нерфов верхов и
ВВЕРХ от буста дна (нормированные скоры нетронутых классов ползут сами) — статикой это не свести,
а полный live-trio-пересъём вне лейна исполнителя (acid/homunculus persistent-pool сим зависает
>150с, как в 3a–3d). Каданс-кап и width-кап — ClassWeapon-live-механики, невидимые формульному
fast-эстимейту, поэтому их направление гарантировано детерминированно.

## v8 «до» (приёмка координатора) и правки

| класс | v8 total | вердикт | рычаг v8→v9 |
|---|--:|:--:|---|
| druid | 1.23 | FAIL+ | амулет `summon_damage_multiplier 0.85→0.78` (aoe 1.64 — амулет перелетел после ревайва ворона; призыв pure_summon → db НЕ ведёт) |
| robot | 1.22 | FAIL+ | db `0.80→0.75` — остаток = identity-price ТАНКА (def 2.12), survival НЕ режем |
| chemist | 1.18 | FAIL+ | db `0.85→0.80` (малый шаг per-hit blast/acid) |
| soldier | 1.17 | FAIL+ | db `0.76→0.72` (uniform per-hit) |
| priest | 1.16 (+random-A1 0.86) | FAIL+ | каденс reliquary `1.30→1.18` (чинит random) + width-кап хвоста кадила |
| dark_mage | 1.16 | FAIL+ | db `0.52→0.48` (per-hit dark_book/dark_wand) |
| guitarist | 0.84 | FAIL | raw к потолку капа (electric `1.28→1.30`, bass `0.48→0.50`) + амп `1.60→1.85` |
| ranger | 0.88 (crowd 0.56) | FAIL | db `1.26→1.38` (raw всех трёх, unclamped) |

## Механики (не численные рычаги)

### Priest — смягчение каденции + перенос крауд-добора на ШИРИНУ кадила
- **Каденс reliquary `1.30→1.18`** (`_fire_interval_artifact_factor`). ×1.30 перегибал RANDOM-билд
  (random-A1 0.86), т.к. каденс давит ВСЕ оси (DPS ∝ 1/cooldown), включая solo/random. Смягчение
  поднимает reliquary throughput ×(1.30/1.18)≈+10% — чинит random/solo.
- **Width-кап ХВОСТА кадила.** Чтобы crowd не улетел обратно от смягчения каденции, `_fire_priest_ward`
  теперь льёт волну через `_damage_enemies_in_circle_capped` (тот же капнутый direct-AoE контракт,
  что blast/acid), а конфиг опт-инится `aoe_full_targets:4` / `aoe_target_diminish:1.2`. Ближние 4
  цели — полный урон, дальний хвост толпы душится по формуле `1/(1+(rank−full+1)·diminish)`.
  **Жёсткого max НЕТ** (`aoe_max_targets` -1) → все в радиусе задеты, дальние слабее → identity
  «выжигают ВСЁ вокруг» цела (в отличие от hard-cap spore/orb/acid, где за N — ноль) → player-facing
  описание кадила НЕ меняем. Сентинел (нет полей → full 9999 / diminish 0) = plain-круг (нулевой A/B).
  Режет crowd БЕЗ solo (1 цель = rank 0 = полный). Пин + A/B на реальном конфиге:
  `coverage_cap_gate._test_censer_width_integration` + real-config pin 4/1.2; каденс-пин 1.18 +
  data-контракт: `priest_kit_test`.

### Guitarist — raw к потолку identity-капа (координаторская санкция)
- electric `1.28→1.30`, bass `0.48→0.50` — В ПРЕДЕЛАХ identity-капа 1.30/0.50 (bass<electric цел).
  db 1.50 не трогаем (держит кит клампнутым budget_dm=2.80 ceil → raw лендится 1:1). Осн. рычаг лифта —
  **амп** (uncapped identity-гейтом) `1.60→1.85` + median-дрейф от нерфов верхов. Если v9 <0.85:
  db↑ ещё (re-clamp лендит больше raw) — как договорено.

### S4 random-floor — офер-гарантия damage-карты (план §2.1-S4, впервые реализовано)
- Каждый level-up-показ ГАРАНТИРУЕТ ≥1 карту, релевантную УРОНУ класса. Рычаг —
  `weighted_level_up_selection` + новый `reward_is_damage_relevant` (урон-ось из
  {damage/magic_focus/attack_speed/crit_chance/crit_damage/dot_damage} И relevance ≠ optional по
  `ATTRIBUTE_RELEVANCE` — физ-«damage» у мага мёртв, matrix это кодирует). Форс на последнем слоте,
  только если в regular-пуле реально есть damage-карта класса (иначе грациозно пропускаем).
  damage-релевантная ⟹ non-optional по построению → УСИЛИВАЕТ старый инвариант «≥1 non-optional»,
  не нарушая «≤1 optional». `LEVEL_UP_REWARDS` не трогали (вычищен FAN-1034) — только офер-гарантия.
  Системно поднимает random-полы всех классов (worst v8 0.86). Гейт:
  `tests/level_up_damage_floor_gate.gd` (17 классов × 200 seed'ов + prefill capstone + helper A/B +
  satisfiability).

## Гейты (32 зелёных, гейтов НЕ ослаблял)

kit ×13 (chemist/robot/soldier/dark_mage/druid/ranger/elementalist/biologist/doctor/sniper/assassin/
guitarist/priest) + cap ×6 (aoe_target/coverage/orbit_falloff/status_fanout/pool_target/boss_hazard) +
`class_budget_profiles_integrity` + `global_damage_balance_smoke` (**worst CCT +20% — БЕЗ изменений**,
db-сдвиги реебейзят формулу зелёно; worst = sniper/deadeye/20t) + `content_rewards_integrity` +
`level_up_advisor` + `level_up_damage_floor_gate` (NEW) + `attribute_relevance` + `damage_type_isolation` +
`content_registry_consistency` + `progression_data_api_surface` + `contact_damage_softcap` +
`runtime_smoke` (base + weapon_mechanics — живой censer-путь). **Усилены** priest_kit (censer width
data-контракт), coverage_cap (censer integration + real-config pin); **добавлен** level_up_damage_floor_gate.

⚠️ **Известный-красный (Stage 4, за координатором):** `comfort_band_cross_class_gate` — стейл
comfort-веса (`class_mean_raw/median`) следуют за db; мой амп-raw-буст добавляет стейл в
`guitarist/sound_amp` CSV-веса (`COMFORT_*_OVERRIDES`). Рекалибровка comfort-весов под финальные db —
явно оставлена координатору на Stage 4. Не в приёмочном наборе.

## За координатором (v9 + Stage 4)
1. **v9 double-reshoot** всего ростера — точные after-totals ±15% (median-дрейф; live-полный вне лейна).
2. Доводка малых db-шагов по live (взяты КОНСЕРВАТИВНО — чтобы v9 фаинтюнил, а не разгребал overshoot).
3. Величина censer width-капа (4/1.2 — старт) + guitarist (если <0.85: db↑) по v9.
4. **Stage 4:** перекалибровка comfort-весов под финальные db; формальный ascension-гейт тестом;
   сводный before/after v2→v9; S4 random-floor уже введён (офер-гарантия) — проверить его вклад в live-полы.
