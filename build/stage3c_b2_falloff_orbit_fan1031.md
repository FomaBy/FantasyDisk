# FAN-1031 Stage 3c(b2) — FALLOFF/ORBIT fan-out data-driven кап

Автор: Claude (headless-полоса), 2026-07-13. Ветка off `agent/claude/53f2a056` @ `3ecc4052`
(v3'' CSV). Вход: план FAN-1030 §2.1(в)/§2.2, координатор-приоритет №1 финального пакета
(«3c-(b2): data-driven кап falloff/orbit-каналов + override для blast_powder и orb_ring»),
карта каналов `build/stage3c_b_status_fanout_fan1031.md`, живой v3'' CSV
(`build/character_balance_dps.csv`).

Реализован **последний некапнутый throughput-канал прямого урона** — крауд-fan-out helper'ов,
раздающих полный урон КАЖДОЙ цели без диминиша по ЧИСЛУ целей. S1 (3a) закрыл прямой
AoE-взрыв, 3c(a) — пул-канал, 3c(b) — крауд-раздачу СТАТУСОВ. Оставались два helper'а
прямого урона, которые в живом v3'' держали верхи crowd-runaway.

## Уточнение каналов (проверено по коду — важно для валидации)

Диагностика координатора («chemist/elementalist runaway живёт в `_damage_enemies_in_circle_falloff`
(blast_powder) и орбитальном канале orb_ring») **неточна по каналам**. Реальная трассировка:

| offender (v3'' 20t) | заявленный канал | ФАКТИЧЕСКИЙ канал (код) |
| --- | --- | --- |
| chemist `blast_powder` `494.9k` (≈108× медианы 4574) | `_damage_enemies_in_circle_falloff` | **`aoe_projectile`** → `_launch_aoe_projectile` (l.1298) → `_damage_aoe_projectile_explosion` → `_damage_enemies_in_circle_capped` — **уже НА S1-капнутом пути** (щедрый дефолт 5/2.0) |
| elementalist `elemental_orbit` (orb_ring) `197.8k` (≈43×) | «орбитальный канал» | `_exec_elemental_orbit` → `_fire_elemental_orbit` → **`_elemental_square_tick`** (l.3311): magic+phys+ожог КАЖДОМУ врагу в квадрате, крауд-кап ОТСУТСТВОВАЛ |
| `_damage_enemies_in_circle_falloff` | «blast_powder» | фактический пользователь — **burst черепа Тёмного мага** (`_fire_curse` l.1341, `rolled*0.42`), dark_mage уже де-эскалирован 3c(b) до total 1.98 |

Вывод: **orb_ring — единственный по-настоящему некапнутый крауд fan-out** из двух названных.
blast_powder режется существующим S1-рычагом (геометрия), но его главный драйвер — per-hit
magnitude (3c-c). falloff — реальный некапнутый канал, но его текущий пользователь уже
де-эскалирован; рычаг отдаётся калибровочной полосе.

## Реализовано (механизм, детерминированно, лёгкий гейт)

1. **Per-weapon поля** `ClassWeapon.falloff_full_targets/falloff_target_diminish` и
   `orbit_full_targets/orbit_target_diminish` (`class_weapon.gd`). Сентинел `<0` →
   `FALLOFF_FANOUT_* / ORBIT_FANOUT_*` (дефолт diminish `0.0` → `factor==1` для ВСЕХ рангов →
   **нулевое изменение поведения без override**; тот же сентинел-контракт, что S1/пул/status).
2. **Helper'ы** `_falloff_fanout_factor(rank)` / `_orbit_fanout_factor(rank)` —
   `factor = 1/(1+(rank−full+1)·D)` для `rank≥full`, иначе `1.0`. Единая формула диминиша толпы
   (та же, что `_status_fanout_factor` / `_damage_enemies_in_circle_capped` / S1 / пул).
3. **Проведены в 2 крауд-сайта** (ранг = дистанция от центра):
   - `_damage_enemies_in_circle_falloff` — крауд-кап ХВОСТА поверх РАДИАЛЬНОГО спада
     (радиальный `minimum_factor` остаётся — ортогональная per-target ось). Дистанционная
     сортировка через `_status_fanout_order` (переиспользован).
   - `_elemental_square_tick` — `magic_tick`, `physical_tick` и тик ожога `four_elements_burn`
     масштабируются одним `_orbit_fanout_factor(rank)`. Ранг берётся из ОТДЕЛЬНОЙ карты
     (`orbit_ranks` по instance_id) — **порядок итерации и `phase_target` (вход constellation
     `hit`) НЕ тронуты** (zero-collateral). Пуш/резонанс/репульс без изменений.

### Первичные override

| оружие | поле | значение | канал | Σfactor 20t | Δ 20t | Δ 5t | Δ 1t |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `elementalist_orb_ring` | `orbit_full_targets/diminish` | **3 / 1.0** | orbit (чистый fan-out) | 20→**5.50** | **−72.5%** | −23% | 0% |
| `chemist/blast_powder` | `aoe_full_targets/diminish` | **4 / 3.0** | прямой AoE (S1) | 6.37→**4.99** | **−22%** | −15% | 0% |

- **orb_ring** — чистый крауд fan-out (три канала магии/физики/ожога скейлятся вместе, отдельного
  «прямого» канала нет), поэтому −72.5% — тесная проекция 20t: `197.8k → ~54k` (43×→~12× медианы).
  Остаток до коридора (~3× медианы) — **per-hit numeric 3c-c**.
- **blast_powder** — правим только ГЕОМЕТРИЮ (щедрый дефолт 5/2.0 → 4/3.0). Диминиш даёт макс
  ≈×4 — **108× медианы им одним НЕ закрыть**; главный драйвер — раздутый per-hit magnitude
  (build-стек ×`damage`, `damage_multiplier 2.60`). Per-hit — **3c-c numeric против v3'''**.
  Идентичность «пара взрывов по ближайшим целям» цела (4 ближних полным, 1t=0%).
- **falloff-рычаг НЕ переопределён нигде** — готовый knob для калибровочной полосы (аналог
  оставленного acid_charge-рычага в 3c(b); burst черепа уже де-эскалирован 3c(b), слепой numeric
  без пересъёма запрещён issue).

## Гейт (новый, лёгкий, детерминированный)

`tests/orbit_falloff_cap_gate.gd` — sanity-probe компиляции; helper override `4/1.0` обоих
каналов (rank0-3=1.0, rank4=0.5, rank5=1/3, rank6=1/4); сентинел-контроль (factor 1.0 всем
рангам обоих helper'ов); **интеграция falloff** (`minimum_factor=1.0` нейтрализует радиальный
спад → урон = amount·fanout(rank), + A/B-контроль без override = все полный урон);
**интеграция orbit** на реальном `_elemental_square_tick` (ratio-проверка magic+phys total И
ожог-DoT хвоста против ядра, + A/B-контроль без orbit-полей = все полный тик); реальные конфиги
(orb_ring orbit=3/1.0; blast_powder aoe=4/3.0 — прямой AoE, НЕ falloff; falloff не переопределён);
CONST-guard дефолтов no-op. **PASS.**

**Регрессия (все PASS, локальный Godot 4.7):** `elementalist_kit_test` (гоняет реальный
`_elemental_square_tick`), `dark_mage_kit_test` (falloff burst черепа), `chemist_kit_test`
(blast direct), `biologist_kit_test`, `doctor_kit_test`, `status_fanout_cap_gate`,
`pool_target_cap_gate`, `boss_hazard_cap_gate`, `class_budget_profiles_integrity`,
`damage_type_isolation`, `content_registry_consistency`, `progression_data_api_surface`,
`contact_damage_softcap`, `global_damage_balance_smoke` (51 пара, worst CCT **+21% — БЕЗ
изменений**: капы рантаймовые, ортогональны формульной бюджет-модели). **Гейтов не ослаблял.**

## Handoff: живой пересъём + 3c(c) numeric + 3b дно-киты

1. **Живой v3'''-пересъём (за интерактивной полосой).** Подтвердить направление 20t: orb_ring
   (весь срез — DoT+magic+phys — капнут одним фактором, ожидаемо близко к −72.5%), blast_powder
   (−22% только от геометрии; per-hit НЕ тронут → срез будет меньше). Тяжёлый DPS-харнес
   headless-лейн в тайм-аутах не тянет (как в 3a/3c-a/3c-b).
2. **Доводка `orbit_target_diminish`/`orbit_full_targets`** против живого 20t: если elementalist
   ещё выше коридора — это уже per-hit magnitude (magic/phys/dot доли), тюнить numeric (3c-c), а
   НЕ давить диминиш ниже 3/1.0 (риск убить identity зоны; диминиш даёт макс ≈×4).
3. **3c(c) numeric верхов** — теперь механизм ПОЛОН (прямой AoE + пул + status + falloff/orbit).
   `blast_powder` `damage_multiplier 2.60` — главный кандидат (108× медианы); chemist total 10.96
   → ≤1.15 требует именно per-hit (по СРЕДНЕМУ 2 прогонов, не слепо). elementalist orb_ring доли
   magic/phys/dot. `druid/summon_amulet 110.4k` — summon-механика (3b/druid, НЕ fan-out helper).
4. **falloff-рычаг** — если v3''' покажет остаточный runaway в burst-канале (напр. cursed_skull
   после re-check) — задать `falloff_full_targets/falloff_target_diminish` (рычаг готов).
5. **3b дно-киты** (guitarist/sniper/assassin/druid briar-raven) — mechanic-first, план §2.2,
   против v3'''.

## Ветка / коммиты

Off `3ecc4052` (v3''). Файлы: `scripts/class_weapon.gd` (2 поля-пары + 2 helper'а + 2 сайта),
`scripts/progression_data_weapons.gd` (orb_ring orbit-override, blast_powder aoe-override),
`tests/orbit_falloff_cap_gate.gd` (+`.uid`), `docs/design/systems/progression_balance.md`
(no-silent-retune лог), этот handoff.

## Команды

```
GODOT_BIN=~/Downloads/Godot.app/Contents/MacOS/Godot
$GODOT_BIN --headless --path . --import                                            # свежий checkout
$GODOT_BIN --headless --path . --script res://tests/orbit_falloff_cap_gate.gd      # 3c-b2
$GODOT_BIN --headless --path . --script res://tests/elementalist_kit_test.gd       # orbit регрессия
$GODOT_BIN --headless --path . --script res://tests/global_damage_balance_smoke_test.gd
```
Валидация / калибровочная полоса: живой v3'''-пересъём CSV, class-trio after
(elementalist/chemist), расширенный runaway-гейт на fan-out оружия, матрица возвышений.
