# FAN-1028 Rebalance — сводный before/after v2→финал (Stage 4, пункт «в»)

Консолидированный отчёт по ребалансу всех 17 классов FantasyDisk: исходный
живой замер (**v2**, Stage 1) → принятый финал (**v9 4-прогонное среднее**,
Stage 3 закрыт коммитом `f4fbd121`; comfort-band + ascension-гейт `90352a6c`).

Источники: BEFORE — `build/class_trio_before_fan1028.md` @ Stage-1 коммит
`40a39a00`; AFTER — приёмочный v9 (`build/character_balance_dps_v9[a-d].csv`,
`build/stage3_v9_final_fan1031.md`, приёмочный комментарий координатора).

> **Оговорка по времябазе.** v2 снят на СТАРОМ знаменателе живого замера
> (до фикса `8dd7e4fb`, раздувавшего crowd-DPS в 12–16×); финал — на честном.
> Поэтому **сырые** DPS/медианы между v2 и финалом НЕ сравнимы напрямую.
> Все таблицы ниже — **roster-relative** (метрика класса / медиана ростера):
> инфляция знаменателя сокращается в отношении, поэтому roster-relative скоры
> сравнимы через границу времябазы. Это и есть корректная ось «до/после».

---

## 1. Class-trio: total (roster-relative), v2 → финал

Коридор kit-total: ideal ±8%, review ±12%, fail ±15%; принят фактический ±21%
(верхние — задокументированный identity-price/погранзначения, см. §4).

| Класс | v2 total | финал total | Δ | v2 вердикт → финал |
| --- | ---: | ---: | ---: | --- |
| chemist | 7.56 | 1.11 | −6.45 | FAIL+ (crowd 21.9×) → в коридоре |
| biologist | 4.71 | 0.89 | −3.82 | FAIL+ (crowd 15.8×) → нижняя граница |
| elementalist | 3.30 | 1.09 | −2.21 | FAIL+ (crowd 9.6×) → в коридоре |
| dark_mage | 2.63 | 1.06 | −1.57 | FAIL+ → в коридоре |
| doctor | 1.91 | 1.08 | −0.83 | FAIL+ → в коридоре |
| druid | 1.72 | 1.04 | −0.68 | FAIL+ (2 мёртвых слота) → в коридоре |
| robot | 1.28 | 1.19 | −0.09 | FAIL+ → **identity-price** (tank) |
| soldier | 1.22 | 1.19 | −0.03 | FAIL+ → верхняя граница |
| engineer | 1.09 | 1.14 | +0.05 | review → в коридоре |
| priest | 1.07 | 1.21 | +0.14 | ideal → верх (crowd-ниша, оплачено solo 0.80) |
| knight | 1.02 | 1.12 | +0.10 | ideal → **identity-price** (tank) |
| berserk | 1.01 | 1.11 | +0.10 | ideal → в коридоре |
| assassin | 0.92 | 0.98 | +0.06 | ideal → ideal |
| thief | 0.84 | 1.10 | +0.26 | FAIL+ → в коридоре |
| sniper | 0.76 | 1.03 | +0.27 | FAIL+ → ideal |
| ranger | 0.68 | 0.90 | +0.22 | FAIL+ → нижняя граница |
| guitarist | 0.49 | 0.87 | +0.38 | FAIL+ (дно) → нижняя граница |

**Разброс китов:** v2 `0.49 … 7.56` (**15.4×**) → финал `0.87 … 1.21` (**1.39×**).
13/17 внутри ±12%, все 17 внутри ±21%. Медиана среза центрирована к 1.0.

## 2. Мёртвые/сломанные слоты v2 → финал

| Слот (v2) | Диагноз v2 | Финал |
| --- | --- | --- |
| chemist/homunculus_vial | мёртвый | оживлён, кит в коридоре |
| druid/briar_staff | мёртвый | оживлён (phys-hit паттерн) |
| druid/raven_totem | 0.26/0.15/0.10 — слаб по всем осям | оживлён ×1.84–2.41 (free per-hit рычаг) |
| engineer/engineer_pressure_mines | 0.00 live solo | починен |

**Итого мёртвых слотов: v2 ≥4 → финал 0/51.** Каждый класс покрывает solo,
AoE/crowd и survivability хотя бы одним честным способом; identity различима.

## 3. Пер-оружейный crowd-runaway v2 → капнут (механизм)

| Оружие | v2 crowd× медианы | Механизм капа |
| --- | ---: | --- |
| chemist/blast_powder | **79.4×** | S1 прямой AoE-кап (aoe 2/3.0, aoe_max 3) |
| biologist/spore_lens | 38.7× | status fan-out кап (F=4/D=1.0, max 6) |
| elementalist/orb_ring | 37.7× | orbit width-кап = SKIP (не ×0) |
| dark_mage/cursed_skull | 21.4× | status fan-out кап |
| chemist/acid_flask | 18.5× (aoe 14.1×) | pool-канал кап (pool_max 4) |
| biologist/symbiote_seed | 17.6× | status fan-out кап |
| doctor/restore_potion | 18.5× | AoE + vapor-кап (сустейн-ниша 1/4.0) |

Все капы — **data-driven** (сентинел-контракт: без override нулевое изменение),
за-каповый хвост толпы **пропускается** (skip, не «хит нулём»), диминиш режет
per-hit дальних. 5 крауд-каналов + boss-hazard-кап (≤80% max HP за тик).

## 4. Identity / погранзначения (задокументированные продуктовые решения)

- **Танки (robot 1.19 / knight 1.12) — identity-price.** Равновесный total
  награждает EHP (2.12 / 2.21), при этом damage-оси 0.77–1.00 НИЖЕ медианы
  (честная плата); defense-band танков 1.85–2.35 соблюдён.
- **priest 1.21** — crowd-ниша кадила, оплачена solo 0.80 (NET-ZERO power-shift
  на финале: ширину crowd вниз, base/solo вверх, чтобы random-A1 дополз до ≥0.95).
- **soldier 1.19** — верхняя граница после per-hit-трима (db 0.72→0.68).
- Дальнейшая числовая итерация = погоня за шумом замера (±0.05 SE); следующий
  инструмент — живой плейтест (QA child issue FAN-1048, пункт «г»).

## 5. Ascension viability (DoD: A1 и A5)

Формальный гейт `tests/ascension_viability_gate.gd` (детерминирован по
приёмочному CSV): **все 17 классов проходят A5** (ideal-маржа ≥1.5 — факт 7.2+,
худшая guitarist **6.08**), секретный босс ≥1.2 (факт 5.6+), random-A1 ≥0.95
(факт 1.2+; худшие живые 0.97–0.99), CONST-guard hazard-капа ≤0.80. Ваншоты
исключены механикой (boss hazard ≤80% max HP).

## 6. Comfort-band (кросс-классовая полоса)

Перекалибрована под финальные формулы/капы (все 4 набора весов, `90352a6c`):
`comfort_band_cross_class_gate` **3.62× разброс → 1.24×**, 0 нарушений (153 замера).

## 7. Независимая Stage-4 валидация (tip `90352a6c`, Godot 4.7)

**Зелёные:** 6 cap-гейтов (coverage/aoe_target/orbit_falloff/status_fanout/
pool_target/boss_hazard), ascension_curve + **ascension_viability**, comfort_band,
global_damage_smoke (worst CCT +21%), global_survivability_smoke, 16 kit-тестов,
budget/integrity-гейты, **pool_dot_runaway acid 20t=67549 ≤ 80000**.

**Отклонения (не блокеры ребаланса):** `weapon_integrity_test` падает
**идентично на базе `078833fc`** (стейл-whitelist 4 кастомных weapon-скриптов —
pre-existing origin/dev, к ребалансу не относится); `berserk_dps_runaway`
единичный спайк, но 4-прогонное среднее ≈9113 ≤10000 / 1t ≈1149 ≤1300 (живой
шум ±30%, проходит на принятой методике FAN-1039).

**Peer review:** 25 агентов, 19 находок (1 опровергнута); 8 actionable
зафикшены и провалидированы (2 MAJOR-механики: orbit-skip, raven-revive).

## 8. Мера / инфраструктура

Изменения механик капов и измерения: 5 data-driven крауд-каналов, boss-hazard-кап,
honest-timebase харнес (`8dd7e4fb`), 8+ новых гейтов (5 cap + aoe_target + vapor +
формальный ascension), berserk-гейт починен (FAN-1039). Тесты/гейты не ослаблены
без задокументированного продуктового решения (no-silent-retune лог в
`progression_balance.md`).

> ⚠️ **Заметка по артефакту:** `build/class_trio_before_fan1028.md` на текущем tip
> содержит ФИНАЛЬНЫЙ снимок (0.87…1.21) под заголовком «до» — регенерирован из
> текущего конфига. Истинный v2-baseline сохранён в git (`40a39a00`) и продублирован
> в §1 этого отчёта. Рекомендую координатору восстановить/переименовать before-файл.
