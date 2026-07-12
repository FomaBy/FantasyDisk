# Character Balance — comfort-нормированная полоса (SCRUM-544)

Сгенерировано `tools/character_balance_csv.gd`. Допуск полосы: ±20% от медианы.
Нормировка: `comfort_normalized = measured_dps / comfort_slice_weight[class][slice]` (см. `progression_data_balance.gd` COMFORT_BAND_SLICE_WEIGHTS / COMFORT_BAND_SLICE_OVERRIDES). Полоса НЕ плоская: вес зависит от среза (ось вовлечённости single-target↔crowd).

## Срез `ideal_1` — FAIL

- медиана нормированного DPS: **298.4**, полоса [238.7 .. 358.1]
- факт: min **0.0**, max **2381.7**, разброс **2381740.1x** (цель ≤ 1.50x)
- нарушений полосы: **39 / 51**

| класс/оружие | raw DPS | comfort | norm DPS | ×медиана |
|---|--:|--:|--:|--:|
| doctor/bone_saw | 755 | 0.32 | 2382 | 7.98x |
| druid/summon_amulet | 1790 | 0.86 | 2084 | 6.98x |
| engineer/engineer_sentry_wrench | 1113 | 0.73 | 1518 | 5.09x |
| assassin/venom_wire | 479 | 0.44 | 1084 | 3.63x |
| soldier/soldier_bayonet | 995 | 0.98 | 1013 | 3.39x |
| dark_mage/dark_book | 792 | 0.93 | 854 | 2.86x |
| thief/thief_shadow_cloak | 803 | 0.99 | 812 | 2.72x |
| elementalist/elementalist_prism_focus | 802 | 1.02 | 786 | 2.63x |
| doctor/plague_syringe | 368 | 0.49 | 743 | 2.49x |
| chemist/blast_powder | 710 | 0.99 | 715 | 2.39x |
| dark_mage/dark_wand | 617 | 0.93 | 666 | 2.23x |
| priest/priest_reliquary | 457 | 1.00 | 456 | 1.53x |
| berserk/axe | 479 | 1.14 | 421 | 1.41x |
| soldier/soldier_grenade | 401 | 0.98 | 409 | 1.37x |
| biologist/biologist_sample_injector | 416 | 1.03 | 404 | 1.35x |
| biologist/biologist_spore_lens | 293 | 0.75 | 389 | 1.30x |
| berserk/hammer | 435 | 1.14 | 383 | 1.28x |
| soldier/soldier_rifle | 368 | 0.98 | 375 | 1.26x |
| assassin/chakrams | 611 | 1.65 | 371 | 1.24x |
| chemist/homunculus_vial | 197 | 0.55 | 361 | 1.21x |
| thief/thief_coin_pouch | 231 | 0.99 | 233 | 0.78x |
| berserk/sword | 170 | 0.73 | 232 | 0.78x |
| chemist/acid_flask | 218 | 0.99 | 219 | 0.73x |
| sniper/sniper_shatter_rounds | 243 | 1.17 | 207 | 0.69x |
| robot/robot_magnetic_anchor | 208 | 1.00 | 207 | 0.69x |
| knight/long_spear | 183 | 0.96 | 191 | 0.64x |
| assassin/shadow_daggers | 308 | 1.65 | 187 | 0.63x |
| druid/briar_staff | 159 | 0.86 | 185 | 0.62x |
| sniper/sniper_spotter_scope | 212 | 1.17 | 181 | 0.61x |
| priest/priest_censer | 172 | 1.00 | 172 | 0.57x |
| doctor/restore_potion | 243 | 1.49 | 163 | 0.55x |
| biologist/biologist_symbiote_seed | 157 | 1.03 | 152 | 0.51x |
| guitarist/electric_guitar | 129 | 1.04 | 124 | 0.42x |
| knight/holy_flail | 117 | 0.96 | 122 | 0.41x |
| ranger/hunter_trap | 138 | 1.47 | 94 | 0.32x |
| guitarist/sound_amp | 97 | 1.04 | 93 | 0.31x |
| guitarist/bass_guitar | 92 | 1.04 | 88 | 0.30x |
| druid/raven_totem | 60 | 1.02 | 59 | 0.20x |
| engineer/engineer_pressure_mines | 0 | 0.96 | 0 | 0.00x |

## Срез `ideal_5` — FAIL

- медиана нормированного DPS: **1120.7**, полоса [896.6 .. 1344.9]
- факт: min **179.0**, max **8934.8**, разброс **49.9x** (цель ≤ 1.50x)
- нарушений полосы: **36 / 51**

| класс/оружие | raw DPS | comfort | norm DPS | ×медиана |
|---|--:|--:|--:|--:|
| chemist/acid_flask | 13483 | 1.51 | 8935 | 7.97x |
| druid/summon_amulet | 7159 | 0.87 | 8219 | 7.33x |
| chemist/blast_powder | 8826 | 1.51 | 5849 | 5.22x |
| doctor/bone_saw | 1529 | 0.32 | 4748 | 4.24x |
| dark_mage/dark_book | 4306 | 1.46 | 2956 | 2.64x |
| elementalist/elementalist_prism_focus | 2813 | 1.13 | 2485 | 2.22x |
| priest/priest_reliquary | 2415 | 1.03 | 2344 | 2.09x |
| dark_mage/dark_wand | 3275 | 1.46 | 2248 | 2.01x |
| ranger/moon_crossbow | 1613 | 0.79 | 2037 | 1.82x |
| elementalist/elementalist_orb_ring | 2291 | 1.13 | 2024 | 1.81x |
| berserk/axe | 2129 | 1.15 | 1846 | 1.65x |
| assassin/venom_wire | 432 | 0.24 | 1783 | 1.59x |
| priest/priest_chime | 1606 | 1.03 | 1560 | 1.39x |
| soldier/soldier_grenade | 1528 | 0.99 | 1536 | 1.37x |
| berserk/hammer | 1735 | 1.15 | 1505 | 1.34x |
| biologist/biologist_spore_lens | 1630 | 1.11 | 1465 | 1.31x |
| thief/thief_smoke_bomb | 1453 | 1.00 | 1453 | 1.30x |
| engineer/engineer_sentry_wrench | 1242 | 0.91 | 1366 | 1.22x |
| thief/thief_coin_pouch | 854 | 1.00 | 854 | 0.76x |
| thief/thief_shadow_cloak | 810 | 1.00 | 810 | 0.72x |
| robot/robot_hydraulic_press | 793 | 1.00 | 794 | 0.71x |
| druid/briar_staff | 683 | 0.87 | 784 | 0.70x |
| ranger/hunter_trap | 573 | 0.79 | 724 | 0.65x |
| assassin/chakrams | 637 | 0.90 | 707 | 0.63x |
| biologist/biologist_symbiote_seed | 917 | 1.33 | 687 | 0.61x |
| knight/long_spear | 627 | 0.93 | 678 | 0.61x |
| doctor/plague_syringe | 341 | 0.52 | 657 | 0.59x |
| biologist/biologist_sample_injector | 873 | 1.33 | 655 | 0.58x |
| ranger/storm_longbow | 371 | 0.79 | 469 | 0.42x |
| engineer/engineer_pressure_mines | 522 | 1.11 | 469 | 0.42x |
| guitarist/bass_guitar | 587 | 1.37 | 427 | 0.38x |
| guitarist/sound_amp | 563 | 1.37 | 410 | 0.37x |
| knight/tower_shield | 311 | 0.93 | 336 | 0.30x |
| guitarist/electric_guitar | 445 | 1.37 | 324 | 0.29x |
| berserk/sword | 203 | 0.74 | 274 | 0.24x |
| druid/raven_totem | 202 | 1.13 | 179 | 0.16x |

## Срез `ideal_20` — FAIL

- медиана нормированного DPS: **4700.6**, полоса [3760.5 .. 5640.7]
- факт: min **402.8**, max **321035.9**, разброс **796.9x** (цель ≤ 1.50x)
- нарушений полосы: **44 / 51**

| класс/оружие | raw DPS | comfort | norm DPS | ×медиана |
|---|--:|--:|--:|--:|
| chemist/blast_powder | 490222 | 1.53 | 321036 | 68.30x |
| elementalist/elementalist_orb_ring | 199729 | 1.14 | 174588 | 37.14x |
| biologist/biologist_spore_lens | 116310 | 1.31 | 88651 | 18.86x |
| dark_mage/cursed_skull | 96749 | 1.16 | 83118 | 17.68x |
| ranger/hunter_trap | 46522 | 0.76 | 60972 | 12.97x |
| biologist/biologist_symbiote_seed | 69581 | 1.31 | 53034 | 11.28x |
| doctor/restore_potion | 68884 | 1.32 | 52185 | 11.10x |
| chemist/acid_flask | 73491 | 1.53 | 48128 | 10.24x |
| druid/summon_amulet | 35639 | 0.84 | 42276 | 8.99x |
| biologist/biologist_sample_injector | 42234 | 1.31 | 32190 | 6.85x |
| doctor/bone_saw | 6737 | 0.31 | 21943 | 4.67x |
| elementalist/elementalist_prism_focus | 17820 | 1.14 | 15577 | 3.31x |
| priest/priest_reliquary | 14817 | 1.05 | 14085 | 3.00x |
| dark_mage/dark_book | 16934 | 1.39 | 12191 | 2.59x |
| berserk/axe | 9869 | 1.10 | 8980 | 1.91x |
| chemist/homunculus_vial | 7050 | 0.80 | 8801 | 1.87x |
| priest/priest_chime | 7833 | 1.05 | 7446 | 1.58x |
| soldier/soldier_grenade | 6776 | 0.97 | 6985 | 1.49x |
| engineer/engineer_pressure_mines | 6899 | 1.05 | 6583 | 1.40x |
| thief/thief_smoke_bomb | 6286 | 0.97 | 6460 | 1.37x |
| elementalist/elementalist_meteor_core | 7359 | 1.14 | 6433 | 1.37x |
| knight/holy_flail | 5605 | 0.88 | 6355 | 1.35x |
| soldier/soldier_bayonet | 5774 | 0.97 | 5952 | 1.27x |
| robot/robot_hydraulic_press | 3039 | 0.97 | 3124 | 0.66x |
| knight/long_spear | 2631 | 0.88 | 2983 | 0.63x |
| guitarist/sound_amp | 3340 | 1.14 | 2925 | 0.62x |
| berserk/hammer | 3180 | 1.10 | 2893 | 0.62x |
| guitarist/bass_guitar | 3417 | 1.40 | 2434 | 0.52x |
| sniper/sniper_deadeye_rifle | 1929 | 0.80 | 2427 | 0.52x |
| ranger/storm_longbow | 1766 | 0.76 | 2315 | 0.49x |
| berserk/sword | 1618 | 0.71 | 2285 | 0.49x |
| assassin/venom_wire | 518 | 0.23 | 2251 | 0.48x |
| ranger/moon_crossbow | 1614 | 0.76 | 2116 | 0.45x |
| assassin/chakrams | 1798 | 0.86 | 2096 | 0.45x |
| knight/tower_shield | 1752 | 0.88 | 1986 | 0.42x |
| thief/thief_shadow_cloak | 1798 | 0.97 | 1848 | 0.39x |
| engineer/engineer_sentry_wrench | 1538 | 0.85 | 1811 | 0.39x |
| engineer/engineer_repair_drone | 1790 | 1.05 | 1708 | 0.36x |
| assassin/shadow_daggers | 1190 | 0.86 | 1387 | 0.30x |
| thief/thief_coin_pouch | 1321 | 0.97 | 1358 | 0.29x |
| sniper/sniper_shatter_rounds | 959 | 0.80 | 1206 | 0.26x |
| guitarist/electric_guitar | 1566 | 1.40 | 1116 | 0.24x |
| doctor/plague_syringe | 341 | 0.46 | 743 | 0.16x |
| druid/raven_totem | 425 | 1.06 | 403 | 0.09x |

---

**Итог полосы: ПОЛОСА НЕ ВЫДЕРЖАНА — требуется тюнинг**