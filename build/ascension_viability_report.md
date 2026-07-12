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
| assassin | ideal | 474 | 6.90 | 5.91 | 82 | 113 | 200% | OK | ONESHOT |
| assassin | random | 64 | 0.93 | 0.80 | 82 | 113 | 200% | FAIL | ONESHOT |
| berserk | ideal | 384 | 5.59 | 4.79 | 111 | 151 | 148% | OK | ONESHOT |
| berserk | random | 81 | 1.18 | 1.01 | 111 | 151 | 148% | RISK | ONESHOT |
| biologist | ideal | 298 | 4.30 | 3.68 | 66 | 87 | 247% | OK | ONESHOT |
| biologist | random | 82 | 1.19 | 1.02 | 66 | 87 | 247% | RISK | ONESHOT |
| chemist | ideal | 550 | 8.02 | 6.86 | 53 | 69 | 310% | OK | ONESHOT |
| chemist | random | 40 | 0.58 | 0.50 | 53 | 69 | 310% | FAIL | ONESHOT |
| dark_mage | ideal | 510 | 7.43 | 6.36 | 50 | 64 | 324% | OK | ONESHOT |
| dark_mage | random | 99 | 1.44 | 1.23 | 50 | 64 | 324% | RISK | ONESHOT |
| doctor | ideal | 558 | 8.13 | 6.96 | 82 | 109 | 200% | OK | ONESHOT |
| doctor | random | 44 | 0.64 | 0.55 | 82 | 109 | 200% | FAIL | ONESHOT |
| druid | ideal | 594 | 8.65 | 7.41 | 82 | 108 | 200% | OK | ONESHOT |
| druid | random | 49 | 0.72 | 0.62 | 82 | 108 | 200% | FAIL | ONESHOT |
| elementalist | ideal | 579 | 8.43 | 7.22 | 50 | 64 | 324% | OK | ONESHOT |
| elementalist | random | 58 | 0.85 | 0.72 | 50 | 64 | 324% | FAIL | ONESHOT |
| engineer | ideal | 444 | 6.42 | 5.23 | 82 | 107 | 200% | OK | ONESHOT |
| engineer | random | 46 | 0.66 | 0.54 | 82 | 107 | 200% | FAIL | ONESHOT |
| guitarist | ideal | 112 | 1.63 | 1.40 | 66 | 86 | 247% | OK | ONESHOT |
| guitarist | random | 34 | 0.50 | 0.43 | 66 | 86 | 247% | FAIL | ONESHOT |
| knight | ideal | 231 | 3.37 | 2.88 | 154 | 217 | 106% | OK | ONESHOT |
| knight | random | 40 | 0.58 | 0.50 | 154 | 217 | 106% | FAIL | ONESHOT |
| priest | ideal | 246 | 3.55 | 3.01 | 82 | 107 | 200% | OK | ONESHOT |
| priest | random | 30 | 0.43 | 0.37 | 82 | 107 | 200% | FAIL | ONESHOT |
| ranger | ideal | 319 | 4.65 | 3.98 | 67 | 90 | 243% | OK | ONESHOT |
| ranger | random | 46 | 0.66 | 0.57 | 67 | 90 | 243% | FAIL | ONESHOT |
| robot | ideal | 258 | 3.73 | 3.01 | 157 | 221 | 104% | OK | ONESHOT |
| robot | random | 31 | 0.44 | 0.36 | 157 | 221 | 104% | FAIL | ONESHOT |
| sniper | ideal | 260 | 3.78 | 3.24 | 111 | 152 | 148% | OK | ONESHOT |
| sniper | random | 25 | 0.36 | 0.31 | 111 | 152 | 148% | FAIL | ONESHOT |
| soldier | ideal | 537 | 7.82 | 6.70 | 96 | 131 | 170% | OK | ONESHOT |
| soldier | random | 38 | 0.56 | 0.48 | 96 | 131 | 170% | FAIL | ONESHOT |
| thief | ideal | 423 | 6.17 | 4.94 | 66 | 89 | 247% | OK | ONESHOT |
| thief | random | 79 | 1.16 | 0.93 | 66 | 89 | 247% | FAIL | ONESHOT |

## Сводка A5 (ideal-билд)

- FAIL: assassin, berserk, biologist, chemist, dark_mage, doctor, druid, elementalist, engineer, guitarist, knight, priest, ranger, robot, sniper, soldier, thief
- RISK: нет
- OK: нет

Оговорки: kit DPS — среднее 3 оружий на болванках (8с, без ульты в full-charge циклах,
без кайта); random-билд ближе к реальному первому прохождению. Ваншот-порог сравнивается
с typical HP (floor×1.45×player_max_hp_mult); уворот/i-frames/absorb смягчают hazard в бою.
