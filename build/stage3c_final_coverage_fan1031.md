# FAN-1031 Stage 3c-final — data-driven hard WIDTH cap (coverage) + crowd-runaway root-cause profiling

Автор: Claude (headless-полоса), 2026-07-13. Ветка off `agent/claude/53f2a056` @ `6b938bd4` (CSV v5).
Вход: финальный slice координатора (2026-07-13, коммент 88b5b0d2) — «coverage-cap для chemist/biologist
(снарядное покрытие + residual acid; одновременное заражение spore/symbiote), цель crowd_norm ≤1.56 =
1.2×1.30 профиля; elementalist residual к total ≤1.5; 3b дно-киты».

Валидировано **лёгкими детерминированными гейтами** + **прямой профилировкой live-канала** (счётчики).
Тяжёлый live 20t-пересъём (16 мин/полный CSV, ~17 мин/пара, замерил) headless-лейн для итерации не тянет —
за интерактивной полосой, как в 3a/3c-a/3c-b/3c-b2/3c-c.

## 0. ГЛАВНАЯ НАХОДКА: корень crowd-runaway — coverage (ШИРИНА) + measurement-артефакт frame-time

Прежде чем резать, **профилировал живой канал** (временные счётчики в `_damage_enemy`,
`_fire_aoe_projectile`, `_damage_aoe_projectile_explosion`; 150-кадровое окно; ideal-билд харнеса;
1/5/20 целей). Разложение blast_powder (chemist), tc = число целей:

| tc | casts | explosions | hits | hits/expl | total dmg | per_hit |
| --- | --- | --- | --- | --- | --- | --- |
| 1  | 6   | 7   | 6    | 0.9  | 1379     | **230** |
| 5  | 67  | 135 | 670  | 5.0  | 88061    | 131 |
| 20 | 67  | 135 | 2547 | 18.9 | 97614    | **38** |

Три факта, которые переворачивают диагноз «остаток = per-hit magnitude»:

1. **per_hit ПАДАЕТ с плотностью (230→38).** Диминиш-капы (S1/пул/status/orbit) УЖЕ работают —
   per-hit дальних целей срезан. Резать per-hit дальше = «выгрызать до бессмысленности» (запрет
   координатора). Значит crowd-runaway живёт НЕ в per-hit.
2. **hits взрываются (6→2547).** Runaway — это ШИРИНА (число событий урона), а не сила. Подтверждает
   решение координатора «резать ШИРИНУ».
3. **casts прыгают 6→67 при ТОМ ЖЕ числе кадров окна.** Оружие фаирит в `_process(delta)` через
   `_cooldown -= delta` (variable delta). `fire_interval` заклампан снизу 0.18с, значит 150 кадров
   ≤ ~14 кастов при ФИКС game-time. Наблюдаем 67 → **на 20 целях один `await process_frame` несёт
   в ~5× больше game-time** (тяжёлый кадр: много событий/твинов/физики → больше wall-delta).

### Следствие: живой crowd 20t частично — measurement-артефакт «frame-time-under-load»

`tools/character_balance_csv.gd::_measure_dps` копит hp-loss за `FRAMES=480` и делит на **константу**
`WINDOW_SECONDS=8.0`. Но при variable delta 480 тяжёлых кадров = НЕ 8с game-time, а больше → оружие
успевает больше кастов → «DPS» инфлируется пропорционально нагрузке кадра. Это объясняет:
- **экстремальные crowd-числа** (blast 20t ≈483k при 1t ≈700 = 687× — геометрия даёт ~10×, разница —
  cast-inflation);
- **12× run-to-run шум** (я снял свежий single-pair live: blast 5t качнулся `8.4k → 108k` = 12.8× при
  1t/20t совпавших с committed CSV) — ранее списанный на «flaky FAN-1039»;
- **почему диминиш-капы «не двигали» живой crowd** — они режут per-hit, но почти не снижают ЧИСЛО
  событий/кадр (кап `_damage_enemies_in_circle_capped` всё равно вызывает `_damage_enemy` на всех).

**Рекомендация лидеру (методика, за пределами моего slice):** гнать crowd к живому `crowd_norm 1.56`
рискованно — это догон артефакт-инфлированной метрики → over-nerf РЕАЛЬНОГО геймплея. Варианты:
- **(A)** судить crowd-ось по ДЕТЕРМИНИРОВАННОЙ per-cast-coverage / формуле (`class_trio_table.py` уже
  детерминирован), живой замер — только направление;
- **(B)** починить харнес: нормировать hp-loss на РЕАЛЬНУЮ сумму delta за окно (или fixed-timestep),
  и пересобрать base-line — это инвалидирует v1–v5 калибровку, поэтому решение лидера, не моё.

Харнес я НЕ трогал (сломал бы весь прежний процесс). Отдаю находку с воспроизводимой профилировкой.

## 1. Механизм: data-driven ЖЁСТКИЙ кап ШИРИНЫ (`*_max_targets`)

Диминиш-капы режут per-hit; нужен ОРТОГОНАЛЬНЫЙ рычаг на ЧИСЛО целей. Per-weapon поля
(`class_weapon.gd`, сентинел `<0` → без потолка → нулевое изменение без override — тот же контракт,
что S1/пул/status/orbit):

| поле | канал | helper/сайт |
| --- | --- | --- |
| `aoe_max_targets` | прямой AoE-взрыв | `_damage_enemies_in_circle_capped` (break за N) |
| `pool_max_targets` | тик лужи | `_damage_enemies_in_pool` (break за N) |
| `status_max_targets` | крауд-DoT/статусы | `_status_fanout_factor` → 0.0 за N (spore/symbiote/skull/acid-charge) |
| `orbit_max_targets` | тик квадрата орбит | `_orbit_fanout_factor` → 0.0 за N |

Ближние N целей (по дистанции от центра) — полный урон/статус; дальше — НОЛЬ. Композится с
диминишем (проверено гейтом: `status_full=1/D=1.0/max=3` → rank0=1.0, rank1=0.5, rank2=0.333, rank3+=0).
`_bio_spore_pulse`/`_germinate_symbiote_seed` рвут цикл заражения по `factor<=0` (order отсортирован по
дистанции → `break`, без фантомных 0-статусов). 1t / малый пак (rank<N) не тронуты → 0 изменения solo.

## 2. Override (СТАРТ, консервативно — калибровать по live crowd_norm ≤1.56)

| оружие | поле | поверх диминиша | after (direct-профиль, tc=20) |
| --- | --- | --- | --- |
| chemist/blast_powder | `aoe_max_targets=6` | aoe 4/3.0 | hits/expl 18.9→**6.0** (−68% событий; damage −10% — хвост был диминиш-мал) |
| chemist/acid_flask | `pool_max_targets=6` | pool_diminish 3.0 | пул-тик −20% (заряды-статус НЕ тронуты — свой кап стаков) |
| biologist/biologist_spore_lens | `status_max_targets=6` | status 4/1.0 | инфекция-DoT по ширине; прямой ring НЕ тронут |
| biologist/biologist_symbiote_seed | `status_max_targets=6` | status 4/1.0 | инфекция-DoT по ширине; linked (constellation, кап 5) отдельны |
| elementalist/elementalist_orb_ring | `orbit_max_targets=6` | orbit 3/1.0 | тик квадрата −33% |
| elementalist (профиль) | `damage_budget 0.88→0.82` | — | добивает solo/aoe к total ≤1.5 (item 2) |

**Почему damage −10% у blast, а не −70%.** Хвост за rank 6 УЖЕ был диминиш-мал (per_hit там ~единицы),
поэтому детерминированный УРОН падает слабо — но **число событий −68%** → сильно падает frame-load →
де-инфлируется живой замер (§0). Т.е. на артефакт-метрике живой эффект БОЛЬШЕ детерминированного.
Инфекция-DoT (spore/symbiote) идёт через `StatusEffects` (вне direct-профиля счётчика) — её ширина
режется, но в этой таблице не видна; живой 20t-срез покажет.

## 3. Что за интерактивной полосой (§4-контракт + следующий slice)

1. **Живой v6-пересъём** (направление): blast/acid/orb crowd вниз; spore/symbiote infection-DoT вниз;
   elementalist total (crowd width-кап + budget). Брать среднее ≥2 прогонов (§0 шум).
2. **Доводка `*_max_targets`** по live crowd_norm (старт 6 — двигать 4↔8; ниже = уже CDT, выше = мягче).
   Если crowd всё ещё высок при разумном N — это подтверждает §0 (артефакт), эскалировать методику.
3. **Решение по §0** (методика crowd-оси / фикс харнеса) — за лидером; влияет и на приёмку 3b.
4. **3b дно-киты (guitarist/sniper/assassin/thief/raven) — НЕ начаты (deferred, осознанно).** Их «raw
   ниже сатурации 2.80» судится по той же frame-inflated crowd-оси; буст к артефакт-инфлированному
   верху = over-buff. Разумнее калибровать после решения §0. Механики (mechanic-first §2.2) готов взять
   следующим slice, как только зафиксирована метрика.

## 4. Ветка / коммиты / команды

Off `6b938bd4` (v5). Файлы: `scripts/class_weapon.gd` (поля + парсинг + 4 helper'а/сайта),
`scripts/progression_data_weapons.gd` (5 override), `scripts/progression_data_balance.gd` (elementalist
budget), `tests/coverage_cap_gate.gd` (+`.uid`), `docs/design/systems/progression_balance.md`
(no-silent-retune + §0 находка), этот handoff.

```
GODOT=~/Downloads/Godot.app/Contents/MacOS/Godot
$GODOT --headless --path . --import                                       # свежий checkout (один раз)
$GODOT --headless --path . --script res://tests/coverage_cap_gate.gd      # новый A/B width-кап
$GODOT --headless --path . --script res://tests/chemist_kit_test.gd
$GODOT --headless --path . --script res://tests/biologist_kit_test.gd
$GODOT --headless --path . --script res://tests/elementalist_kit_test.gd
$GODOT --headless --path . --script res://tests/global_damage_balance_smoke_test.gd   # worst CCT +21% без изменений
# полный §4-контракт (все гейты + live CSV v6 + матрица возвышений) — интерактивная полоса
```

Все перечисленные гейты + orbit_falloff/status_fanout/pool_target/boss_hazard cap-гейты +
class_budget_profiles_integrity + damage_type_isolation + content_registry_consistency +
progression_data_api_surface + contact_damage_softcap + runtime_smoke — **зелёные локально (Godot 4.7)**.
Гейтов не ослаблял.
