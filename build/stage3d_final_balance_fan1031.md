# FAN-1031 Stage 3d — финальный балансировочный заход (v6 honest timebase)

Финальный numeric/coverage-заход по приёмочному baseline **v6** (среднее двух честных
прогонов, все капы включены, времябаза `8dd7e4fb`). Метрика — `tools/class_trio_table.py`
(скор = метрика класса / медиана ростера по осям solo=1t / aoe=5t / crowd=20t / defense=EHP;
total = среднее 4 осей; коридор ±15%).

**Разделение труда (по контракту координатора):** этот слайс — направленные правки рычагов,
подтверждённые (а) **детерминированным дампом** `ProgressionData.budget_tuning_for` (budget_dm)
и (б) **одиночными live `--pair`** (±30% шум на ideal — направление надёжно, точная величина нет).
**Финальный v7 double-reshoot + приёмка коридоров — за координатором.**

## v6 «до» (trio-модель, медианы ростера: solo 897 / aoe 2510 / crowd 7878 / EHP 85)

| класс | solo | aoe | crowd | def | total | вердикт | правка |
|---|--:|--:|--:|--:|--:|:--:|---|
| chemist | 1.00 | 3.28 | 2.11 | 0.63 | **1.76** | FAIL+ | db↓ + blast/acid width |
| elementalist | 1.03 | 1.74 | 2.58 | 0.60 | **1.49** | FAIL+ | db↓ + orb width |
| dark_mage | 1.11 | 2.19 | 1.72 | 0.59 | **1.41** | FAIL+ | db↓ (direct; curse нетронут) |
| soldier | 1.63 | 1.30 | 1.39 | 1.22 | **1.39** | FAIL+ | db↓ + bayonet solo-спайк |
| priest | 0.67 | 1.41 | 2.29 | 1.01 | **1.35** | FAIL+ | reliquary falloff + db↓ |
| berserk | 1.09 | 1.38 | 1.42 | 1.41 | **1.32** | FAIL+ | db↓ (axe; def in-profile) |
| guitarist | 0.30 | 0.53 | 0.73 | 0.80 | **0.59** | FAIL+ | RAW↑ (клампнут ceil) |
| ranger | 0.86 | 0.92 | 0.63 | 0.80 | **0.80** | FAIL+ | db↑ |
| sniper | 0.66 | 0.80 | 0.52 | 1.45 | **0.86** | FAIL | db↑ |
| druid/raven_totem | — | — | — | — | 0.14–0.26× | dead slot | RAW↑ + radius |
| assassin (crowd-ось) | 1.57 | 0.75 | **0.38** | 1.03 | 0.93 | ok(low crowd) | widen ОТКАЧЕН |

Классы в коридоре и НЕ тронутые: robot 1.20*, knight 1.11, engineer 1.06, thief 1.03,
doctor 0.96, biologist 0.89. (*robot 1.20 — def-driven tank, damage-оси ≤1.12; координатору
решить, нужен ли отдельный проход; в этот слайс не брал — не в списке координатора.)

## Рычаги и механика

**budget_damage_multiplier** = `clamp(√((solo_target·db·48/base_solo)·(aoe_target·db·150/base_aoe)), 0.28, 2.80)`.
Живой per-hit прямого канала = `weapon.damage_multiplier × budget_dm`. Отсюда:
- **db (damage_budget)** — единственный чистый uniform-рычаг per-hit класса (двигает budget_dm,
  а с ним ВСЕ оси; НЕ трогает clamp-упёртые оружия и curse_only DoT).
- **solo/aoe_target** — только наклон гео-среднего (идентичность профиля) — НЕ трогал.
- Width/coverage-капы (`*_max_targets` жёсткий / `*_full_targets`+`*_diminish` мягкий) —
  рантайм, режут aoe/crowd ШИРИНОЙ, solo (1 цель) целы. Вне budget-модели.
- Clamp-упёртые (budget_dm=2.80 ceil): guitarist ×3, priest censer/chime, druid briar,
  berserk hammer (вышел после db↓). Их live двигает ТОЛЬКО raw damage_multiplier — и только
  пока формульный таргет ≥ потолка.

## Применённые правки + измеренная реакция (single live run, id 1t/5t/20t)

| класс/оружие | рычаг | v6 (1t/5t/20t) | 3d (1t/5t/20t) | направление |
|---|---|---|---|---|
| chemist db 1.15→0.95 | + blast aoe 4/3→2/3, aoe_max 6→3; acid pool_max 6→4 | | | |
| ↳ blast_powder | width+db | 1703/20024/31584 | 1504/9509/14835 | crowd **−53%**, aoe −53% ✓ |
| elementalist db 0.82→0.70 | + orb orbit_max 6→4 | | | |
| ↳ orb_ring | width+db | 628/3767/17340 | 601/2979/**4332** | crowd **−75%** ✓ |
| ↳ prism_focus | db | 1586/6066/31137 | 1069/4651/24888 | solo −33%, crowd −20% ✓ |
| dark_mage db 0.72→0.58 | direct-канал | | | |
| ↳ dark_book | db | 1562/8569/25200 | 1245/6937/21026 | все ↓ ✓ |
| ↳ cursed_skull | curse_only (db НЕ трогает) | 405/1782/2688 | 405/1782/**2689** | нетронут ✓ (подтверждает изоляцию) |
| soldier db 1.00→0.82 | + bayonet close 1.12→1.06, auto 0.25→0.18 | | | |
| ↳ bayonet | db+спайк | 2414/2515/11367 | **1600**/1926/8898 | solo-спайк **−34%** ✓ |
| ↳ rifle | db | 925/2519/7970 | 662/2513/6854 | ↓ ✓ |
| berserk db 1.00→0.82 | axe (hammer вышел из клампа) | | | |
| ↳ axe | db | 1303/4252/21379 | 579/2683/**12886** | crowd **−40%** ✓ |
| priest db 0.92→0.86 | + reliquary falloff 3/2.2 | | | |
| ↳ reliquary | falloff+db | 876/4702/25825 | 993/4954/20159 | crowd −22% (⚠️ каденс-driven) |
| guitarist RAW (клампнут) | electric 0.66→0.80, bass 0.26→0.30, amp 0.85→1.00 | | | |
| ↳ electric_guitar | raw | 329/1120/3117 | 434/1407/3783 | **+21%** ✓ |
| ↳ bass_guitar | raw | 239/1351/6523 | 254/1542/8194 | **+26%** ✓ |
| druid/raven_totem | raw 1.35→2.40 + radius 120→150 | 190/623/1149 | 349/1264/**2774** | ×1.84/2.03/2.41 — ОЖИЛ ✓ |
| ranger db 1.15→1.26 | все три (budget_dm ✓) | — | budget_dm ×1.10 | ↑ (детерм.) |
| sniper db 1.00→1.15 | все три (budget_dm ✓) | — | budget_dm ×1.15 | ↑ (детерм.) |

## За координатором (v7 + решения)

1. **v7 double-reshoot** всего ростера — точные after-totals по коридору ±15% (медиана дрейфует
   вниз от нерфов верхов → нормированные скоры нетронутых классов растут сами; я это НЕ мог
   учесть — только полный пересъём). Мой лейн: acid_flask/homunculus (persistent-pool live-сим)
   зависают >150с — полный trio-пересъём у меня недоступен, отсюда single-pair направление.
2. **priest** — reliquary crowd КАДЕНС-driven (не width): falloff-кап трогает лишь хвост каждого
   бурста (4/1.5 vs 3/2.2 = −20% vs −22%, разница мизер). Довести priest в коридор — либо ещё db↓
   (роняет и так слабый solo 0.67), либо принять reliquary pack-clear как identity. Решение за вами.
3. **guitarist** — структурный дефицит: кит клампнут budget-ceil 2.80 (формула хочет больше),
   а RAW-buff упёрт в identity-гейт (рифф ≤0.80 / бас ≤0.30). Гейт НЕ ослаблял. Закрыть остаток
   до ≥0.85: поднять кламп-ceiling для класса / identity-границу / faster-riff mechanic — продуктовое.
4. **assassin crowd 0.38** — геометрический widen чакрама НЕ работает (откачен). Нужна отдельная
   механика (крауд-хит возвратной дуги сверх дедупа 1out+1return). Deferred.
5. **raven crowd** ~84% порога «жив» — при желании добить `raven_damage_multiplier` ещё чуть
   (модель пинована, буст лендится 1:1).

Все kit/cap/smoke/regression-гейты зелёные (worst CCT +20%). Пинованные значения капов в
`aoe_target_cap_gate`/`coverage_cap_gate`/`orbit_falloff_cap_gate` обновлены под новую калибровку
(документированная правка, не ослабление). berserk_dps_runaway_gate — известный флаки FAN-1039
(нерф hammer его только опускает).
