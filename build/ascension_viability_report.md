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
| assassin | ideal | 630 | 9.18 | 7.86 | 82 | 113 | 200% | OK | ONESHOT |
| assassin | random | 67 | 0.98 | 0.84 | 82 | 113 | 200% | FAIL | ONESHOT |
| berserk | ideal | 319 | 4.64 | 3.98 | 111 | 151 | 148% | OK | ONESHOT |
| berserk | random | 80 | 1.17 | 1.00 | 111 | 151 | 148% | RISK | ONESHOT |
| biologist | ideal | 300 | 4.33 | 3.71 | 66 | 87 | 247% | OK | ONESHOT |
| biologist | random | 90 | 1.30 | 1.11 | 66 | 87 | 247% | RISK | ONESHOT |
| chemist | ideal | 373 | 5.44 | 4.66 | 53 | 69 | 310% | OK | ONESHOT |
| chemist | random | 41 | 0.60 | 0.51 | 53 | 69 | 310% | FAIL | ONESHOT |
| dark_mage | ideal | 678 | 9.88 | 8.46 | 50 | 64 | 324% | OK | ONESHOT |
| dark_mage | random | 99 | 1.45 | 1.24 | 50 | 64 | 324% | RISK | ONESHOT |
| doctor | ideal | 436 | 6.36 | 5.44 | 82 | 109 | 200% | OK | ONESHOT |
| doctor | random | 48 | 0.70 | 0.60 | 82 | 109 | 200% | FAIL | ONESHOT |
| druid | ideal | 677 | 9.87 | 8.44 | 82 | 108 | 200% | OK | ONESHOT |
| druid | random | 46 | 0.67 | 0.57 | 82 | 108 | 200% | FAIL | ONESHOT |
| elementalist | ideal | 455 | 6.64 | 5.68 | 50 | 64 | 324% | OK | ONESHOT |
| elementalist | random | 63 | 0.91 | 0.78 | 50 | 64 | 324% | FAIL | ONESHOT |
| engineer | ideal | 429 | 6.19 | 5.05 | 82 | 107 | 200% | OK | ONESHOT |
| engineer | random | 47 | 0.67 | 0.55 | 82 | 107 | 200% | FAIL | ONESHOT |
| guitarist | ideal | 110 | 1.60 | 1.37 | 66 | 86 | 247% | OK | ONESHOT |
| guitarist | random | 32 | 0.46 | 0.39 | 66 | 86 | 247% | FAIL | ONESHOT |
| knight | ideal | 227 | 3.31 | 2.83 | 154 | 217 | 106% | OK | ONESHOT |
| knight | random | 52 | 0.76 | 0.65 | 154 | 217 | 106% | FAIL | ONESHOT |
| priest | ideal | 272 | 3.93 | 3.33 | 82 | 107 | 200% | OK | ONESHOT |
| priest | random | 30 | 0.43 | 0.36 | 82 | 107 | 200% | FAIL | ONESHOT |
| ranger | ideal | 314 | 4.57 | 3.91 | 67 | 90 | 243% | OK | ONESHOT |
| ranger | random | 57 | 0.82 | 0.71 | 67 | 90 | 243% | FAIL | ONESHOT |
| robot | ideal | 282 | 4.08 | 3.29 | 157 | 221 | 104% | OK | ONESHOT |
| robot | random | 37 | 0.53 | 0.43 | 157 | 221 | 104% | FAIL | ONESHOT |
| sniper | ideal | 309 | 4.51 | 3.86 | 111 | 152 | 148% | OK | ONESHOT |
| sniper | random | 25 | 0.36 | 0.31 | 111 | 152 | 148% | FAIL | ONESHOT |
| soldier | ideal | 622 | 9.07 | 7.76 | 96 | 131 | 170% | OK | ONESHOT |
| soldier | random | 33 | 0.48 | 0.41 | 96 | 131 | 170% | FAIL | ONESHOT |
| thief | ideal | 459 | 6.69 | 5.35 | 66 | 89 | 247% | OK | ONESHOT |
| thief | random | 90 | 1.31 | 1.04 | 66 | 89 | 247% | RISK | ONESHOT |

## Сводка A5 (ideal-билд)

- FAIL: assassin, berserk, biologist, chemist, dark_mage, doctor, druid, elementalist, engineer, guitarist, knight, priest, ranger, robot, sniper, soldier, thief
- RISK: нет
- OK: нет

Оговорки: kit DPS — среднее 3 оружий на болванках (8с, без ульты в full-charge циклах,
без кайта); random-билд ближе к реальному первому прохождению. Ваншот-порог сравнивается
с typical HP (floor×1.45×player_max_hp_mult); уворот/i-frames/absorb смягчают hazard в бою.
