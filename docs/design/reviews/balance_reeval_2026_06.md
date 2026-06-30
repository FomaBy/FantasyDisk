# Balance Re-Evaluation — Measurement & Findings (2026-06)

Jira: SCRUM-780 · Версия: 0.1.8 · Роль: Back-end / balance · Эпик: SCRUM-214
Тип: **read-only замер** (никаких изменений баланс-значений/тестов в этом тикете).
Источник запроса: пользователь — «пересмотреть баланс персонажей: выживаемость, урон, комфорт».

Это гейт-отчёт для трёх дочерних тюнинг-пассов (survivability / damage / comfort).
Все числа — из детерминированных гейтов на `dev`, без `character_balance_csv.gd`
(он флейково падает SIGABRT под нагрузкой — см. backlog-память).

## Метод и прогнанные гейты (все зелёные, Godot 4.7, по одному через семафор)

| Гейт | Результат |
| --- | --- |
| `tools/balance_harness.gd` → `build/balance_report.md` | 51 пара класс/оружие, after-tuning ±0.1% от таргета; raw (mult=1.0) и budget-мультипликаторы |
| `global_damage_balance_smoke_test.gd` | PASS — 51 пара; combined ±25%, solo ±20%, CCT ±30%; **худшее CCT +22% = doctor/restore_potion/20** |
| `global_survivability_balance_smoke_test.gd` | PASS — 16 строк; TTD ≤ 600с, митигация < 98%, бессмертие недостижимо |
| `survivability_scenario_test.gd` | PASS — 16 строк модели; монотонность/слои/absorb/якорь (33.055 == формула) |
| `class_damage_table_3variants_test.gd` | PASS — 17 классов × (best+random) = 153 строки, TTK по волнам 5/10/20 |
| `comfort_band_cross_class_gate.gd` | PASS — срезы 1/5/20t, **spread 1.13x**, 0 нарушений ±20% медианы |
| `berserk_dps_runaway_gate.gd` | PASS — hammer lvl20: 20t=2194 (≤3600), 1t=484 (≤650), есть запас |

**Ключевая методологическая оговорка (наследие SCRUM-176/504-544):** after-tuning
урон сходится к таргету в ±0.1% **по построению** — `ProgressionData.derived_parameters`
домножает урон на авто-выведенный `budget_damage_multiplier` под профиль-таргет. Поэтому
«after-tuning зелёный» НЕ доказывает здоровье идентичностей оружия. Диагностическая
ценность — в **raw-отклонениях (mult=1.0)** и в **самом мультипликаторе** (как далеко
бюджету пришлось тянуть/давить идентичность).

---

## 1. Выживаемость (Survivability)

Метрика — модельный EHP (HP + защита + dodge + слои), `build/balance_report.md`,
колонка EHP. Это единственная ось, которую бюджет урона НЕ нормирует — поэтому
разброс реален.

| Сегмент | Классы (EHP) |
| --- | --- |
| Стекло (floor) | **dark_mage 34.6**, elementalist 50.8, chemist 51.2–58.2 |
| Низ-середина | guitarist 68.0, ranger 68.1, thief 69.2, biologist 69.4–70.7 |
| Середина | druid 83.9, engineer 85.0–88.2, assassin 87.6, priest 87.5–91.1 |
| Крепкие | doctor 94.1–106.9, soldier 103.1–106.0, berserk 120.2, sniper 122.8 |
| Танки (ceiling) | robot 177.0–185.5, **knight 175.7–203.3** |

- **Разброс EHP = 203.3 / 34.6 ≈ 5.9x** — медиана ≈ 88. Это далеко за пределами
  целевого spread-гейта 0.75x–2.0x (= 2.67x). Гейт survivability при этом зелёный
  (TTD ≤ 600с, митигация < 98%) — то есть «играбельно», но кросс-классовая
  живучесть расходится почти в 6 раз.
- **Вне band снизу:** `dark_mage` 34.6 = **0.39x медианы** — даже среди aoe-стекла он
  в ~1.5x хрупче соседей (elementalist/chemist ~50). Гипотеза: dark_mage держит
  одновременно самый высокий 5T-таргет (224 DPS) и самый низкий EHP — двойной перекос
  «гипер-стекло».
- **Вне band сверху:** `knight` (203 / 176 / 184) и `robot` (185 / 179 / 177) =
  **2.0–2.3x медианы**. Танк-архетип ожидаем, но текущий потолок выходит за 2.0x.
- Вампиризм/sustain: после SCRUM-526 оба канала ослаблены (chance-cap 0.20,
  hard-cap 2.0, weapon-drain 0.35) — гейты бессмертия зелёные, отдельного выброса
  по sustain нет.

**Кандидаты на тюнинг (survivability-пасс):** поднять пол dark_mage (34.6 → диапазон
aoe-стекла ~50–55, чтобы не быть 1.5x хрупче равных по роли); приспустить потолок
knight/robot (203/185 → ~165–175) так, чтобы танк ≤ ~1.9x медианы. Цель-band EHP ≈
**[0.6x .. 1.9x] медианы ≈ [53 .. 167]**.

---

## 2. Урон (Damage)

After-tuning все 51 пара в ±0.1% таргета (by construction). Сигнал — в raw-отклонениях
и в budget-мультипликаторе.

### 2a. Cap-pinned идентичности (мультипликатор уперся в потолок 2.800) — хрупкость

~16 из 51 пары тянутся бюджетом на максимуме `2.800`. Это значит: сырое оружие СЛИШКОМ
слабое, и кап едва дотягивает до таргета — нет запаса, любой дрейф вниз уронит пару
ниже band. Список (raw-отклонение solo на mult=1.0):

| Пара | raw solo dev | прим. |
| --- | ---: | --- |
| knight/holy_flail | −75.1% | tank, кап 2.800 |
| knight/tower_shield | −68.8% | tank, кап 2.800 |
| ranger/hunter_trap | −73.3% | solo, кап 2.800 |
| chemist/blast_powder | −57.8% | aoe, кап 2.800 |
| doctor/restore_potion | −57.3% | + худший CCT (см. comfort) |
| dark_mage/dark_book, biologist/symbiote_seed, robot/magnetic_anchor·reactor_core, priest/reliquary·chime, sniper/spotter_scope, elementalist/prism_focus·meteor_core, thief/smoke_bomb, guitarist/bass_guitar, engineer/pressure_mines | −40…−55% | все на капе 2.800 |

### 2b. Raw over-hitters (бюджет ДАВИТ идентичность вниз, mult ≪ 1) — сплющивание

Сырьё бьёт кратно выше таргета, бюджет душит до 0.28–0.62 → идентичность оружия почти
полностью переписывается множителем:

| Пара | raw solo dev | budget mult |
| --- | ---: | ---: |
| druid/summon_amulet | **+2344%** | 0.280 |
| chemist/homunculus_vial | **+719%** | 0.280 |
| doctor/plague_syringe | +207% | 0.566 |
| doctor/bone_saw | +100% | 0.624 |
| assassin/venom_wire | +82% (5T +332%) | 0.357 |
| engineer/sentry_wrench | (5T-перекос) | 0.335 |
| berserk/sword | — | 0.612 |

Это семейство summon/DoT/turret: их «сырой» DPS-замер модели улетает (множитель тиков
/ призывов), поэтому бюджет берёт на себя почти весь баланс. Цена — балансу нечего
«щупать» в самой идентичности.

**Кандидаты на тюнинг (damage-пасс):** свести `budget_damage_multiplier` всех пар в
**[0.5 .. 2.5]** (сейчас 0.28 .. 2.80) — поднять сырьё cap-pinned оружия (knight,
ranger/hunter_trap, chemist/blast_powder, doctor/restore_potion …) и приструнить
модель summon/DoT-over-hitters (druid/summon_amulet, chemist/homunculus_vial,
doctor/plague_syringe) на уровне формулы тиков/призывов, а не множителем. berserk-ось —
в пределах runaway-гейта, тюнинга не требует.

---

## 3. Комфорт игры (Comfort / pacing)

`comfort_band_cross_class_gate`: spread **1.13x** на всех срезах (1/5/20t), 0 нарушений
±20% медианы — кросс-классовый комфорт-DPS здоров. TTK по волнам (`class_damage_table`,
отклонение clear-времени от базовой кривой):

- Когорта нормы: ~+13.1% на 15s-волне (большинство пар).
- **Лаггеры crowd-clear (20 врагов):**

| Пара | dev 20-enemy clear |
| --- | ---: |
| doctor/restore_potion | **+22.0%** |
| druid/summon_amulet | +20.2% |
| chemist/homunculus_vial | +20.1% |
| druid/raven_totem | +20.0% |

Все — heal-гибрид / summon / DoT: одиночную цель добивают по таргету, но эффективный
crowd-DPS отстаёт (медленное растекание по толпе / задержка призыва). Совпадает с
worst-CCT из damage-гейта (doctor/restore_potion/20 +22%).

**Кандидаты на тюнинг (comfort-пасс):** подтянуть crowd-clear лаггеров к когорте +13%
(мелкие AoE/скорость-растекания/таргет-приоритет для summon/heal-гибрид/DoT). Цель:
отклонение 20-enemy clear **≤ +15%** для всех пар. Контроль/таргетинг summon-классов
(druid/engineer/biologist) — отдельная под-проверка читаемости в comfort-пассе.

---

## Сводная таблица выбросов

| Класс/пара | Ось | Метрика (before) | Целевой band |
| --- | --- | --- | --- |
| dark_mage | survivability | EHP 34.6 (0.39x медианы) | ≥ ~50 (aoe-стекло) |
| knight | survivability | EHP 175–203 (2.0–2.3x) | ≤ ~167 (~1.9x) |
| robot | survivability | EHP 177–185 (2.1x) | ≤ ~167 |
| knight/holy_flail·tower_shield | damage | budget mult 2.800 (кап) | mult ≤ 2.5 |
| ranger/hunter_trap, chemist/blast_powder, doctor/restore_potion (+13 пар на капе) | damage | budget mult 2.800 | mult ≤ 2.5 |
| druid/summon_amulet | damage | raw +2344%, mult 0.280 | mult ≥ 0.5 (правка формулы призыва) |
| chemist/homunculus_vial | damage | raw +719%, mult 0.280 | mult ≥ 0.5 |
| doctor/plague_syringe, bone_saw; assassin/venom_wire; engineer/sentry_wrench | damage | mult 0.33–0.62 | mult ∈ [0.5..2.5] |
| doctor/restore_potion | comfort | 20-clear +22.0% | ≤ +15% |
| druid/summon_amulet·raven_totem, chemist/homunculus_vial | comfort | 20-clear +20% | ≤ +15% |

---

## Приоритизированный backlog для дочерних задач

**P1 — Survivability-пасс** (узкий, измеримый):
1. dark_mage EHP-floor 34.6 → ~50–55 (диапазон aoe-стекла), не теряя «стеклянность».
2. knight/robot потолок 203/185 → ~165–175 (танк ≤ ~1.9x медианы).
3. Цель-гейт: EHP-spread свести к ≤ ~3x (с 5.9x), все классы в [0.6x..1.9x] медианы.

**P1 — Damage-пасс** (структурный, риск slice-зависимости):
1. Снять cap-pinned хрупкость: поднять сырьё ~16 пар на капе 2.800 так, чтобы
   `budget_damage_multiplier ≤ 2.5` (запас вниз).
2. Усмирить summon/DoT over-hitters в самой формуле (тики/призывы), а не множителем →
   `mult ≥ 0.5`; цель: все пары в `mult ∈ [0.5..2.5]`.
3. Проверять ре-нормировку в Python + `balance_harness.gd` (НЕ `character_balance_csv.gd`).

**P2 — Comfort-пасс** (наименее острый, comfort-band уже 1.13x):
1. Подтянуть crowd-clear 4 лаггеров (doctor/restore_potion, druid summon/raven,
   chemist/homunculus_vial) к +13% когорте → ≤ +15% на 20-enemy.
2. Аудит читаемости таргетинга/контроля summon-классов.

**Зависимости/риски:** damage-пасс — самый рисковый (slice-зависимые выбросы, как
отмечено в SCRUM-504/505/506/544); вести по одной паре с проверкой всех шести гейтов
после каждой правки. Survivability-пасс — наиболее изолированный, можно стартовать первым.
