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
| assassin | ideal | 1340 | 19.54 | 16.72 | 82 | 113 | 80% | OK | RISK |
| assassin | random | 154 | 2.24 | 1.92 | 82 | 113 | 80% | OK | RISK |
| berserk | ideal | 699 | 10.19 | 8.72 | 111 | 151 | 80% | OK | RISK |
| berserk | random | 157 | 2.29 | 1.96 | 111 | 151 | 80% | OK | RISK |
| biologist | ideal | 711 | 10.27 | 8.79 | 66 | 87 | 80% | OK | RISK |
| biologist | random | 197 | 2.84 | 2.43 | 66 | 87 | 80% | OK | RISK |
| chemist | ideal | 742 | 10.82 | 9.26 | 53 | 69 | 80% | OK | RISK |
| chemist | random | 83 | 1.21 | 1.04 | 53 | 69 | 80% | RISK | RISK |
| dark_mage | ideal | 747 | 10.89 | 9.32 | 50 | 64 | 80% | OK | RISK |
| dark_mage | random | 133 | 1.94 | 1.66 | 50 | 64 | 80% | OK | RISK |
| doctor | ideal | 1163 | 16.95 | 14.51 | 82 | 109 | 80% | OK | RISK |
| doctor | random | 121 | 1.77 | 1.51 | 82 | 109 | 80% | OK | RISK |
| druid | ideal | 696 | 10.14 | 8.68 | 82 | 108 | 80% | OK | RISK |
| druid | random | 112 | 1.64 | 1.40 | 82 | 108 | 80% | OK | RISK |
| elementalist | ideal | 764 | 11.13 | 9.53 | 50 | 64 | 80% | OK | RISK |
| elementalist | random | 89 | 1.30 | 1.11 | 50 | 64 | 80% | RISK | RISK |
| engineer | ideal | 1237 | 17.86 | 14.56 | 82 | 107 | 80% | OK | RISK |
| engineer | random | 124 | 1.79 | 1.46 | 82 | 107 | 80% | OK | RISK |
| guitarist | ideal | 487 | 7.10 | 6.08 | 66 | 86 | 80% | OK | RISK |
| guitarist | random | 131 | 1.91 | 1.63 | 66 | 86 | 80% | OK | RISK |
| knight | ideal | 578 | 8.43 | 7.21 | 154 | 217 | 80% | OK | RISK |
| knight | random | 105 | 1.53 | 1.31 | 154 | 217 | 80% | OK | RISK |
| priest | ideal | 583 | 8.42 | 7.14 | 82 | 107 | 80% | OK | RISK |
| priest | random | 60 | 0.87 | 0.74 | 82 | 107 | 80% | FAIL | RISK |
| ranger | ideal | 842 | 12.28 | 10.51 | 67 | 90 | 80% | OK | RISK |
| ranger | random | 135 | 1.96 | 1.68 | 67 | 90 | 80% | OK | RISK |
| robot | ideal | 572 | 8.26 | 6.67 | 157 | 221 | 80% | OK | RISK |
| robot | random | 67 | 0.97 | 0.78 | 157 | 221 | 80% | FAIL | RISK |
| sniper | ideal | 827 | 12.06 | 10.32 | 111 | 152 | 80% | OK | RISK |
| sniper | random | 77 | 1.13 | 0.97 | 111 | 152 | 80% | FAIL | RISK |
| soldier | ideal | 1118 | 16.29 | 13.95 | 96 | 131 | 80% | OK | RISK |
| soldier | random | 78 | 1.13 | 0.97 | 96 | 131 | 80% | FAIL | RISK |
| thief | ideal | 1156 | 16.85 | 13.48 | 66 | 89 | 80% | OK | RISK |
| thief | random | 203 | 2.96 | 2.37 | 66 | 89 | 80% | OK | RISK |

## Сводка A5 (ideal-билд)

- FAIL: нет
- RISK: assassin, berserk, biologist, chemist, dark_mage, doctor, druid, elementalist, engineer, guitarist, knight, priest, ranger, robot, sniper, soldier, thief
- OK: нет

Оговорки: kit DPS — среднее 3 оружий на болванках (8с, без ульты в full-charge циклах,
без кайта); random-билд ближе к реальному первому прохождению. Ваншот-порог сравнивается
с typical HP (floor×1.45×player_max_hp_mult); уворот/i-frames/absorb смягчают hazard в бою.
