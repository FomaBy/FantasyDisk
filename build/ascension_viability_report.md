# Матрица жизнеспособности возвышений (A0 / A1 / A5)

Генератор: `tools/ascension_viability_report.py` (модель — см. док-стринг и
`docs/design/systems/balance_systems_map_fan1028.md`). Живой слой: lvl20_ideal /
lvl20_random из `tools/character_balance_csv.gd --mode=live` (окно 8с, болванки).

## Пороги угрозы (worst-case ротации)

| Уровень | Босс А1 HP | треб. DPS | Босс А2 HP | треб. DPS | Элитка st12 HP | треб. DPS |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| A0 | 7622 | 25.4 | 21608 | 72.0 | 9296 | 31.0 |
| A1 | 7622 | 25.4 | 21608 | 72.0 | 9296 | 31.0 |
| A5 | 9909 | 33.0 | 28090 | 93.6 | 11620 | 38.7 |
| A5 секрет | — | — | 36546 | 121.8 | — | — |

## Ваншот-пороги финального босса (фаза 3; на A5 фаза 4)

| Уровень | Худший hazard | Худший slam |
| --- | ---: | ---: |
| A0 | 107.3 | 100.0 |
| A1 | 107.3 | 100.0 |
| A5 | 163.6 | 156.0 |

## Классы

| Класс | Билд | Kit DPS A0 | Маржа A1 | Маржа A5 (А2-босс) | HP typ A5 | EHP A5 | Hazard A5 %HP | Вердикт DPS A5 | Вердикт выживания A5 |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | :---: | :---: |
| assassin | ideal | 531 | 7.74 | 6.63 | 82 | 113 | 200% | OK | ONESHOT |
| assassin | random | 56 | 0.81 | 0.69 | 82 | 113 | 200% | FAIL | ONESHOT |
| berserk | ideal | 286 | 4.17 | 3.57 | 111 | 151 | 148% | OK | ONESHOT |
| berserk | random | 75 | 1.10 | 0.94 | 111 | 151 | 148% | FAIL | ONESHOT |
| biologist | ideal | 308 | 4.45 | 3.81 | 66 | 87 | 247% | OK | ONESHOT |
| biologist | random | 81 | 1.17 | 1.00 | 66 | 87 | 247% | RISK | ONESHOT |
| chemist | ideal | 306 | 4.47 | 3.82 | 53 | 69 | 310% | OK | ONESHOT |
| chemist | random | 41 | 0.60 | 0.51 | 53 | 69 | 310% | FAIL | ONESHOT |
| dark_mage | ideal | 479 | 6.99 | 5.98 | 50 | 64 | 324% | OK | ONESHOT |
| dark_mage | random | 80 | 1.17 | 1.00 | 50 | 64 | 324% | RISK | ONESHOT |
| doctor | ideal | 363 | 5.29 | 4.53 | 82 | 109 | 200% | OK | ONESHOT |
| doctor | random | 44 | 0.65 | 0.55 | 82 | 109 | 200% | FAIL | ONESHOT |
| druid | ideal | 509 | 7.43 | 6.36 | 82 | 108 | 200% | OK | ONESHOT |
| druid | random | 61 | 0.89 | 0.76 | 82 | 108 | 200% | FAIL | ONESHOT |
| elementalist | ideal | 387 | 5.65 | 4.83 | 50 | 64 | 324% | OK | ONESHOT |
| elementalist | random | 47 | 0.69 | 0.59 | 50 | 64 | 324% | FAIL | ONESHOT |
| engineer | ideal | 391 | 5.64 | 4.60 | 82 | 107 | 200% | OK | ONESHOT |
| engineer | random | 48 | 0.70 | 0.57 | 82 | 107 | 200% | FAIL | ONESHOT |
| guitarist | ideal | 100 | 1.45 | 1.24 | 66 | 86 | 247% | RISK | ONESHOT |
| guitarist | random | 28 | 0.42 | 0.36 | 66 | 86 | 247% | FAIL | ONESHOT |
| knight | ideal | 207 | 3.02 | 2.58 | 154 | 217 | 106% | OK | ONESHOT |
| knight | random | 36 | 0.53 | 0.45 | 154 | 217 | 106% | FAIL | ONESHOT |
| priest | ideal | 194 | 2.80 | 2.38 | 82 | 107 | 200% | OK | ONESHOT |
| priest | random | 31 | 0.45 | 0.38 | 82 | 107 | 200% | FAIL | ONESHOT |
| ranger | ideal | 277 | 4.04 | 3.46 | 67 | 90 | 243% | OK | ONESHOT |
| ranger | random | 38 | 0.55 | 0.47 | 67 | 90 | 243% | FAIL | ONESHOT |
| robot | ideal | 245 | 3.54 | 2.86 | 157 | 221 | 104% | OK | ONESHOT |
| robot | random | 30 | 0.43 | 0.35 | 157 | 221 | 104% | FAIL | ONESHOT |
| sniper | ideal | 212 | 3.10 | 2.65 | 111 | 152 | 148% | OK | ONESHOT |
| sniper | random | 25 | 0.37 | 0.32 | 111 | 152 | 148% | FAIL | ONESHOT |
| soldier | ideal | 507 | 7.39 | 6.32 | 96 | 131 | 170% | OK | ONESHOT |
| soldier | random | 41 | 0.60 | 0.52 | 96 | 131 | 170% | FAIL | ONESHOT |
| thief | ideal | 373 | 5.44 | 4.35 | 66 | 89 | 247% | OK | ONESHOT |
| thief | random | 69 | 1.00 | 0.80 | 66 | 89 | 247% | FAIL | ONESHOT |

## Сводка A5 (ideal-билд)

- FAIL: assassin, berserk, biologist, chemist, dark_mage, doctor, druid, elementalist, engineer, guitarist, knight, priest, ranger, robot, sniper, soldier, thief
- RISK: нет
- OK: нет

Оговорки: kit DPS — среднее 3 оружий на болванках (8с, без ульты в full-charge циклах,
без кайта); random-билд ближе к реальному первому прохождению. Ваншот-порог сравнивается
с typical HP (floor×1.45×player_max_hp_mult); уворот/i-frames/absorb смягчают hazard в бою.
