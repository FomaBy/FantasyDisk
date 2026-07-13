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
| assassin | ideal | 1219 | 17.77 | 15.21 | 82 | 113 | 80% | OK | RISK |
| assassin | random | 152 | 2.22 | 1.90 | 82 | 113 | 80% | OK | RISK |
| berserk | ideal | 731 | 10.65 | 9.12 | 111 | 151 | 80% | OK | RISK |
| berserk | random | 161 | 2.34 | 2.01 | 111 | 151 | 80% | OK | RISK |
| biologist | ideal | 700 | 10.11 | 8.65 | 66 | 87 | 80% | OK | RISK |
| biologist | random | 193 | 2.79 | 2.39 | 66 | 87 | 80% | OK | RISK |
| chemist | ideal | 776 | 11.31 | 9.68 | 53 | 69 | 80% | OK | RISK |
| chemist | random | 86 | 1.26 | 1.08 | 53 | 69 | 80% | RISK | RISK |
| dark_mage | ideal | 840 | 12.25 | 10.49 | 50 | 64 | 80% | OK | RISK |
| dark_mage | random | 142 | 2.07 | 1.77 | 50 | 64 | 80% | OK | RISK |
| doctor | ideal | 965 | 14.07 | 12.05 | 82 | 109 | 80% | OK | RISK |
| doctor | random | 116 | 1.69 | 1.45 | 82 | 109 | 80% | OK | RISK |
| druid | ideal | 884 | 12.89 | 11.03 | 82 | 108 | 80% | OK | RISK |
| druid | random | 125 | 1.83 | 1.56 | 82 | 108 | 80% | OK | RISK |
| elementalist | ideal | 673 | 9.81 | 8.40 | 50 | 64 | 80% | OK | RISK |
| elementalist | random | 84 | 1.22 | 1.04 | 50 | 64 | 80% | RISK | RISK |
| engineer | ideal | 1037 | 14.98 | 12.21 | 82 | 107 | 80% | OK | RISK |
| engineer | random | 119 | 1.72 | 1.40 | 82 | 107 | 80% | OK | RISK |
| guitarist | ideal | 435 | 6.34 | 5.43 | 66 | 86 | 80% | OK | RISK |
| guitarist | random | 134 | 1.96 | 1.68 | 66 | 86 | 80% | OK | RISK |
| knight | ideal | 523 | 7.63 | 6.53 | 154 | 217 | 80% | OK | RISK |
| knight | random | 92 | 1.34 | 1.15 | 154 | 217 | 80% | RISK | RISK |
| priest | ideal | 554 | 8.00 | 6.79 | 82 | 107 | 80% | OK | RISK |
| priest | random | 60 | 0.86 | 0.73 | 82 | 107 | 80% | FAIL | RISK |
| ranger | ideal | 808 | 11.77 | 10.08 | 67 | 90 | 80% | OK | RISK |
| ranger | random | 114 | 1.66 | 1.42 | 67 | 90 | 80% | OK | RISK |
| robot | ideal | 590 | 8.53 | 6.89 | 157 | 221 | 80% | OK | RISK |
| robot | random | 76 | 1.09 | 0.88 | 157 | 221 | 80% | FAIL | RISK |
| sniper | ideal | 713 | 10.39 | 8.89 | 111 | 152 | 80% | OK | RISK |
| sniper | random | 79 | 1.15 | 0.99 | 111 | 152 | 80% | FAIL | RISK |
| soldier | ideal | 1128 | 16.45 | 14.08 | 96 | 131 | 80% | OK | RISK |
| soldier | random | 84 | 1.22 | 1.05 | 96 | 131 | 80% | RISK | RISK |
| thief | ideal | 1067 | 15.55 | 12.44 | 66 | 89 | 80% | OK | RISK |
| thief | random | 201 | 2.93 | 2.34 | 66 | 89 | 80% | OK | RISK |

## Сводка A5 (ideal-билд)

- FAIL: нет
- RISK: assassin, berserk, biologist, chemist, dark_mage, doctor, druid, elementalist, engineer, guitarist, knight, priest, ranger, robot, sniper, soldier, thief
- OK: нет

Оговорки: kit DPS — среднее 3 оружий на болванках (8с, без ульты в full-charge циклах,
без кайта); random-билд ближе к реальному первому прохождению. Ваншот-порог сравнивается
с typical HP (floor×1.45×player_max_hp_mult); уворот/i-frames/absorb смягчают hazard в бою.
