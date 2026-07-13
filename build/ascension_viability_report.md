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
| assassin | ideal | 470 | 6.85 | 5.86 | 82 | 113 | 200% | OK | ONESHOT |
| assassin | random | 62 | 0.90 | 0.77 | 82 | 113 | 200% | FAIL | ONESHOT |
| berserk | ideal | 353 | 5.15 | 4.41 | 111 | 151 | 148% | OK | ONESHOT |
| berserk | random | 73 | 1.06 | 0.91 | 111 | 151 | 148% | FAIL | ONESHOT |
| biologist | ideal | 284 | 4.10 | 3.51 | 66 | 87 | 247% | OK | ONESHOT |
| biologist | random | 85 | 1.22 | 1.05 | 66 | 87 | 247% | RISK | ONESHOT |
| chemist | ideal | 365 | 5.33 | 4.56 | 53 | 69 | 310% | OK | ONESHOT |
| chemist | random | 42 | 0.61 | 0.53 | 53 | 69 | 310% | FAIL | ONESHOT |
| dark_mage | ideal | 505 | 7.36 | 6.30 | 50 | 64 | 324% | OK | ONESHOT |
| dark_mage | random | 102 | 1.48 | 1.27 | 50 | 64 | 324% | OK | ONESHOT |
| doctor | ideal | 432 | 6.30 | 5.39 | 82 | 109 | 200% | OK | ONESHOT |
| doctor | random | 44 | 0.64 | 0.55 | 82 | 109 | 200% | FAIL | ONESHOT |
| druid | ideal | 1031 | 15.02 | 12.86 | 82 | 108 | 200% | OK | ONESHOT |
| druid | random | 38 | 0.56 | 0.48 | 82 | 108 | 200% | FAIL | ONESHOT |
| elementalist | ideal | 454 | 6.62 | 5.67 | 50 | 64 | 324% | OK | ONESHOT |
| elementalist | random | 58 | 0.85 | 0.73 | 50 | 64 | 324% | FAIL | ONESHOT |
| engineer | ideal | 403 | 5.82 | 4.74 | 82 | 107 | 200% | OK | ONESHOT |
| engineer | random | 54 | 0.77 | 0.63 | 82 | 107 | 200% | FAIL | ONESHOT |
| guitarist | ideal | 113 | 1.65 | 1.42 | 66 | 86 | 247% | OK | ONESHOT |
| guitarist | random | 30 | 0.44 | 0.38 | 66 | 86 | 247% | FAIL | ONESHOT |
| knight | ideal | 233 | 3.40 | 2.91 | 154 | 217 | 106% | OK | ONESHOT |
| knight | random | 35 | 0.52 | 0.44 | 154 | 217 | 106% | FAIL | ONESHOT |
| priest | ideal | 256 | 3.69 | 3.13 | 82 | 107 | 200% | OK | ONESHOT |
| priest | random | 31 | 0.45 | 0.38 | 82 | 107 | 200% | FAIL | ONESHOT |
| ranger | ideal | 379 | 5.52 | 4.73 | 67 | 90 | 243% | OK | ONESHOT |
| ranger | random | 44 | 0.65 | 0.55 | 67 | 90 | 243% | FAIL | ONESHOT |
| robot | ideal | 294 | 4.25 | 3.43 | 157 | 221 | 104% | OK | ONESHOT |
| robot | random | 31 | 0.44 | 0.36 | 157 | 221 | 104% | FAIL | ONESHOT |
| sniper | ideal | 251 | 3.66 | 3.13 | 111 | 152 | 148% | OK | ONESHOT |
| sniper | random | 22 | 0.33 | 0.28 | 111 | 152 | 148% | FAIL | ONESHOT |
| soldier | ideal | 637 | 9.29 | 7.95 | 96 | 131 | 170% | OK | ONESHOT |
| soldier | random | 41 | 0.60 | 0.51 | 96 | 131 | 170% | FAIL | ONESHOT |
| thief | ideal | 398 | 5.80 | 4.64 | 66 | 89 | 247% | OK | ONESHOT |
| thief | random | 82 | 1.20 | 0.96 | 66 | 89 | 247% | FAIL | ONESHOT |

## Сводка A5 (ideal-билд)

- FAIL: assassin, berserk, biologist, chemist, dark_mage, doctor, druid, elementalist, engineer, guitarist, knight, priest, ranger, robot, sniper, soldier, thief
- RISK: нет
- OK: нет

Оговорки: kit DPS — среднее 3 оружий на болванках (8с, без ульты в full-charge циклах,
без кайта); random-билд ближе к реальному первому прохождению. Ваншот-порог сравнивается
с typical HP (floor×1.45×player_max_hp_mult); уворот/i-frames/absorb смягчают hazard в бою.
