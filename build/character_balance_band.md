# Character Balance — comfort-нормированная полоса (SCRUM-544)

Сгенерировано `tools/character_balance_csv.gd`. Допуск полосы: ±20% от медианы.
Нормировка: `comfort_normalized = measured_dps / comfort_slice_weight[class][slice]` (см. `progression_data_balance.gd` COMFORT_BAND_SLICE_WEIGHTS / COMFORT_BAND_SLICE_OVERRIDES). Полоса НЕ плоская: вес зависит от среза (ось вовлечённости single-target↔crowd).

## Срез `ideal_1` — FAIL

- медиана нормированного DPS: **263.7**, полоса [210.9 .. 316.4]
- факт: min **0.0**, max **1736.8**, разброс **1736795.7x** (цель ≤ 1.50x)
- нарушений полосы: **33 / 51**

| класс/оружие | raw DPS | comfort | norm DPS | ×медиана |
|---|--:|--:|--:|--:|
| doctor/bone_saw | 551 | 0.32 | 1737 | 6.59x |
| druid/summon_amulet | 1305 | 0.86 | 1520 | 5.76x |
| assassin/venom_wire | 640 | 0.44 | 1448 | 5.49x |
| engineer/engineer_sentry_wrench | 945 | 0.73 | 1289 | 4.89x |
| soldier/soldier_bayonet | 949 | 0.98 | 967 | 3.67x |
| thief/thief_shadow_cloak | 662 | 0.99 | 669 | 2.54x |
| dark_mage/dark_book | 617 | 0.93 | 665 | 2.52x |
| elementalist/elementalist_prism_focus | 668 | 1.02 | 655 | 2.48x |
| dark_mage/dark_wand | 599 | 0.93 | 646 | 2.45x |
| chemist/blast_powder | 593 | 0.99 | 597 | 2.26x |
| biologist/biologist_spore_lens | 400 | 0.75 | 531 | 2.01x |
| doctor/plague_syringe | 260 | 0.49 | 525 | 1.99x |
| berserk/hammer | 399 | 1.14 | 351 | 1.33x |
| biologist/biologist_sample_injector | 339 | 1.03 | 329 | 1.25x |
| robot/robot_hydraulic_press | 205 | 1.00 | 204 | 0.77x |
| knight/long_spear | 194 | 0.96 | 202 | 0.77x |
| chemist/homunculus_vial | 109 | 0.55 | 199 | 0.75x |
| berserk/sword | 140 | 0.73 | 191 | 0.72x |
| doctor/restore_potion | 279 | 1.49 | 187 | 0.71x |
| druid/briar_staff | 157 | 0.86 | 182 | 0.69x |
| biologist/biologist_symbiote_seed | 185 | 1.03 | 179 | 0.68x |
| knight/holy_flail | 168 | 0.96 | 175 | 0.66x |
| ranger/moon_crossbow | 243 | 1.47 | 166 | 0.63x |
| priest/priest_chime | 146 | 1.00 | 146 | 0.55x |
| ranger/hunter_trap | 198 | 1.47 | 135 | 0.51x |
| sniper/sniper_shatter_rounds | 148 | 1.17 | 127 | 0.48x |
| priest/priest_censer | 126 | 1.00 | 125 | 0.48x |
| guitarist/electric_guitar | 123 | 1.04 | 118 | 0.45x |
| sniper/sniper_spotter_scope | 128 | 1.17 | 110 | 0.42x |
| guitarist/sound_amp | 88 | 1.04 | 85 | 0.32x |
| guitarist/bass_guitar | 88 | 1.04 | 84 | 0.32x |
| druid/raven_totem | 67 | 1.02 | 65 | 0.25x |
| engineer/engineer_pressure_mines | 0 | 0.96 | 0 | 0.00x |

## Срез `ideal_5` — FAIL

- медиана нормированного DPS: **1009.0**, полоса [807.2 .. 1210.8]
- факт: min **137.8**, max **9404.1**, разброс **68.3x** (цель ≤ 1.50x)
- нарушений полосы: **41 / 51**

| класс/оружие | raw DPS | comfort | norm DPS | ×медиана |
|---|--:|--:|--:|--:|
| chemist/acid_flask | 14191 | 1.51 | 9404 | 9.32x |
| druid/summon_amulet | 6205 | 0.87 | 7124 | 7.06x |
| chemist/blast_powder | 6448 | 1.51 | 4273 | 4.24x |
| doctor/bone_saw | 1237 | 0.32 | 3841 | 3.81x |
| dark_mage/dark_book | 4418 | 1.46 | 3032 | 3.00x |
| assassin/venom_wire | 613 | 0.24 | 2532 | 2.51x |
| elementalist/elementalist_prism_focus | 2432 | 1.13 | 2148 | 2.13x |
| robot/robot_reactor_core | 2066 | 1.00 | 2068 | 2.05x |
| priest/priest_reliquary | 2033 | 1.03 | 1973 | 1.96x |
| biologist/biologist_spore_lens | 2022 | 1.11 | 1817 | 1.80x |
| ranger/moon_crossbow | 1401 | 0.79 | 1769 | 1.75x |
| berserk/hammer | 1971 | 1.15 | 1710 | 1.69x |
| dark_mage/dark_wand | 2438 | 1.46 | 1674 | 1.66x |
| elementalist/elementalist_orb_ring | 1646 | 1.13 | 1454 | 1.44x |
| assassin/shadow_daggers | 1273 | 0.90 | 1415 | 1.40x |
| soldier/soldier_grenade | 1359 | 0.99 | 1365 | 1.35x |
| elementalist/elementalist_meteor_core | 1537 | 1.13 | 1357 | 1.35x |
| engineer/engineer_sentry_wrench | 1201 | 0.91 | 1321 | 1.31x |
| thief/thief_shadow_cloak | 771 | 1.00 | 771 | 0.76x |
| priest/priest_censer | 774 | 1.03 | 751 | 0.74x |
| thief/thief_coin_pouch | 751 | 1.00 | 751 | 0.74x |
| soldier/soldier_bayonet | 718 | 0.99 | 722 | 0.72x |
| ranger/hunter_trap | 570 | 0.79 | 720 | 0.71x |
| biologist/biologist_symbiote_seed | 920 | 1.33 | 690 | 0.68x |
| robot/robot_hydraulic_press | 688 | 1.00 | 688 | 0.68x |
| chemist/homunculus_vial | 573 | 0.86 | 668 | 0.66x |
| druid/briar_staff | 552 | 0.87 | 634 | 0.63x |
| sniper/sniper_shatter_rounds | 505 | 0.82 | 617 | 0.61x |
| biologist/biologist_sample_injector | 803 | 1.33 | 602 | 0.60x |
| knight/tower_shield | 532 | 0.93 | 575 | 0.57x |
| sniper/sniper_spotter_scope | 432 | 0.82 | 528 | 0.52x |
| knight/long_spear | 438 | 0.93 | 474 | 0.47x |
| assassin/chakrams | 423 | 0.90 | 470 | 0.47x |
| doctor/plague_syringe | 243 | 0.52 | 468 | 0.46x |
| ranger/storm_longbow | 369 | 0.79 | 465 | 0.46x |
| berserk/sword | 326 | 0.74 | 439 | 0.44x |
| guitarist/sound_amp | 594 | 1.37 | 432 | 0.43x |
| guitarist/bass_guitar | 570 | 1.37 | 415 | 0.41x |
| engineer/engineer_pressure_mines | 414 | 1.11 | 372 | 0.37x |
| guitarist/electric_guitar | 229 | 1.37 | 167 | 0.17x |
| druid/raven_totem | 156 | 1.13 | 138 | 0.14x |

## Срез `ideal_20` — FAIL

- медиана нормированного DPS: **3890.5**, полоса [3112.4 .. 4668.6]
- факт: min **346.5**, max **196249.9**, разброс **566.3x** (цель ≤ 1.50x)
- нарушений полосы: **44 / 51**

| класс/оружие | raw DPS | comfort | norm DPS | ×медиана |
|---|--:|--:|--:|--:|
| chemist/blast_powder | 299674 | 1.53 | 196250 | 50.44x |
| elementalist/elementalist_orb_ring | 142183 | 1.14 | 124286 | 31.95x |
| biologist/biologist_spore_lens | 145891 | 1.31 | 111197 | 28.58x |
| dark_mage/cursed_skull | 80564 | 1.16 | 69213 | 17.79x |
| doctor/restore_potion | 69754 | 1.32 | 52844 | 13.58x |
| biologist/biologist_symbiote_seed | 66517 | 1.31 | 50699 | 13.03x |
| chemist/acid_flask | 69717 | 1.53 | 45656 | 11.74x |
| biologist/biologist_sample_injector | 56594 | 1.31 | 43135 | 11.09x |
| druid/summon_amulet | 31329 | 0.84 | 37164 | 9.55x |
| engineer/engineer_pressure_mines | 17551 | 1.05 | 16747 | 4.30x |
| doctor/bone_saw | 5108 | 0.31 | 16638 | 4.28x |
| priest/priest_reliquary | 14349 | 1.05 | 13639 | 3.51x |
| elementalist/elementalist_prism_focus | 13359 | 1.14 | 11677 | 3.00x |
| soldier/soldier_grenade | 8205 | 0.97 | 8458 | 2.17x |
| dark_mage/dark_book | 11344 | 1.39 | 8167 | 2.10x |
| robot/robot_reactor_core | 7868 | 0.97 | 8086 | 2.08x |
| knight/holy_flail | 6540 | 0.88 | 7415 | 1.91x |
| elementalist/elementalist_meteor_core | 7219 | 1.14 | 6311 | 1.62x |
| thief/thief_smoke_bomb | 5979 | 0.97 | 6145 | 1.58x |
| robot/robot_magnetic_anchor | 5358 | 0.97 | 5507 | 1.42x |
| berserk/axe | 5935 | 1.10 | 5400 | 1.39x |
| dark_mage/dark_wand | 7258 | 1.39 | 5225 | 1.34x |
| soldier/soldier_bayonet | 5030 | 0.97 | 5185 | 1.33x |
| assassin/venom_wire | 710 | 0.23 | 3085 | 0.79x |
| berserk/hammer | 3357 | 1.10 | 3055 | 0.79x |
| sniper/sniper_deadeye_rifle | 2308 | 0.80 | 2903 | 0.75x |
| guitarist/sound_amp | 3145 | 1.14 | 2754 | 0.71x |
| ranger/hunter_trap | 2002 | 0.76 | 2624 | 0.67x |
| knight/tower_shield | 2228 | 0.88 | 2526 | 0.65x |
| ranger/storm_longbow | 1563 | 0.76 | 2048 | 0.53x |
| guitarist/bass_guitar | 2774 | 1.40 | 1975 | 0.51x |
| thief/thief_shadow_cloak | 1815 | 0.97 | 1865 | 0.48x |
| assassin/chakrams | 1582 | 0.86 | 1843 | 0.47x |
| engineer/engineer_repair_drone | 1908 | 1.05 | 1821 | 0.47x |
| berserk/sword | 1276 | 0.71 | 1803 | 0.46x |
| engineer/engineer_sentry_wrench | 1468 | 0.85 | 1729 | 0.44x |
| ranger/moon_crossbow | 1224 | 0.76 | 1604 | 0.41x |
| assassin/shadow_daggers | 1092 | 0.86 | 1273 | 0.33x |
| knight/long_spear | 1057 | 0.88 | 1198 | 0.31x |
| thief/thief_coin_pouch | 1092 | 0.97 | 1122 | 0.29x |
| sniper/sniper_shatter_rounds | 546 | 0.80 | 686 | 0.18x |
| doctor/plague_syringe | 260 | 0.46 | 566 | 0.15x |
| guitarist/electric_guitar | 756 | 1.40 | 538 | 0.14x |
| druid/raven_totem | 366 | 1.06 | 347 | 0.09x |

---

**Итог полосы: ПОЛОСА НЕ ВЫДЕРЖАНА — требуется тюнинг**