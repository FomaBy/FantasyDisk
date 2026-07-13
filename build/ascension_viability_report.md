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
| assassin | ideal | 1409 | 20.53 | 17.58 | 82 | 113 | 80% | OK | RISK |
| assassin | random | 139 | 2.03 | 1.74 | 82 | 113 | 80% | OK | RISK |
| berserk | ideal | 976 | 14.23 | 12.18 | 111 | 151 | 80% | OK | RISK |
| berserk | random | 199 | 2.91 | 2.49 | 111 | 151 | 80% | OK | RISK |
| biologist | ideal | 716 | 10.33 | 8.84 | 66 | 87 | 80% | OK | RISK |
| biologist | random | 195 | 2.82 | 2.41 | 66 | 87 | 80% | OK | RISK |
| chemist | ideal | 897 | 13.07 | 11.19 | 53 | 69 | 80% | OK | RISK |
| chemist | random | 86 | 1.25 | 1.07 | 53 | 69 | 80% | RISK | RISK |
| dark_mage | ideal | 997 | 14.54 | 12.45 | 50 | 64 | 80% | OK | RISK |
| dark_mage | random | 179 | 2.61 | 2.23 | 50 | 64 | 80% | OK | RISK |
| doctor | ideal | 989 | 14.42 | 12.34 | 82 | 109 | 80% | OK | RISK |
| doctor | random | 112 | 1.63 | 1.39 | 82 | 109 | 80% | OK | RISK |
| druid | ideal | 585 | 8.53 | 7.30 | 82 | 108 | 80% | OK | RISK |
| druid | random | 81 | 1.18 | 1.01 | 82 | 108 | 80% | RISK | RISK |
| elementalist | ideal | 924 | 13.47 | 11.53 | 50 | 64 | 80% | OK | RISK |
| elementalist | random | 109 | 1.59 | 1.36 | 50 | 64 | 80% | OK | RISK |
| engineer | ideal | 1116 | 16.11 | 13.13 | 82 | 107 | 80% | OK | RISK |
| engineer | random | 133 | 1.93 | 1.57 | 82 | 107 | 80% | OK | RISK |
| guitarist | ideal | 269 | 3.92 | 3.36 | 66 | 86 | 80% | OK | RISK |
| guitarist | random | 77 | 1.12 | 0.96 | 66 | 86 | 80% | FAIL | RISK |
| knight | ideal | 582 | 8.49 | 7.27 | 154 | 217 | 80% | OK | RISK |
| knight | random | 105 | 1.53 | 1.31 | 154 | 217 | 80% | OK | RISK |
| priest | ideal | 604 | 8.72 | 7.40 | 82 | 107 | 80% | OK | RISK |
| priest | random | 82 | 1.18 | 1.00 | 82 | 107 | 80% | RISK | RISK |
| ranger | ideal | 770 | 11.23 | 9.61 | 67 | 90 | 80% | OK | RISK |
| ranger | random | 114 | 1.66 | 1.42 | 67 | 90 | 80% | OK | RISK |
| robot | ideal | 589 | 8.51 | 6.87 | 157 | 221 | 80% | OK | RISK |
| robot | random | 82 | 1.18 | 0.95 | 157 | 221 | 80% | FAIL | RISK |
| sniper | ideal | 594 | 8.65 | 7.41 | 111 | 152 | 80% | OK | RISK |
| sniper | random | 56 | 0.82 | 0.70 | 111 | 152 | 80% | FAIL | RISK |
| soldier | ideal | 1466 | 21.37 | 18.29 | 96 | 131 | 80% | OK | RISK |
| soldier | random | 103 | 1.50 | 1.28 | 96 | 131 | 80% | OK | RISK |
| thief | ideal | 1136 | 16.57 | 13.25 | 66 | 89 | 80% | OK | RISK |
| thief | random | 200 | 2.92 | 2.34 | 66 | 89 | 80% | OK | RISK |

## Сводка A5 (ideal-билд)

- FAIL: нет
- RISK: assassin, berserk, biologist, chemist, dark_mage, doctor, druid, elementalist, engineer, guitarist, knight, priest, ranger, robot, sniper, soldier, thief
- OK: нет

Оговорки: kit DPS — среднее 3 оружий на болванках (8с, без ульты в full-charge циклах,
без кайта); random-билд ближе к реальному первому прохождению. Ваншот-порог сравнивается
с typical HP (floor×1.45×player_max_hp_mult); уворот/i-frames/absorb смягчают hazard в бою.
