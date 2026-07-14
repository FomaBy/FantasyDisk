# FAN-1031 Stage 3c(b) — STATUS fan-out data-driven кап

Автор: Claude (headless-полоса), 2026-07-13. Ветка off `agent/claude/53f2a056` @ `280ab1c2`
(v3' CSV). Вход: план FAN-1030 §2.1(в)/§2.2, координатор-приоритет («3c-(b) статусные
fan-out капы — последний механизм; без него numeric по верхам бессмыслен»), карта каналов
`build/stage3c_pool_caps_fan1031.md`, живой v3' CSV (`build/character_balance_dps.csv`).

Реализован **ТРЕТИЙ и последний throughput-канал периодики** — крауд-раздача периодических
СТАТУСОВ. S1 (3a) закрыл прямой AoE-взрыв, 3c(a) — пул-канал (тик лужи + leaves_pool). Оставался
канал, который в живом v3' держал верхи crowd-runaway.

## Диагноз: крауд-DoT как некапнутый fan-out

`skull_curse` (Тёмный маг) и `bio_infection` (Биолог) применяются **на КАЖДОГО врага в зоне
полным per-target тиком** — на 20 целях это ×N throughput без всякого диминиша. v3'
(`lvl20_ideal`, медиана 20t = 4574):

| оружие (weapon_id) | 1t | 5t | 20t | 20t/медиана | 20t/1t | канал |
| --- | --- | --- | --- | --- | --- | --- |
| dark_mage `cursed_skull` | 270 | 1315 | **96 918** | ≈21× | ≈359× | чистый крауд-DoT (`_apply_skull_curse_zone`) |
| biologist `biologist_spore_lens` | 293 | 1587 | **114 519** | ≈25× | ≈391× | ring-урон + крауд-DoT (`_bio_spore_pulse`) |
| biologist `biologist_symbiote_seed` | 173 | 804 | **69 065** | ≈15× | ≈400× | seed-урон + крауд-DoT (`_germinate_symbiote_seed`) |

Ratio 20t/1t ≈ ×360-400 при 20 целях = DoT блэнкетит всю толпу и все носители одновременно
соакают тик. Это ровно тот fan-out, что диминиш-рычаг лечит геометрически (без per-hit).

## Реализовано (механизм, детерминированно, лёгкий гейт)

1. **Per-weapon поля** `ClassWeapon.status_full_targets / status_target_diminish`
   (`class_weapon.gd`). Сентинел `<0` → `STATUS_FANOUT_FULL_TARGETS=4 /
   STATUS_FANOUT_TARGET_DIMINISH=0.0`. Дефолтный diminish `0.0` → `factor==1` для ВСЕХ
   рангов → **нулевое изменение поведения без override** (тот же сентинел-контракт, что S1/пул).
2. **Helper** `_status_fanout_factor(rank)` — `factor = 1/(1+(rank−full+1)·D)` для `rank≥full`,
   иначе `1.0`. Идентична формуле `_damage_enemies_in_circle_capped` / S1 / пул-капа (единый
   контракт диминиша толпы). `_status_fanout_order(origin, enemies)` — дистанционная сортировка
   в дубликате (порядок вызывающего для constellation-логики не тревожится).
3. **Проведён в 4 крауд-сайта** (ранг = дистанция от центра каста):
   - `_apply_skull_curse_zone` — тик `skull_curse` масштабируется per-target; ult-фид
     `on_curse_applied` (база×count) НЕ тронут — экономика ульты стабильна.
   - `_bio_spore_pulse` и `_germinate_symbiote_seed` — `_apply_bio_infection(enemy, owner,
     fanout_factor)` (новый опциональный параметр, дефолт `1.0`); `linked_targets`/constellation
     читают исходный порядок — zero-collateral. Одиночная инфекция `bio_sample_dart` (tip) —
     `factor 1.0`, без изменений.
   - `_apply_pool_contact_statuses` — сила тика `acid_charge` per-rank; кап ЧИСЛА зарядов
     (`pool_charge_cap`) и детонация по стакам (≥5) не тронуты.

### Первичные капы (`status_full_targets=4, status_target_diminish=1.0`)

`cursed_skull`, `biologist_spore_lens`, `biologist_symbiote_seed` (`progression_data_weapons.gd`).
Выбор: ближние 4 носителя прогорают полным тиком (identity зоны + пак 1t/5t целы), дальний хвост
20-толпы душится. Детерминированная дельта суммарного throughput DoT-канала (диминиш —
чистая функция ранга, не per-hit):

| targets | Σfactor(new) | Σfactor(old = N) | Δ DoT-канал |
| --- | --- | --- | --- |
| 1t | 1.00 | 1 | **0%** |
| 5t | 4.50 | 5 | **−10%** |
| 20t | 6.44 | 20 | **−67.8% (≈×3.1)** |

**cursed_skull — чистый DoT** → −67.8% это тесная проекция 20t: `96.9k → ~31k` (21×→~7× медианы).
**bio-оружия — смешанный канал** (споровые кольца / seed-impact дают ПРЯМОЙ урон, кап его НЕ
трогает) → измеренный 20t-срез будет МЕНЬШЕ −68% (только DoT-доля). Это осознанно — урок
restore_potion (3c-a проекция −72% → живой −24% из-за некапнутых каналов). Точный live 20t —
за v3'-пересъёмом.

acid_flask **НЕ переопределён**: рычаг проведён, но заряды уже пул-капнуты в 3c-a — величину
charge-fanout калибрует v3' (иначе тройной кап на одном оружии = риск over-nerf).

## Гейт (новый, лёгкий, детерминированный)

`tests/status_fanout_cap_gate.gd` — sanity-probe компиляции; helper override `4/1.0`
(rank0-3=1.0, rank4=0.5, rank5=1/3, rank6=1/4); сентинел-контроль (factor 1.0 всем рангам);
**интеграция** `_apply_skull_curse_zone` на 6 ранжированных (снапшот `dot_damage` режет хвост
по формуле, ядро полное) + A/B-контроль (тот же кит без status-полей → все полный тик);
`bio_infection` fanout_factor масштабирует применённый тик; реальные конфиги (три оружия =4/1.0;
acid_flask = сентинел); CONST-guard дефолта no-op. **PASS.**

**Регрессия (все PASS, локальный Godot 4.7):** `dark_mage_kit_test`, `biologist_kit_test`
(оба гоняют реальные крауд-сайты — малый пак rank<4 = без изменений), `chemist_kit_test`
(acid charges), `druid_kit_test` (пулы), `pool_target_cap_gate`, `doctor_kit_test`,
`boss_hazard_cap_gate`, `class_budget_profiles_integrity`, `damage_type_isolation`,
`content_registry_consistency`, `progression_data_api_surface`, `contact_damage_softcap`,
`status_effects_aura`, `global_damage_balance_smoke` (51 пара, worst CCT **+21% — БЕЗ
изменений**: кап рантаймовый, ортогонален формульной бюджет-модели). Гейтов не ослаблял.

## Handoff: 3c(c) numeric + 3b дно-киты + доводка величин

1. **Живой v3'-пересъём (за интерактивной полосой)** — подтвердить направление 20t трёх
   оффендеров; для bio-оружий разложить измеренный срез на DoT-долю (капнута) и прямую (нет).
   Тяжёлый DPS-харнес headless-лейн не тянет в тайм-аутах (как в 3a/3c-a).
2. **Доводка `status_target_diminish`** против живого 20t: если после `D=1.0` bio-оружия ещё
   выше коридора из-за ПРЯМОГО канала — тюнить их ring/seed-numeric (3c-c), а не давить диминиш
   (диминиш бьёт только DoT; макс ≈×4 без потери identity).
3. **3c(c) numeric верхов** (chemist/elementalist/biologist/dark_mage/druid-амулет к total
   ≤1.15, по СРЕДНЕМУ 2 прогонов) — теперь механизм полон (прямой AoE + пул + status), numeric
   осмыслен. Топ по 20t вне status-канала: `blast_powder` 494.9k (прямой AoE — S1 `aoe_*` +
   per-hit), `elemental_orbit` 197.8k (custom executor — верифицировать канал), `summon_amulet`
   110.4k (druid summon — mechanic).
4. **acid_charge** — если v3' покажет остаточный charge-runaway, задать `acid_flask
   status_full_targets/status_target_diminish` (рычаг готов); стартовая точка мягче `4/1.0`
   (оружие уже пул-капнуто).
5. **3b дно-киты** (guitarist/sniper/druid briar-raven) — mechanic-first, план §2.2, против v3'.

## Ветка / коммиты

Off `280ab1c2` (v3'). Файлы: `scripts/class_weapon.gd` (поля + helper + 4 сайта),
`scripts/progression_data_weapons.gd` (3 override), `tests/status_fanout_cap_gate.gd` (+`.uid`),
`docs/design/systems/progression_balance.md` (no-silent-retune лог), этот handoff.

## Команды

```
GODOT_BIN=~/Downloads/Godot.app/Contents/MacOS/Godot
$GODOT_BIN --headless --path . --import                                          # свежий checkout
$GODOT_BIN --headless --path . --script res://tests/status_fanout_cap_gate.gd    # 3c-b
$GODOT_BIN --headless --path . --script res://tests/dark_mage_kit_test.gd        # skull_curse регрессия
$GODOT_BIN --headless --path . --script res://tests/biologist_kit_test.gd        # bio_infection регрессия
```
Валидация / калибровочная полоса: живой v3'-пересъём CSV, class-trio after (dark_mage/biologist),
расширенный `pool_dot_runaway_gate` на крауд-DoT оружия, ascension-матрица.
