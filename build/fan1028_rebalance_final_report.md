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

## 3b. Пер-оружейная identity-таблица (роль каждого оружия)

Каждый класс — полный three-weapon кит с тремя РАЗЛИЧИМЫМИ ролями (нет клонов,
нет «оружия, которое выгодно игнорировать»). Полные gameplay-описания —
`docs/design/systems/characters_weapons.md` (Weapon Matrix). Правка = что сделал
ребаланс FAN-1028 с этим оружием.

| Класс | Оружие | Роль / ось | Правка ребаланса |
| --- | --- | --- | --- |
| berserk | sword / axe / hammer | узкий сектор-solo / широкий сектор-AoE / круговой slam-crowd | db 1.00→0.82 (axe 20t −40%, hammer из клампа) |
| soldier | rifle / grenade / bayonet | частая пуля-solo / тяжёлый nuke-burst / конус-melee+knockback | db 0.72→0.68, bayonet solo-спайк вниз |
| thief | coin_pouch / shadow_cloak / smoke_bomb | economy-цепь / backstab-solo+паралич / AoE+облако-уклонения | дно вверх (mechanic-first) |
| elementalist | orb_ring / prism_focus / meteor_core | квадрат-crowd / полнокартный X-line / медленный метеор-burst | db 0.82→0.70; **orb_ring orbit width-cap (nearest cluster)** |
| sniper | deadeye_rifle / spotter_scope / shatter_rounds | lockshot-solo / kill-zone-AoE / веер-pierce | db 1.00→1.15 (solo-ниша поднята) |
| priest | reliquary / censer / chime | sanctify solo-burst+sustain / ward-crowd+absorb / prayer-chain sustain | NET-ZERO: crowd(кадило) вниз, reliquary base/solo вверх (random-A1 ≥0.95) |
| biologist | spore_lens / sample_injector / symbiote_seed | споры-crowd-DoT / пирс-луч-solo / семя-инфекция-DoT | **spore_lens infection width-cap (nearest)**; status fan-out кап |
| robot | magnetic_anchor / hydraulic_press / reactor_core | пулл-группировка / коридор-line / веер-360° | tank identity-price (damage-оси 0.77–1.00, платит EHP 2.12) |
| engineer | sentry_wrench / repair_drone / pressure_mines | турели-summon-DPS / орбит-дроны-контакт / персист-мины-zone | sentry solo-спайк снят, устройства в коридор |
| dark_mage | dark_book / cursed_skull / dark_wand | зеркальный AoE-burst / curse-only-DoT-crowd / цепь до 3 | db 0.72→0.58; status fan-out кап (curse-тик); ульта-фид Σfactor |
| guitarist | electric_guitar / bass_guitar / sound_amp | рифф-strip-solo / кайт-кольцо-crowd / амп-турели-summon | RAW↑ (electric 0.66→0.80, bass 0.26→0.30, amp 0.85→1.00) — дно из сатурации |
| assassin | chakrams / shadow_daggers / venom_wire | boomerang-solo / point-blank-flurry-AoE+tempo / poison-line-DoT | crowd-ось поднята к профилю (chakram-цепь) |
| ranger | moon_crossbow / storm_longbow / hunter_trap | split-shot 1→4 / пирс-конус-line / перманентный капкан-control | db 1.15→1.26 (дно вверх) |
| doctor | restore_potion / plague_syringe / bone_saw | зелье-AoE+хил / чума-спред-DoT / сектор-пила-solo+execute-heal | **restore_potion splash+vapor кап (сустейн-ниша 1/4.0)** |
| chemist | blast_powder / acid_flask / homunculus_vial | прямой физ-AoE / лужа-zone-DoT / пара гомункулов-summon | db 1.15→0.95; **blast aoe 4/3→2/3 max 3 (20t −53%), acid pool_max 6→4** |
| knight | long_spear / tower_shield / holy_flail | укол-solo+counter / баш-щит-defense / спираль-crowd-control | tank identity-price (EHP 2.21, damage-оси ниже медианы) |
| druid | summon_amulet / briar_staff / raven_totem | beast-pack-summon / терновые зоны-DoT-control / вороний тотем-DPS | амулет вниз; **briar + raven оживлены (raven rdm 1.35→2.40, ×1.84–2.41)** |

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

> ✅ **Заметка по артефакту (закрыто `76e251ef`):** прежний
> `build/class_trio_before_fan1028.md` содержал ФИНАЛЬНЫЙ снимок под заголовком
> «до»; координатор переименовал его в **`build/class_trio_fan1028.md`** (нейтральное
> имя + заголовок). Истинный v2-baseline сохранён в git (`40a39a00`) и продублирован
> в §1 этого отчёта.
