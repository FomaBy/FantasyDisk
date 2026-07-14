# FAN-1031 Stage 3a — системные капы: реализация и предварительные after-метрики

Автор: Claude (headless-полоса), 2026-07-13. Ветка: `agent/claude/53f2a056`.
Вход: план FAN-1030 (`docs/design/systems/balance_plan_fan1030.md` §2.1), baseline v2
FAN-1029 (`build/character_balance_dps.csv`, коммит 5bf8a017). Реализован **пакет 3a**
(системные правки S1/S2/S3) — блокер, который план требует закрыть ДО пер-классовых
чисел («только он делает пер-классовые числа осмысленными»). Пакеты 3b/3c/3d — handoff
ниже (требуют v3-пересъёма живого CSV).

## Ограничение окружения (важно для валидации)

В этой headless-полосе живой Godot доступен, но **тяжёлые DPS-харнесы нежизнеспособны
в рамках тайм-аутов инструмента**: полный live CSV (51 пара) ≈16 мин, а один
`pool_dot_runaway_gate` (lvl20-ideal, 480 кадров, накопление луж/VFX) шёл >16 мин при
100% CPU и был снят. Поэтому:

- Валидация 3a выполнена **лёгкими детерминированными гейтами** (клэмп/геометрия, единичный
  fire — единицы секунд), а не 480-кадровым DPS-пересъёмом.
- **After-метрики crowd (S1/S3) — аналитические проекции**: диминиш детерминирован
  (`_damage_enemies_in_circle_capped`: `factor = 1/(1+(rank−full+1)·D)`), поэтому при
  неизменном per-hit amount `20t_new/20t_old = Σfactor_new/Σfactor_old`. Живой 20t-пересъём
  (v3) — задача Stage 4 (FAN-1032 и так перезапускает CSV/harness).

## Реализовано (коммиты)

| # | Правка | Файлы | Гейт | Статус |
| --- | --- | --- | --- | --- |
| **S2** | Кап урона зон/сламов/хазардов/укусов босса ≤80% max HP за тик (11 сайтов `boss.gd` → `enemy._hazard_hit`) | `progression_data_balance.gd`, `progression_data.gd`, `enemy.gd`, `boss.gd` | `tests/boss_hazard_cap_gate.gd` | PASS 1.3s (e450ccef) |
| **S1** | Data-driven кап прямого AoE (`ClassWeapon.aoe_full_targets/aoe_target_diminish`, сентинел = общий default) — механизм | `class_weapon.gd` | A/B в doctor_kit_test | PASS (2bf1458a) |
| **S3** | `doctor/restore_potion` → сустейн: `aoe_full_targets=1, aoe_target_diminish=4.0` | `progression_data_weapons.gd` | `doctor_kit_test._test_restore_potion_splash_cap` | PASS 1.7s (2bf1458a) |

Регрессия (все PASS, лёгкие): `class_budget_profiles_integrity`, `global_damage_balance_smoke`
(51 пара, худший CCT +21% — БЕЗ изменений, кап рантаймовый и ортогонален формульной
бюджет-модели), `damage_type_isolation`, `content_registry_consistency`,
`progression_data_api_surface`, `contact_damage_softcap_test`.

## After-метрики

### S2 — ваншот-политика (DoD-критично)

| | before (baseline v2) | after |
| --- | --- | --- |
| Худший hazard/slam за тик | без капа → фаза-4 A5 ≈164 урона | ≤ 80% текущего max HP |
| Ваншот full-HP одним тиком | **все 17 классов** | 0 классов (гейт E2E: full-HP 80 → drop 64, выжил) |

Провал доджа по-прежнему почти смертелен (телеграфы честные, combat-feel этап C), но
full-HP герой не удаляется одним неравным тиком. Это единственный реалистичный путь к
DoD «каждый класс проходит A5» без раздувания HP хрупких в ~3× (см. FAN-1029 §4).

### S3 — restore_potion (проекция при неизменном per-hit amount)

| срез | before v2 | after (проекция) | Δ |
| --- | --- | --- | --- |
| 20t (crowd) | 68 884 (15.1× медианы 4574) | ~19 500 (4.3×) | −72% |
| 5t (aoe) | 1 410 | ~408 | −71% |
| 1t (solo) | 243 | 243 | 0% (solo-хил сохранён точно) |

Роль восстановлена: «безопасный ranged-сустейн/solo-хил», а не чистка толпы. Сустейн не
страдает — хил (16% нанесённого) всё равно упирается в drain-budget 7/с. Остаточные 4.3×
медианы — часть ОБЩЕГО crowd-runaway (раздутый per-hit из мультипликативного билд-стека),
который душится offender-тюном S1 + numeric 3c против v3, а не диминишем в одиночку.

## Handoff: 3b/3c/3d (требуют v3-пересъёма)

`build/character_balance_dps.csv` (baseline v2), медиана crowd(20t) = **4574**, целевой
потолок ≈3× = **~13.7k** (план §1.1).

### S1 offender-калибровка + 3c numeric (пакет 3c) — crowd(20t) выше потолка

| weapon (класс) | 20t before | × медианы | лечится диминишем S1? |
| --- | --- | --- | --- |
| chemist/blast_powder | 490 222 | 107× | нет (per-hit нерф обязателен: диминиш даёт ≤4×) |
| elementalist/orb_ring | 199 729 | 44× | частично + numeric |
| biologist/spore_lens | 116 310 | 25× | частично + numeric |
| dark_mage/cursed_skull | 96 749 | 21× | частично + numeric |
| chemist/acid_flask (pool) | 73 491 | 16× | pool-tick диминиш (S1 pool-ветка, не сделана) |
| biologist/symbiote_seed | 69 581 | 15× | частично + numeric |
| ranger/hunter_trap (bleed) | 46 522 | 10× | S1-кап на bleed@толпа |
| biologist/sample_injector | 42 234 | 9× | numeric |
| druid/summon_amulet | 35 639 | 8× | druid кит-перестройка (3c) |
| elementalist/prism_focus | 17 820 | 4× | numeric доводка |
| dark_mage/dark_book | 16 934 | 4× | numeric доводка |

**Ключевой вывод:** диминиш «полных целей» (S1) снижает 20t максимум ≈×4 (при F=1). Для
blast_powder (107×), orb_ring (44×) и т.д. нужен ТАКЖЕ per-hit numeric нерф (план 3c:
«chemist … aoe_norm→1.2 вниз»), т.к. per-hit amount раздут билд-стеком (RUN_DAMAGE_MULT
softcap уже 12.0, но dot/aoe-скейл всё равно множит). Порядок для 3c: применить S1
`aoe_full_targets`/`aoe_target_diminish` к прямо-AoE offender'ам (orb_ring, cursed_skull,
symbiote, prism_focus, dark_book) + добавить аналогичные pool-tick/wave-tick data-поля
(S1-ветка pool не сделана — `_damage_enemies_in_pool` пока на константах POOL_*), затем
numeric против v3 до 20t ≤ ~13.7k, синхронно с расширением `pool_dot_runaway_gate`.

### 3b mechanic-first (дно-киты) — не начаты (нужен v3 для калибровки)

`guitarist` (0.52, сатурация тюнера 2.80 ×3 оружия — raw выше сатурации + Разогрев
2%/с→4%/с), `sniper` (SOLO 0.61 нормы — shatter в честную анти-крауд нишу, deadeye
дистанц-бонус), `assassin` (crowd 0.30 — рикошет чакрама цепью), `thief` (crowd — цепь
монеты/дым частота тика), `knight` (все оси урона 0.5–0.6 — пол урона), `engineer`
(crowd + mines solo-триггер). Цели/коридоры — план §2.2.

### 3d — random-пол (S4) + перекалибровка comfort-band. Не начато.

### Doctor intra-kit (частично)

S3 снял restore_potion-выброс, но `plague_syringe` по-прежнему без AoE (341@20t, «мёртвая
AoE-ось»), поэтому intra-kit спред Доктора ещё > 2.5× (bone_saw 6736 / restore ~19.5k /
plague 341). Полный ≤2.5× требует честного многоцельного тика чумы в капе (план doctor:
«spread-механика уже есть — дать честный многоцельный тик») + v3-пересъём — пакет 3c.

## Гейты 3a — команды

```
GODOT_BIN=~/Downloads/Godot.app/Contents/MacOS/Godot
$GODOT_BIN --headless --path . --script res://tests/boss_hazard_cap_gate.gd   # S2
$GODOT_BIN --headless --path . --script res://tests/doctor_kit_test.gd        # S1+S3
```
Stage 4 обязан догнать тяжёлые гейты (в лане с бюджетом времени): расширенный
`pool_dot_runaway_gate` на все периодические оружия, живой v3-пересъём CSV,
`survivability_scenario`/ascension-матрица (S2 подтвердить по факту A5), class-trio after.
