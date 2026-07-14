# Character Balance — comfort-нормированная полоса (SCRUM-544)

Сгенерировано `tools/character_balance_csv.gd`. Допуск полосы: ±20% от медианы.
Нормировка: `comfort_normalized = measured_dps / comfort_slice_weight[class][slice]` (см. `progression_data_balance.gd` COMFORT_BAND_SLICE_WEIGHTS / COMFORT_BAND_SLICE_OVERRIDES). Полоса НЕ плоская: вес зависит от среза (ось вовлечённости single-target↔crowd).

## Срез `ideal_1` — FAIL

- медиана нормированного DPS: **318.2**, полоса [254.6 .. 381.9]
- факт: min **0.0**, max **3185.8**, разброс **3185791.1x** (цель ≤ 1.50x)
- нарушений полосы: **38 / 51**

| класс/оружие | raw DPS | comfort | norm DPS | ×медиана |
|---|--:|--:|--:|--:|
| doctor/bone_saw | 1010 | 0.32 | 3186 | 10.01x |
| druid/summon_amulet | 1556 | 0.86 | 1812 | 5.69x |
| engineer/engineer_sentry_wrench | 1002 | 0.73 | 1367 | 4.29x |
| chemist/blast_powder | 1254 | 0.99 | 1261 | 3.96x |
| elementalist/elementalist_prism_focus | 1140 | 1.02 | 1117 | 3.51x |
| assassin/venom_wire | 397 | 0.44 | 899 | 2.82x |
| soldier/soldier_bayonet | 829 | 0.98 | 844 | 2.65x |
| dark_mage/dark_book | 753 | 0.93 | 813 | 2.55x |
| thief/thief_shadow_cloak | 763 | 0.99 | 771 | 2.42x |
| doctor/plague_syringe | 368 | 0.49 | 743 | 2.33x |
| dark_mage/dark_wand | 515 | 0.93 | 556 | 1.75x |
| berserk/axe | 592 | 1.14 | 520 | 1.64x |
| biologist/biologist_sample_injector | 442 | 1.03 | 429 | 1.35x |
| priest/priest_reliquary | 423 | 1.00 | 423 | 1.33x |
| soldier/soldier_rifle | 391 | 0.98 | 398 | 1.25x |
| soldier/soldier_grenade | 390 | 0.98 | 398 | 1.25x |
| assassin/chakrams | 648 | 1.65 | 394 | 1.24x |
| biologist/biologist_spore_lens | 294 | 0.75 | 390 | 1.23x |
| ranger/storm_longbow | 356 | 1.47 | 243 | 0.76x |
| assassin/shadow_daggers | 375 | 1.65 | 228 | 0.72x |
| sniper/sniper_shatter_rounds | 257 | 1.17 | 219 | 0.69x |
| chemist/acid_flask | 218 | 0.99 | 219 | 0.69x |
| knight/long_spear | 205 | 0.96 | 214 | 0.67x |
| doctor/restore_potion | 295 | 1.49 | 198 | 0.62x |
| thief/thief_coin_pouch | 191 | 0.99 | 194 | 0.61x |
| druid/briar_staff | 159 | 0.86 | 185 | 0.58x |
| knight/holy_flail | 166 | 0.96 | 174 | 0.55x |
| priest/priest_censer | 158 | 1.00 | 158 | 0.50x |
| priest/priest_chime | 156 | 1.00 | 156 | 0.49x |
| biologist/biologist_symbiote_seed | 156 | 1.03 | 152 | 0.48x |
| guitarist/electric_guitar | 141 | 1.04 | 136 | 0.43x |
| robot/robot_magnetic_anchor | 135 | 1.00 | 134 | 0.42x |
| ranger/hunter_trap | 168 | 1.47 | 114 | 0.36x |
| sniper/sniper_spotter_scope | 126 | 1.17 | 108 | 0.34x |
| guitarist/bass_guitar | 98 | 1.04 | 94 | 0.30x |
| guitarist/sound_amp | 97 | 1.04 | 93 | 0.29x |
| druid/raven_totem | 66 | 1.02 | 64 | 0.20x |
| engineer/engineer_pressure_mines | 0 | 0.96 | 0 | 0.00x |

## Срез `ideal_5` — FAIL

- медиана нормированного DPS: **1100.1**, полоса [880.1 .. 1320.1]
- факт: min **0.0**, max **10719.3**, разброс **10719330.8x** (цель ≤ 1.50x)
- нарушений полосы: **37 / 51**

| класс/оружие | raw DPS | comfort | norm DPS | ×медиана |
|---|--:|--:|--:|--:|
| chemist/blast_powder | 16175 | 1.51 | 10719 | 9.74x |
| druid/summon_amulet | 8268 | 0.87 | 9492 | 8.63x |
| chemist/acid_flask | 14099 | 1.51 | 9343 | 8.49x |
| doctor/bone_saw | 2000 | 0.32 | 6210 | 5.65x |
| elementalist/elementalist_prism_focus | 4145 | 1.13 | 3662 | 3.33x |
| dark_mage/dark_book | 4301 | 1.46 | 2952 | 2.68x |
| ranger/moon_crossbow | 1836 | 0.79 | 2318 | 2.11x |
| dark_mage/dark_wand | 3341 | 1.46 | 2293 | 2.08x |
| priest/priest_reliquary | 2203 | 1.03 | 2138 | 1.94x |
| assassin/venom_wire | 498 | 0.24 | 2059 | 1.87x |
| elementalist/elementalist_orb_ring | 2314 | 1.13 | 2044 | 1.86x |
| berserk/hammer | 1967 | 1.15 | 1706 | 1.55x |
| soldier/soldier_grenade | 1664 | 0.99 | 1673 | 1.52x |
| berserk/axe | 1922 | 1.15 | 1667 | 1.52x |
| thief/thief_smoke_bomb | 1660 | 1.00 | 1660 | 1.51x |
| elementalist/elementalist_meteor_core | 1679 | 1.13 | 1483 | 1.35x |
| robot/robot_reactor_core | 1455 | 1.00 | 1456 | 1.32x |
| engineer/engineer_sentry_wrench | 1294 | 0.91 | 1423 | 1.29x |
| biologist/biologist_spore_lens | 1579 | 1.11 | 1419 | 1.29x |
| priest/priest_censer | 906 | 1.03 | 880 | 0.80x |
| thief/thief_shadow_cloak | 844 | 1.00 | 844 | 0.77x |
| assassin/chakrams | 661 | 0.90 | 735 | 0.67x |
| druid/briar_staff | 633 | 0.87 | 727 | 0.66x |
| biologist/biologist_sample_injector | 862 | 1.33 | 646 | 0.59x |
| doctor/plague_syringe | 314 | 0.52 | 606 | 0.55x |
| biologist/biologist_symbiote_seed | 781 | 1.33 | 585 | 0.53x |
| doctor/restore_potion | 774 | 1.49 | 518 | 0.47x |
| sniper/sniper_spotter_scope | 420 | 0.82 | 514 | 0.47x |
| ranger/storm_longbow | 372 | 0.79 | 469 | 0.43x |
| knight/long_spear | 384 | 0.93 | 415 | 0.38x |
| guitarist/sound_amp | 563 | 1.37 | 410 | 0.37x |
| guitarist/bass_guitar | 554 | 1.37 | 403 | 0.37x |
| knight/tower_shield | 325 | 0.93 | 351 | 0.32x |
| guitarist/electric_guitar | 426 | 1.37 | 310 | 0.28x |
| berserk/sword | 169 | 0.74 | 227 | 0.21x |
| druid/raven_totem | 202 | 1.13 | 179 | 0.16x |
| engineer/engineer_pressure_mines | 0 | 1.11 | 0 | 0.00x |

## Срез `ideal_20` — FAIL

- медиана нормированного DPS: **5006.1**, полоса [4004.9 .. 6007.4]
- факт: min **402.8**, max **376849.3**, разброс **935.5x** (цель ≤ 1.50x)
- нарушений полосы: **41 / 51**

| класс/оружие | raw DPS | comfort | norm DPS | ×медиана |
|---|--:|--:|--:|--:|
| chemist/blast_powder | 575449 | 1.53 | 376849 | 75.28x |
| elementalist/elementalist_orb_ring | 198303 | 1.14 | 173342 | 34.63x |
| biologist/biologist_spore_lens | 114810 | 1.31 | 87508 | 17.48x |
| dark_mage/cursed_skull | 100019 | 1.16 | 85927 | 17.16x |
| druid/summon_amulet | 52969 | 0.84 | 62834 | 12.55x |
| ranger/hunter_trap | 43195 | 0.76 | 56612 | 11.31x |
| biologist/biologist_symbiote_seed | 68042 | 1.31 | 51861 | 10.36x |
| chemist/acid_flask | 73390 | 1.53 | 48062 | 9.60x |
| doctor/restore_potion | 52373 | 1.32 | 39676 | 7.93x |
| biologist/biologist_sample_injector | 43078 | 1.31 | 32834 | 6.56x |
| doctor/bone_saw | 7451 | 0.31 | 24271 | 4.85x |
| elementalist/elementalist_prism_focus | 24352 | 1.14 | 21287 | 4.25x |
| priest/priest_reliquary | 14705 | 1.05 | 13978 | 2.79x |
| dark_mage/dark_book | 14228 | 1.39 | 10243 | 2.05x |
| soldier/soldier_grenade | 9364 | 0.97 | 9653 | 1.93x |
| berserk/axe | 10215 | 1.10 | 9295 | 1.86x |
| engineer/engineer_pressure_mines | 8753 | 1.05 | 8352 | 1.67x |
| thief/thief_smoke_bomb | 7979 | 0.97 | 8201 | 1.64x |
| elementalist/elementalist_meteor_core | 8742 | 1.14 | 7642 | 1.53x |
| knight/holy_flail | 6449 | 0.88 | 7312 | 1.46x |
| berserk/hammer | 3425 | 1.10 | 3116 | 0.62x |
| guitarist/sound_amp | 3555 | 1.14 | 3113 | 0.62x |
| ranger/moon_crossbow | 2258 | 0.76 | 2959 | 0.59x |
| sniper/sniper_spotter_scope | 1925 | 0.80 | 2421 | 0.48x |
| guitarist/bass_guitar | 3296 | 1.40 | 2348 | 0.47x |
| knight/tower_shield | 2052 | 0.88 | 2326 | 0.46x |
| sniper/sniper_deadeye_rifle | 1778 | 0.80 | 2236 | 0.45x |
| ranger/storm_longbow | 1692 | 0.76 | 2218 | 0.44x |
| assassin/venom_wire | 498 | 0.23 | 2167 | 0.43x |
| engineer/engineer_repair_drone | 1980 | 1.05 | 1889 | 0.38x |
| thief/thief_shadow_cloak | 1801 | 0.97 | 1851 | 0.37x |
| engineer/engineer_sentry_wrench | 1490 | 0.85 | 1755 | 0.35x |
| berserk/sword | 1202 | 0.71 | 1697 | 0.34x |
| assassin/chakrams | 1438 | 0.86 | 1676 | 0.33x |
| knight/long_spear | 1270 | 0.88 | 1440 | 0.29x |
| thief/thief_coin_pouch | 1259 | 0.97 | 1294 | 0.26x |
| assassin/shadow_daggers | 1036 | 0.86 | 1207 | 0.24x |
| sniper/sniper_shatter_rounds | 867 | 0.80 | 1091 | 0.22x |
| guitarist/electric_guitar | 1321 | 1.40 | 941 | 0.19x |
| doctor/plague_syringe | 341 | 0.46 | 743 | 0.15x |
| druid/raven_totem | 425 | 1.06 | 403 | 0.08x |

---

**Итог полосы: ПОЛОСА НЕ ВЫДЕРЖАНА — требуется тюнинг**