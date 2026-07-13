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
| assassin | ideal | 514 | 7.49 | 6.41 | 82 | 113 | 200% | OK | ONESHOT |
| assassin | random | 60 | 0.87 | 0.75 | 82 | 113 | 200% | FAIL | ONESHOT |
| berserk | ideal | 333 | 4.86 | 4.16 | 111 | 151 | 148% | OK | ONESHOT |
| berserk | random | 82 | 1.20 | 1.02 | 111 | 151 | 148% | RISK | ONESHOT |
| biologist | ideal | 291 | 4.20 | 3.60 | 66 | 87 | 247% | OK | ONESHOT |
| biologist | random | 82 | 1.19 | 1.02 | 66 | 87 | 247% | RISK | ONESHOT |
| chemist | ideal | 361 | 5.26 | 4.50 | 53 | 69 | 310% | OK | ONESHOT |
| chemist | random | 40 | 0.58 | 0.50 | 53 | 69 | 310% | FAIL | ONESHOT |
| dark_mage | ideal | 382 | 5.57 | 4.77 | 50 | 64 | 324% | OK | ONESHOT |
| dark_mage | random | 80 | 1.17 | 1.00 | 50 | 64 | 324% | FAIL | ONESHOT |
| doctor | ideal | 459 | 6.69 | 5.73 | 82 | 109 | 200% | OK | ONESHOT |
| doctor | random | 46 | 0.66 | 0.57 | 82 | 109 | 200% | FAIL | ONESHOT |
| druid | ideal | 289 | 4.22 | 3.61 | 82 | 108 | 200% | OK | ONESHOT |
| druid | random | 39 | 0.57 | 0.48 | 82 | 108 | 200% | FAIL | ONESHOT |
| elementalist | ideal | 567 | 8.27 | 7.08 | 50 | 64 | 324% | OK | ONESHOT |
| elementalist | random | 45 | 0.66 | 0.57 | 50 | 64 | 324% | FAIL | ONESHOT |
| engineer | ideal | 454 | 6.55 | 5.34 | 82 | 107 | 200% | OK | ONESHOT |
| engineer | random | 47 | 0.68 | 0.56 | 82 | 107 | 200% | FAIL | ONESHOT |
| guitarist | ideal | 160 | 2.33 | 1.99 | 66 | 86 | 247% | OK | ONESHOT |
| guitarist | random | 33 | 0.48 | 0.41 | 66 | 86 | 247% | FAIL | ONESHOT |
| knight | ideal | 244 | 3.56 | 3.04 | 154 | 217 | 106% | OK | ONESHOT |
| knight | random | 47 | 0.69 | 0.59 | 154 | 217 | 106% | FAIL | ONESHOT |
| priest | ideal | 276 | 3.99 | 3.38 | 82 | 107 | 200% | OK | ONESHOT |
| priest | random | 37 | 0.54 | 0.46 | 82 | 107 | 200% | FAIL | ONESHOT |
| ranger | ideal | 298 | 4.34 | 3.72 | 67 | 90 | 243% | OK | ONESHOT |
| ranger | random | 48 | 0.69 | 0.59 | 67 | 90 | 243% | FAIL | ONESHOT |
| robot | ideal | 253 | 3.66 | 2.96 | 157 | 221 | 104% | OK | ONESHOT |
| robot | random | 33 | 0.48 | 0.39 | 157 | 221 | 104% | FAIL | ONESHOT |
| sniper | ideal | 339 | 4.94 | 4.23 | 111 | 152 | 148% | OK | ONESHOT |
| sniper | random | 26 | 0.38 | 0.32 | 111 | 152 | 148% | FAIL | ONESHOT |
| soldier | ideal | 650 | 9.47 | 8.11 | 96 | 131 | 170% | OK | ONESHOT |
| soldier | random | 45 | 0.66 | 0.56 | 96 | 131 | 170% | FAIL | ONESHOT |
| thief | ideal | 431 | 6.29 | 5.03 | 66 | 89 | 247% | OK | ONESHOT |
| thief | random | 77 | 1.13 | 0.90 | 66 | 89 | 247% | FAIL | ONESHOT |

## Сводка A5 (ideal-билд)

- FAIL: assassin, berserk, biologist, chemist, dark_mage, doctor, druid, elementalist, engineer, guitarist, knight, priest, ranger, robot, sniper, soldier, thief
- RISK: нет
- OK: нет

Оговорки: kit DPS — среднее 3 оружий на болванках (8с, без ульты в full-charge циклах,
без кайта); random-билд ближе к реальному первому прохождению. Ваншот-порог сравнивается
с typical HP (floor×1.45×player_max_hp_mult); уворот/i-frames/absorb смягчают hazard в бою.
