# Character Balance — comfort-нормированная полоса (SCRUM-544)

Сгенерировано `tools/character_balance_csv.gd`. Допуск полосы: ±20% от медианы.
Нормировка: `comfort_normalized = measured_dps / comfort_weight[class]` (см. `progression_data_balance.gd` COMFORT_WEIGHTS).

## Срез `ideal_1` — FAIL

- медиана нормированного DPS: **239.7**, полоса [191.7 .. 287.6]
- факт: min **102.1**, max **626.1**, разброс **6.1x** (цель ≤ 1.50x)
- нарушений полосы: **27 / 51**

| класс/оружие | raw DPS | comfort | norm DPS | ×медиана |
|---|--:|--:|--:|--:|
| assassin/chakrams | 495 | 0.79 | 626 | 2.61x |
| assassin/shadow_daggers | 441 | 0.79 | 558 | 2.33x |
| doctor/restore_potion | 399 | 0.79 | 505 | 2.11x |
| ranger/storm_longbow | 393 | 0.81 | 485 | 2.02x |
| ranger/moon_crossbow | 392 | 0.81 | 484 | 2.02x |
| ranger/hunter_trap | 391 | 0.81 | 482 | 2.01x |
| sniper/sniper_deadeye_rifle | 315 | 0.78 | 404 | 1.68x |
| sniper/sniper_shatter_rounds | 313 | 0.78 | 401 | 1.67x |
| sniper/sniper_spotter_scope | 312 | 0.78 | 399 | 1.67x |
| berserk/axe | 304 | 0.98 | 310 | 1.30x |
| berserk/hammer | 304 | 0.98 | 310 | 1.29x |
| knight/tower_shield | 256 | 0.83 | 309 | 1.29x |
| knight/long_spear | 256 | 0.83 | 309 | 1.29x |
| knight/holy_flail | 256 | 0.83 | 308 | 1.29x |
| robot/robot_reactor_core | 269 | 0.93 | 289 | 1.21x |
| robot/robot_magnetic_anchor | 268 | 0.93 | 289 | 1.20x |
| robot/robot_hydraulic_press | 268 | 0.93 | 289 | 1.20x |
| engineer/engineer_sentry_wrench | 196 | 1.03 | 190 | 0.79x |
| chemist/acid_flask | 266 | 1.55 | 172 | 0.72x |
| doctor/plague_syringe | 132 | 0.79 | 168 | 0.70x |
| dark_mage/dark_wand | 250 | 1.50 | 167 | 0.69x |
| dark_mage/dark_book | 248 | 1.50 | 165 | 0.69x |
| biologist/biologist_spore_lens | 201 | 1.33 | 151 | 0.63x |
| assassin/venom_wire | 118 | 0.79 | 150 | 0.62x |
| dark_mage/cursed_skull | 197 | 1.50 | 131 | 0.55x |
| doctor/bone_saw | 85 | 0.79 | 107 | 0.45x |
| chemist/homunculus_vial | 146 | 1.43 | 102 | 0.43x |

## Срез `ideal_5` — FAIL

- медиана нормированного DPS: **812.8**, полоса [650.3 .. 975.4]
- факт: min **252.0**, max **1556.5**, разброс **6.2x** (цель ≤ 1.50x)
- нарушений полосы: **7 / 51**

| класс/оружие | raw DPS | comfort | norm DPS | ×медиана |
|---|--:|--:|--:|--:|
| doctor/restore_potion | 1230 | 0.79 | 1557 | 1.91x |
| assassin/chakrams | 833 | 0.79 | 1054 | 1.30x |
| berserk/sword | 612 | 0.98 | 624 | 0.77x |
| doctor/plague_syringe | 428 | 0.79 | 541 | 0.67x |
| chemist/homunculus_vial | 706 | 1.43 | 494 | 0.61x |
| doctor/bone_saw | 265 | 0.79 | 336 | 0.41x |
| assassin/venom_wire | 199 | 0.79 | 252 | 0.31x |

## Срез `ideal_20` — FAIL

- медиана нормированного DPS: **753.7**, полоса [602.9 .. 904.4]
- факт: min **222.9**, max **1276.4**, разброс **5.7x** (цель ≤ 1.50x)
- нарушений полосы: **8 / 51**

| класс/оружие | raw DPS | comfort | norm DPS | ×медиана |
|---|--:|--:|--:|--:|
| doctor/restore_potion | 1008 | 0.79 | 1276 | 1.69x |
| assassin/chakrams | 736 | 0.79 | 932 | 1.24x |
| dark_mage/cursed_skull | 889 | 1.50 | 593 | 0.79x |
| berserk/sword | 541 | 0.98 | 552 | 0.73x |
| doctor/plague_syringe | 351 | 0.79 | 444 | 0.59x |
| chemist/homunculus_vial | 612 | 1.43 | 428 | 0.57x |
| doctor/bone_saw | 235 | 0.79 | 297 | 0.39x |
| assassin/venom_wire | 176 | 0.79 | 223 | 0.30x |

---

**Итог полосы: ПОЛОСА НЕ ВЫДЕРЖАНА — требуется тюнинг**