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
| assassin | ideal | 466 | 6.79 | 5.82 | 82 | 113 | 200% | OK | ONESHOT |
| assassin | random | 68 | 0.99 | 0.84 | 82 | 113 | 200% | FAIL | ONESHOT |
| berserk | ideal | 361 | 5.26 | 4.51 | 111 | 151 | 148% | OK | ONESHOT |
| berserk | random | 79 | 1.15 | 0.99 | 111 | 151 | 148% | FAIL | ONESHOT |
| biologist | ideal | 289 | 4.17 | 3.57 | 66 | 87 | 247% | OK | ONESHOT |
| biologist | random | 80 | 1.16 | 0.99 | 66 | 87 | 247% | FAIL | ONESHOT |
| chemist | ideal | 375 | 5.47 | 4.68 | 53 | 69 | 310% | OK | ONESHOT |
| chemist | random | 33 | 0.48 | 0.41 | 53 | 69 | 310% | FAIL | ONESHOT |
| dark_mage | ideal | 557 | 8.11 | 6.95 | 50 | 64 | 324% | OK | ONESHOT |
| dark_mage | random | 96 | 1.40 | 1.20 | 50 | 64 | 324% | RISK | ONESHOT |
| doctor | ideal | 455 | 6.64 | 5.68 | 82 | 109 | 200% | OK | ONESHOT |
| doctor | random | 44 | 0.64 | 0.55 | 82 | 109 | 200% | FAIL | ONESHOT |
| druid | ideal | 670 | 9.76 | 8.36 | 82 | 108 | 200% | OK | ONESHOT |
| druid | random | 49 | 0.71 | 0.61 | 82 | 108 | 200% | FAIL | ONESHOT |
| elementalist | ideal | 473 | 6.89 | 5.90 | 50 | 64 | 324% | OK | ONESHOT |
| elementalist | random | 57 | 0.83 | 0.71 | 50 | 64 | 324% | FAIL | ONESHOT |
| engineer | ideal | 447 | 6.46 | 5.27 | 82 | 107 | 200% | OK | ONESHOT |
| engineer | random | 50 | 0.73 | 0.59 | 82 | 107 | 200% | FAIL | ONESHOT |
| guitarist | ideal | 106 | 1.54 | 1.32 | 66 | 86 | 247% | OK | ONESHOT |
| guitarist | random | 32 | 0.46 | 0.40 | 66 | 86 | 247% | FAIL | ONESHOT |
| knight | ideal | 199 | 2.91 | 2.49 | 154 | 217 | 106% | OK | ONESHOT |
| knight | random | 44 | 0.64 | 0.54 | 154 | 217 | 106% | FAIL | ONESHOT |
| priest | ideal | 318 | 4.60 | 3.90 | 82 | 107 | 200% | OK | ONESHOT |
| priest | random | 31 | 0.45 | 0.38 | 82 | 107 | 200% | FAIL | ONESHOT |
| ranger | ideal | 312 | 4.55 | 3.90 | 67 | 90 | 243% | OK | ONESHOT |
| ranger | random | 43 | 0.62 | 0.53 | 67 | 90 | 243% | FAIL | ONESHOT |
| robot | ideal | 261 | 3.77 | 3.04 | 157 | 221 | 104% | OK | ONESHOT |
| robot | random | 34 | 0.49 | 0.40 | 157 | 221 | 104% | FAIL | ONESHOT |
| sniper | ideal | 261 | 3.81 | 3.26 | 111 | 152 | 148% | OK | ONESHOT |
| sniper | random | 22 | 0.33 | 0.28 | 111 | 152 | 148% | FAIL | ONESHOT |
| soldier | ideal | 588 | 8.57 | 7.34 | 96 | 131 | 170% | OK | ONESHOT |
| soldier | random | 39 | 0.57 | 0.49 | 96 | 131 | 170% | FAIL | ONESHOT |
| thief | ideal | 450 | 6.56 | 5.25 | 66 | 89 | 247% | OK | ONESHOT |
| thief | random | 88 | 1.28 | 1.02 | 66 | 89 | 247% | RISK | ONESHOT |

## Сводка A5 (ideal-билд)

- FAIL: assassin, berserk, biologist, chemist, dark_mage, doctor, druid, elementalist, engineer, guitarist, knight, priest, ranger, robot, sniper, soldier, thief
- RISK: нет
- OK: нет

Оговорки: kit DPS — среднее 3 оружий на болванках (8с, без ульты в full-charge циклах,
без кайта); random-билд ближе к реальному первому прохождению. Ваншот-порог сравнивается
с typical HP (floor×1.45×player_max_hp_mult); уворот/i-frames/absorb смягчают hazard в бою.
