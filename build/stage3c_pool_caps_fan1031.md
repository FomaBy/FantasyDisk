# FAN-1031 Stage 3c(a) — пул-канал data-driven кап + завершение S3 restore_potion

Автор: Claude (headless-полоса), 2026-07-13. Ветка off `agent/claude/53f2a056` @ 346c0d21
(v3 CSV). Вход: план FAN-1030 §2.1/§2.2/§3, v3-находка интерактивной полосы
(`restore_potion 20t 68.9k→52.4k, −24% вместо −72%`; коммит 346c0d21).

Реализован **блокирующий подпакет 3c(a)** — системный кап пул-канала, который план и
координатор требуют закрыть ДО пер-классового numeric (пункт «(а) распространить
data-driven капы на leaves_pool-ветку и pool-тики → (б) status fan-out → (в) только потом
numeric»). Это прямой аналог того, как 3a (S1) закрывал прямой AoE ДО чисел.

## Диагноз: почему S1 (3a) дал restore_potion только −24%

S1 сделал per-weapon кап ТОЛЬКО для прямого AoE-взрыва
(`_damage_aoe_projectile_explosion`, ветка без `leaves_pool`). Но у периодики есть ещё
ТРИ throughput-канала, которые S1 не трогал — они были на КОНСТАНТАХ кода:

| канал | функция | было (константы) |
| --- | --- | --- |
| тик лужи | `_damage_enemies_in_pool` | `POOL_FULL_TARGETS=1 / POOL_TARGET_DIMINISH=1.5` |
| прямая ветка лужи | `_damage_aoe_projectile_explosion` (`if leaves_pool`) | `POOL_PROJECTILE_FULL_TARGETS=1 / …DIMINISH=3.0` |
| vapor restore_potion | `_spawn_restore_vapor` | хардкод `(F=2 / D=1.5)` |

Декомпозиция restore_potion 20t (в живом v3 главным остаточным хвостом был **vapor** —
он капнут лишь до 1.5, а не до сустейн-ниши зелья 4.0), поэтому −24%, а не −72%.

## Реализовано (механизм, детерминированно, лёгкий гейт)

1. **Per-weapon пул-кап** `ClassWeapon.pool_full_targets / pool_target_diminish`
   (`class_weapon.gd`). Сентинел `<0` → per-channel default (тик лужи → `POOL_*`; прямая
   ветка → `POOL_PROJECTILE_*`). Нулевое изменение поведения без override — тот же
   сентинел-контракт, что и S1. Проведён через `_damage_enemies_in_pool` и leaves_pool-ветку.
2. **S3 завершение — restore_vapor.** Артефактный vapor теперь наследует сустейн-нишевый
   кап зелья (`aoe_full_targets/aoe_target_diminish` = 1/4.0), а не хардкод `(2/1.5)`.
   rank0 (solo/дуо-хил) не тронут — лечение сохранено точно.
3. **acid_flask пул-тик** `pool_target_diminish: 3.0` (был default 1.5) — первичное
   сужение по образцу S1: ядро пака полный тик, хвост душится (area-denial). Персистентные
   `acid_charge` (status fan-out) НЕ тронуты — это канал 3c(b).

**Гейт (лёгкий, детерминированный, единицы секунд):** `tests/pool_target_cap_gate.gd` —
override режет rank1 круче default'а (пул-тик и leaves_pool-ветка), сентинел-контроль =
прежний default (нулевое изменение), CONST-guard дефолтов, anti-silent-retune на реальных
конфигах (acid_flask 3.0; restore_potion 1/4.0 → vapor наследует). PASS.

**Регрессия (все PASS):** `doctor_kit_test`, `boss_hazard_cap_gate`,
`class_budget_profiles_integrity`, `damage_type_isolation`, `content_registry_consistency`,
`progression_data_api_surface`, `contact_damage_softcap_test`,
`global_damage_balance_smoke` (51 пара, worst CCT **+21% — БЕЗ изменений**: капы
рантаймовые, ортогональны формульной бюджет-модели).

## After-метрики (детерминированные throughput-дельты; живой 20t — за интерактивной полосой)

Диминиш-формула детерминирована (`factor = 1/(1+(rank−full+1)·D)`), поэтому per-channel
дельта суммарного 20t-throughput = `Σfactor_new / Σfactor_old` — ТОЧНА при неизменном
per-hit amount. Живой v3′-пересъём (полный CSV, тяжёлый harness) — за интерактивной
полосой (headless-лейн не тянет 480-кадровые DPS-симы в тайм-аутах, как и в 3a).

| канал (оружие) | было → стало | Σfactor(20t) old → new | Δ throughput 20t |
| --- | --- | --- | --- |
| restore_vapor (restore_potion) | F2/D1.5 → F1/D4.0 | 3.848 → 1.803 (×2 тика) | **−53%** |
| пул-тик (acid_flask) | D1.5 → D3.0 (F=1) | 2.882 → 2.040 (на лужу) | **−29%** |
| прямой AoE-взрыв (restore_potion, 3a) | F5/D2 → F1/D4 | 6.368 → 1.803 | −72% (напоминание) |

restore_potion: главный остаточный хвост v3 (vapor) срезан −53%; вместе с 3a-капом
основного взрыва зелье уходит из топ-AoE к сустейн-нише (S3-цель). Точный 20t после — за
v3′-пересъёмом. acid_flask пул-тик −29% — ПЕРВИЧНОЕ сужение; величина донастраивается
против v3′ (16× медианы у колбы дают не только пул-тик, но и multi-pool ×6 и acid_charge —
см. 3c-b/3c-c).

## Handoff: 3c(b) status fan-out, 3c(c) numeric, 3b дно-киты

### Критично: не всякий offender ловится диминиш-рычагом (урок restore_potion, обобщённый)

Диминиш-поля (`aoe_*`/`pool_*`) работают ТОЛЬКО на капающих путях
(`_damage_aoe_projectile_explosion`, `_damage_enemies_in_pool`,
`_damage_enemies_in_circle_capped`). Часть offender'ов льёт урон через НЕкапающие каналы —
там рычаг = НО-ОП, нужен либо перенос канала на capped-путь, либо numeric per-hit. Перед
применением любого диминиш-рычага **проверять фактический executor** (как выявили у
restore_vapor). Псевдонимы плана ≠ code weapon_id — карта ниже.

| план-алиас | code weapon_id | attack_mode | канал урона (проверено/оценка) | рычаг |
| --- | --- | --- | --- | --- |
| chemist/blast_powder 107× | `blast_powder` | aoe_projectile | прямой `_damage_aoe_projectile_explosion` (без leaves_pool) | S1 `aoe_*` **ловит** + numeric (диминиш даёт ≤×4, per-hit раздут) |
| chemist/acid_flask 16× | `acid_flask` | aoe_projectile+pool | пул-тик ×6 луж + `acid_charge` status | пул-тик ✓(3c-a); **charges = 3c-b**; multi-pool cap |
| elementalist/orb_ring 44× | `elemental_orbit` | elemental_orbit | custom executor `_fire_elemental_orbit` — верифицировать | вероятно numeric/новый cap |
| biologist/spore_lens 25× | `bio_spore_bloom` | bio_spore_bloom | `_bio_spore_pulse` (пульсы) — верифицировать | верифицировать канал |
| dark_mage/cursed_skull 21× | `cursed_skull` | skull_curse_burn | `_fire_curse` → `_damage_enemies_in_circle_falloff` (**НЕ капается**) + DoT | numeric ИЛИ перенос falloff→capped |
| biologist/symbiote_seed 15× | `bio_symbiote_web` | bio_symbiote_web | `_germinate_symbiote_seed` — верифицировать | верифицировать |
| ranger/hunter_trap 10× | `hunter_trap` | trap | `_deploy_hunter_trap` (bleed@толпа, pool_tick 0.20) | S1-кап bleed / pool_* если пул-путь |
| biologist/sample_injector 9× | `bio_sample_dart` | bio_sample_dart | `_enemies_in_corridor`+`_damage_enemy` (**НЕ капается**)+falloff tip | numeric per-hit |
| druid/summon_amulet 8× | `summon_amulet` | (druid summon) | вороны/амулет — druid кит-перестройка | mechanic (3c druid) |
| elementalist/prism_focus 4× | `prism_rift` | prism_rift | `_resolve_prism_rift` — верифицировать | numeric доводка |
| dark_mage/dark_book 4× | `dark_book` | dark_mirror_blast | `_damage_dark_mirror_explosion(…, AOE_PROJECTILE_*)` (**хардкод-константы**) | добавить per-weapon override ИЛИ numeric |

### 3c(b) status fan-out (не начато)

`acid_charge` (acid_flask), DoT-заряды cursed_skull/spore — персистентные ПЕР-цель статусы
(`StatusEffects.apply_status_from`), тикают независимо от оружия. Кап «суммы по толпе»
требует, чтобы урон тика статуса масштабировался по числу носителей ЭТОГО оружия — это
кросс-каттинг в `StatusEffects`/тик-пайплайн (риск-нагруженно, нужен свой лёгкий гейт).
Альтернатива по образцу существующих капов: кап ЧИСЛА одновременных носителей на оружие
(как `MAX_ACTIVE_DAMAGE_POOLS=6` для луж) — дешевле и детерминированно гейтится. Решение
по подходу — за калибровочной полосой с v3′.

### 3c(c) numeric (против v3′) и 3b дно-киты (mechanic-first) — не начаты

Требуют живого v3′-пересъёма (per-hit величины). Порядок и коридоры — план §2.2. Слепой
numeric без пересъёма = риск «silent retune» (запрет issue) — поэтому headless-лейн его не
делает; отдаёт механизм + верифицированную карту каналов калибровочной полосе.

## Команды

```
GODOT_BIN=~/Downloads/Godot.app/Contents/MacOS/Godot
$GODOT_BIN --headless --path . --import                                  # один раз на свежем checkout
$GODOT_BIN --headless --path . --script res://tests/pool_target_cap_gate.gd   # 3c-a
$GODOT_BIN --headless --path . --script res://tests/doctor_kit_test.gd        # restore/vapor регрессия
```
Stage 4 / калибровочная полоса: живой v3′-пересъём CSV, расширенный `pool_dot_runaway_gate`
на все периодические оружия, class-trio after, ascension-матрица.
