# Class-trio таблица (FAN-1028, живой слой lvl20_ideal) — ФИНАЛЬНАЯ приёмка v9

Скоры = метрика класса / медиана ростера. Модель осей — class-balance-model.md;
медианы ростера: solo 747, aoe(5t) 2632, crowd(20t) 8788, EHP 85.
Коридор kit-total: ideal ±8%, review ±12%, fail ±15% (roster-relative).

| Класс | Solo | AoE | Crowd | Defense | **Total** | Вердикт | Мёртвые слоты |
| --- | ---: | ---: | ---: | ---: | ---: | :---: | --- |
| priest | 0.80 | 1.27 | 1.76 | 1.01 | **1.21** | FAIL+ | — |
| robot | 0.77 | 0.87 | 1.00 | 2.12 | **1.19** | FAIL+ | — |
| soldier | 1.44 | 1.00 | 1.08 | 1.22 | **1.19** | FAIL+ | — |
| engineer | 1.66 | 0.99 | 0.92 | 1.00 | **1.14** | FAIL | — |
| knight | 0.77 | 0.58 | 0.91 | 2.21 | **1.12** | FAIL | — |
| chemist | 0.99 | 1.67 | 1.16 | 0.63 | **1.11** | review | — |
| berserk | 0.94 | 1.05 | 1.03 | 1.41 | **1.11** | review | — |
| thief | 1.55 | 1.11 | 0.94 | 0.81 | **1.10** | review | — |
| elementalist | 1.02 | 1.18 | 1.57 | 0.60 | **1.09** | review | — |
| doctor | 1.56 | 0.85 | 0.83 | 1.09 | **1.08** | review | — |
| dark_mage | 1.00 | 1.52 | 1.15 | 0.59 | **1.06** | ideal | — |
| druid | 0.93 | 1.24 | 1.00 | 0.99 | **1.04** | ideal | — |
| sniper | 1.11 | 0.90 | 0.66 | 1.45 | **1.03** | ideal | — |
| assassin | 1.79 | 0.74 | 0.34 | 1.03 | **0.98** | ideal | — |
| ranger | 1.13 | 1.05 | 0.65 | 0.80 | **0.90** | review | — |
| biologist | 0.95 | 0.94 | 0.85 | 0.82 | **0.89** | review | — |
| guitarist | 0.65 | 0.85 | 1.18 | 0.80 | **0.87** | FAIL | — |

## Пер-оружейные выбросы (ideal, множитель к медиане ростера по оси)

| Класс/оружие | Solo × | AoE × | Crowd × | Заметка |
| --- | ---: | ---: | ---: | --- |
| engineer/engineer_sentry_wrench | 3.94 | 1.54 | 0.56 | runaway-ось |
| elementalist/elementalist_prism_focus | 1.74 | 1.94 | 3.56 | runaway-ось |
| chemist/blast_powder | 1.71 | 3.56 | 1.73 | runaway-ось |
