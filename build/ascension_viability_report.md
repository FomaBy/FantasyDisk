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
| assassin | ideal | 1180 | 17.20 | 14.73 | 82 | 113 | 80% | OK | RISK |
| assassin | random | 149 | 2.17 | 1.85 | 82 | 113 | 80% | OK | RISK |
| berserk | ideal | 787 | 11.47 | 9.82 | 111 | 151 | 80% | OK | RISK |
| berserk | random | 167 | 2.43 | 2.08 | 111 | 151 | 80% | OK | RISK |
| biologist | ideal | 722 | 10.43 | 8.93 | 66 | 87 | 80% | OK | RISK |
| biologist | random | 198 | 2.86 | 2.45 | 66 | 87 | 80% | OK | RISK |
| chemist | ideal | 1042 | 15.19 | 13.00 | 53 | 69 | 80% | OK | RISK |
| chemist | random | 90 | 1.31 | 1.12 | 53 | 69 | 80% | RISK | RISK |
| dark_mage | ideal | 851 | 12.41 | 10.62 | 50 | 64 | 80% | OK | RISK |
| dark_mage | random | 152 | 2.21 | 1.90 | 50 | 64 | 80% | OK | RISK |
| doctor | ideal | 1095 | 15.96 | 13.66 | 82 | 109 | 80% | OK | RISK |
| doctor | random | 123 | 1.79 | 1.53 | 82 | 109 | 80% | OK | RISK |
| druid | ideal | 744 | 10.85 | 9.29 | 82 | 108 | 80% | OK | RISK |
| druid | random | 114 | 1.66 | 1.42 | 82 | 108 | 80% | OK | RISK |
| elementalist | ideal | 820 | 11.95 | 10.23 | 50 | 64 | 80% | OK | RISK |
| elementalist | random | 91 | 1.32 | 1.13 | 50 | 64 | 80% | RISK | RISK |
| engineer | ideal | 1062 | 15.33 | 12.50 | 82 | 107 | 80% | OK | RISK |
| engineer | random | 113 | 1.64 | 1.34 | 82 | 107 | 80% | OK | RISK |
| guitarist | ideal | 296 | 4.31 | 3.69 | 66 | 86 | 80% | OK | RISK |
| guitarist | random | 88 | 1.28 | 1.10 | 66 | 86 | 80% | RISK | RISK |
| knight | ideal | 530 | 7.73 | 6.61 | 154 | 217 | 80% | OK | RISK |
| knight | random | 91 | 1.33 | 1.14 | 154 | 217 | 80% | RISK | RISK |
| priest | ideal | 617 | 8.90 | 7.55 | 82 | 107 | 80% | OK | RISK |
| priest | random | 69 | 0.99 | 0.84 | 82 | 107 | 80% | FAIL | RISK |
| ranger | ideal | 987 | 14.38 | 12.31 | 67 | 90 | 80% | OK | RISK |
| ranger | random | 119 | 1.73 | 1.48 | 67 | 90 | 80% | OK | RISK |
| robot | ideal | 689 | 9.95 | 8.04 | 157 | 221 | 80% | OK | RISK |
| robot | random | 75 | 1.09 | 0.88 | 157 | 221 | 80% | FAIL | RISK |
| sniper | ideal | 687 | 10.02 | 8.58 | 111 | 152 | 80% | OK | RISK |
| sniper | random | 69 | 1.01 | 0.86 | 111 | 152 | 80% | FAIL | RISK |
| soldier | ideal | 1165 | 16.99 | 14.54 | 96 | 131 | 80% | OK | RISK |
| soldier | random | 78 | 1.13 | 0.97 | 96 | 131 | 80% | FAIL | RISK |
| thief | ideal | 1108 | 16.15 | 12.92 | 66 | 89 | 80% | OK | RISK |
| thief | random | 203 | 2.96 | 2.37 | 66 | 89 | 80% | OK | RISK |

## Сводка A5 (ideal-билд)

- FAIL: нет
- RISK: assassin, berserk, biologist, chemist, dark_mage, doctor, druid, elementalist, engineer, guitarist, knight, priest, ranger, robot, sniper, soldier, thief
- OK: нет

Оговорки: kit DPS — среднее 3 оружий на болванках (8с, без ульты в full-charge циклах,
без кайта); random-билд ближе к реальному первому прохождению. Ваншот-порог сравнивается
с typical HP (floor×1.45×player_max_hp_mult); уворот/i-frames/absorb смягчают hazard в бою.
