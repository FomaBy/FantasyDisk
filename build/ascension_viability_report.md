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
| assassin | ideal | 541 | 7.88 | 6.75 | 82 | 113 | 200% | OK | ONESHOT |
| assassin | random | 54 | 0.79 | 0.67 | 82 | 113 | 200% | FAIL | ONESHOT |
| berserk | ideal | 373 | 5.43 | 4.65 | 111 | 151 | 148% | OK | ONESHOT |
| berserk | random | 93 | 1.35 | 1.16 | 111 | 151 | 148% | RISK | ONESHOT |
| biologist | ideal | 296 | 4.28 | 3.66 | 66 | 87 | 247% | OK | ONESHOT |
| biologist | random | 81 | 1.17 | 1.00 | 66 | 87 | 247% | RISK | ONESHOT |
| chemist | ideal | 390 | 5.68 | 4.86 | 53 | 69 | 310% | OK | ONESHOT |
| chemist | random | 42 | 0.61 | 0.52 | 53 | 69 | 310% | FAIL | ONESHOT |
| dark_mage | ideal | 510 | 7.44 | 6.37 | 50 | 64 | 324% | OK | ONESHOT |
| dark_mage | random | 96 | 1.40 | 1.19 | 50 | 64 | 324% | RISK | ONESHOT |
| doctor | ideal | 371 | 5.41 | 4.63 | 82 | 109 | 200% | OK | ONESHOT |
| doctor | random | 47 | 0.68 | 0.58 | 82 | 109 | 200% | FAIL | ONESHOT |
| druid | ideal | 626 | 9.13 | 7.81 | 82 | 108 | 200% | OK | ONESHOT |
| druid | random | 45 | 0.66 | 0.56 | 82 | 108 | 200% | FAIL | ONESHOT |
| elementalist | ideal | 605 | 8.82 | 7.55 | 50 | 64 | 324% | OK | ONESHOT |
| elementalist | random | 58 | 0.85 | 0.73 | 50 | 64 | 324% | FAIL | ONESHOT |
| engineer | ideal | 450 | 6.50 | 5.30 | 82 | 107 | 200% | OK | ONESHOT |
| engineer | random | 61 | 0.88 | 0.72 | 82 | 107 | 200% | FAIL | ONESHOT |
| guitarist | ideal | 124 | 1.80 | 1.54 | 66 | 86 | 247% | OK | ONESHOT |
| guitarist | random | 34 | 0.50 | 0.42 | 66 | 86 | 247% | FAIL | ONESHOT |
| knight | ideal | 238 | 3.47 | 2.97 | 154 | 217 | 106% | OK | ONESHOT |
| knight | random | 46 | 0.68 | 0.58 | 154 | 217 | 106% | FAIL | ONESHOT |
| priest | ideal | 260 | 3.75 | 3.18 | 82 | 107 | 200% | OK | ONESHOT |
| priest | random | 30 | 0.44 | 0.37 | 82 | 107 | 200% | FAIL | ONESHOT |
| ranger | ideal | 310 | 4.52 | 3.87 | 67 | 90 | 243% | OK | ONESHOT |
| ranger | random | 46 | 0.68 | 0.58 | 67 | 90 | 243% | FAIL | ONESHOT |
| robot | ideal | 280 | 4.04 | 3.26 | 157 | 221 | 104% | OK | ONESHOT |
| robot | random | 29 | 0.42 | 0.34 | 157 | 221 | 104% | FAIL | ONESHOT |
| sniper | ideal | 269 | 3.92 | 3.36 | 111 | 152 | 148% | OK | ONESHOT |
| sniper | random | 24 | 0.35 | 0.30 | 111 | 152 | 148% | FAIL | ONESHOT |
| soldier | ideal | 576 | 8.39 | 7.19 | 96 | 131 | 170% | OK | ONESHOT |
| soldier | random | 38 | 0.55 | 0.47 | 96 | 131 | 170% | FAIL | ONESHOT |
| thief | ideal | 600 | 8.75 | 7.00 | 66 | 89 | 247% | OK | ONESHOT |
| thief | random | 73 | 1.07 | 0.86 | 66 | 89 | 247% | FAIL | ONESHOT |

## Сводка A5 (ideal-билд)

- FAIL: assassin, berserk, biologist, chemist, dark_mage, doctor, druid, elementalist, engineer, guitarist, knight, priest, ranger, robot, sniper, soldier, thief
- RISK: нет
- OK: нет

Оговорки: kit DPS — среднее 3 оружий на болванках (8с, без ульты в full-charge циклах,
без кайта); random-билд ближе к реальному первому прохождению. Ваншот-порог сравнивается
с typical HP (floor×1.45×player_max_hp_mult); уворот/i-frames/absorb смягчают hazard в бою.
