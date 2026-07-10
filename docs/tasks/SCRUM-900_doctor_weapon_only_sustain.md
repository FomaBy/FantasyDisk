# SCRUM-900 — Doctor: weapon-only sustain and redesign Restore Potion, Plague Syringe, Bone Saw

Статус: done
Дата: 2026-07-10
Исполнитель: claude-w17-doctor (backend lane)
Ключевые коммиты: см. `git log --grep=SCRUM-900` (trait+kit, smoke-контракт, evidence/доки)

## Что сделано

### Trait «Клятва чумного доктора» (plague_oath)

Data-driven запись `CLASS_TRAITS.doctor` (`generic_sustain_blocked: 1.0`,
`scripts/progression_data_characters.gd`). Четыре точки отсечки generic-сустейна:

1. **Пул наград** — `ProgressionData.is_reward_relevant()` (trait-гейт вместо
   хардкода класса, SCRUM-862 реестр `DOCTOR_FORBIDDEN_SUSTAIN_*` сохранён):
   level-up/артефакты/боссы/буны не предлагают Доктору regen/vampirism/
   kill-heal/room-clear/low-HP regen/прямые heal-награды. Пометка
   `doctor_friendly: true` на предмете пропускает его в пул.
2. **Применение** — `Player._apply_reward_mods` и `apply_meta_skill_modifiers`
   молча гасят запрещённые ключи (`ProgressionData.is_blocked_sustain_mod_key`)
   для не-friendly наград: даже принудительно применённая награда/мета-звезда
   регена/вампиризма — задокументированный no-op. `apply_reward.heal_percent`
   гасится там же.
3. **Формула** — `derived_parameters` через `_class_gated_regeneration` отрезает
   БАЗОВЫЙ пассивный реген (константа 0.16 + knowledge-скейл): без friendly-flat
   реген Доктора ровно 0; friendly-flat работает штатной формулой.
4. **Рантайм-страховка** — `_apply_regeneration` не добавляет
   `lowhp_regen_bonus` («Второе Дыхание») классу с trait'ом.

Route/rest/shop-лечение вне `apply_reward` (аптечки-пикапы, отдых) сознательно
НЕ блокируется — отсекается комбат/билд-сустейн (решение по тикету
задокументировано в systems/progression_balance.md).

Сопутствующий фикс: `configure_character` теперь кладёт `character_id` в
`weapon_config` даже до экипировки оружия — class-gated формулы работают и в
безоружном окне (раньше derived не знал класс).

### Оружие (все лечат ТОЛЬКО от фактически нанесённого урона через
`_heal_owner_from_damage` → `apply_drain_heal`, per-second бюджет SCRUM-517)

| Оружие | Было | Стало (SCRUM-900) |
| --- | --- | --- |
| restore_potion | drain_link луч 1.05с, хил 34% | **aoe_projectile**: бросок зелья, магический взрыв 150r / 1.15с, projectile 620, хил **16%**; промах = 0 хила; физического урона нет |
| plague_syringe | drain_link + dot 6 тиков, хил 26% | **plague_dart**: дротик 760, прямой укол + зараза **24с** (коридор 20-30с), тик = magic×0.22 + dot×0.6, интервал 2.0/dot_speed, ramp 0.45→1.0 за 5 тиков, **спред 22%/тик** на ближайшего незаражённого в радиусе 200, **кап 10 зараз**, рефреш без стака, хил **12%** |
| bone_saw | stab_flurry 2 цели, хил 18%+0.2%/hit | **saw_sector**: melee-сектор **135°** (коридор 120-150) дальностью **215**, физ. урон + скорость атаки, мультихит всех в дуге с диминишем 0.72 сверх 4 целей, close-bonus 110/×1.12, хил **34%** — сильнейший в ките |

Иерархия сустейна: пила 34% > зелье 16% > чума 12% (соответствие AC).
Позиционный риск пилы: фланг (~80° от оси) и спина не бьются и не лечат —
покрыто геометрическими ассертами теста.

SCRUM-961 артефакты Доктора перевешаны на новый кит: `saw_heal_ratio_bonus` →
saw_sector, `saw_arc_width_mult` → ширина дуги сектора, `restore_vapor_power` →
взрыв зелья, мета-ветка `drain_extra_targets` → дополнительные чумные дротики
по соседям первичной цели; `triage_heal_burst`/`medkit_healing_mult` — без
изменений (mode-agnostic, канал apply_drain_heal).

Budget-модель честная: `plague_tick_profile` — единый профиль чумы для боя и
тюнинга; hit-модели `saw_sector`/`plague_dart`; plague-ветка `_budget_dot_dps`
(steady-state, независим от fire_interval). Сцены синхронизированы с конфигами,
residual-ключи старого кита вычищены (`heal_percent_on_attack`, `dot_ticks`,
`wave_width`, `projectile_count` — урок SCRUM-898).

## Баланс: before / after (base stats, lvl1)

Профиль класса: balanced/tank, damage_budget 0.85 → таргеты solo 40.8 / aoe 127.5.

| Оружие | mult до | mult после | raw solo до→после | raw aoe до→после | CCT 5t до→после | CCT 20t до→после |
| --- | --- | --- | --- | --- | --- | --- |
| restore_potion | **2.800 (кламп!)** | 1.170 | 15.9→43.0 | 32.7→88.4 | 3.5с (+10.9%)→3.0с (−3.8%) | 15.3с (+22.0%)→13.4с (+6.6%) |
| plague_syringe | 0.566 | 1.507 | 125.4→39.9 | 129.5→57.4 | 3.5с (+10.9%)→3.1с (0.0%) | 15.3с (+21.9%)→13.9с (+10.8%) |
| bone_saw | 0.624 | 1.081 | 81.7→39.3 | 163.6→113.4 | 3.2с (+2.1%)→3.2с (+2.1%) | 14.2с (+13.1%)→14.2с (+13.1%) |

Все три тюнинга ушли из вырожденных зон (кламп 2.8 у зелья, сильное гашение у
чумы/пилы) в коридор 1.08-1.51; кит целиком ближе к целевым CCT, чем до
редизайна. Полные таблицы: `build/balance_report.md` (после), базлайн-снимок —
в сессии воркера.

## Survivability / сустейн-оси

- **Solo сустейн** (heal/s при таргет-DPS, ×0.35 drain-мульт): пила ≈ 4.9 hp/s >
  зелье ≈ 2.3 hp/s > чума ≈ 1.7 hp/s — иерархия AC выполнена и на live-оси.
- **5t/20t/full-map**: сырое лечение пилы/зелья в толпе (≈15/7 hp/s) и чумы при
  10 заражённых упирается в drain-бюджет **7 hp/s** (hard cap 11) — «бессмертие
  от полного заражения карты» недостижимо; подтверждено ассертом теста
  (второй залп сверх бюджета лечит на 0) и глобальным гейтом
  global_survivability (mitigated − regen > floor во всех 16 строках).
- **Отрезанный generic-сустейн**: базовый пассивный реген Доктора 0.179 hp/s →
  0 (компенсирован силой оружейного хила); regen/vamp/kill-heal/room-clear/
  lowhp-билды на Докторе — no-op (тест: та же награда лечит Рейнджера и не
  лечит Доктора).
- **Surrounded side/back pressure**: сектор пилы 135° покрывает 37.5% направлений —
  при окружении хил падает до зелья/чумы, фланг и спина не лечат
  (геометрические ассерты + melee-вход без лечения сзади). EHP-модель кита:
  106.9/99.0/94.1 → 94.0/87.8/95.5 (уход базового регена из модели, tank-профиль
  сохранён, все PASS).

## Тесты (все зелёные)

- `tests/doctor_kit_test.gd` (новый): trait-реестр/пулы; no-op регена/вампиризма/
  триггерных хилов/меты/heal_percent на Докторе + контроль на Рейнджере;
  doctor_friendly пропуск (пул + применение + фактический хил); зелье (AoE-урон,
  хил = 16% фактического, промах = 0); чума (коридор 20-30с, ramp, хил 12% тика,
  спред 1.0/0.0, радиус, кап зараз, рефреш без дубля, cleanup); пила (геометрия
  135°: фронт/грань бьются, фланг 80°/спина/за дальностью — нет; диминиш 6 целей;
  хил 34%; live-иерархия хила); анти-бессмертие (drain-бюджет на реальном Player).
- `weapon_tuning_application_test` — 51 пара PASS.
- `weapon_integrity_test` — 17 классов / 51 оружие PASS (сцены синхронны, residual нет).
- `damage_type_isolation_test` — PASS (зелье/чума — magic, пила — physical, DoT — knowledge).
- `global_survivability_balance_smoke_test` — 16 строк PASS.
- `runtime_smoke_test` — PASS; identity-контракт Доктора обновлён под новый кит
  (3 уникальных режима + live sustain-чек пилой) — продуктовый таргет изменён
  самим тикетом.

## Доки

- `docs/design/class_traits_registry.md` — doctor: implemented + сводка точек.
- `docs/design/systems/characters_weapons.md` — identity класса и матрица оружий.
- `docs/design/systems/progression_balance.md` — sustain-исключения и точки отсечки.
- `docs/design/current_game_state.md` — секция SCRUM-900.
- Описания в данных: `CHARACTER_CONFIGS.doctor`, `CLASS_MECHANIC_IDENTITIES.doctor`,
  descriptions трёх оружий (тултипы/кодекс тянут отсюда).

## QA-заметки

- Регрес-риск: чужие классы не затронуты (trait-гейты читают
  `generic_sustain_blocked`, у остальных классов флага нет; контроль-ассерты на
  Рейнджере в тесте).
- Известный шум: headless-капчер `Parameter "t" is null` в runtime_smoke —
  не блокер (windowed-капчер для визуальной приёмки).
- Плейтест-фокус по AC: regen/vamp апгрейды не должны появляться в level-up
  Доктора; зелье лечит только при попадании; чума видимо перескакивает и лечит
  помалу; пила заметно лечит при фронт-клире и НЕ спасает при окружении.
