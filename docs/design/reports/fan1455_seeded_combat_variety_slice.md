## Решение

**Go with risks** для независимой exact-SHA QA по FAN-2220. Интеграция в `dev`
до `PASSED` и отдельной DevOps-карточки запрещена.

Slice `combat_variety_slice` production-включён только на одном
детерминированно выбранном normal battle node маршрута. Все остальные бои
сохраняют default-off каталог и прежний planner с одним primary beat.

## Состав slice

1. `normal_decks` выбирает одну из пяти wave-композиций из node seed.
2. `marked_target` задаёт первую явную смену приоритета цели.
3. Из того же seed выбирается ровно один `captain_commander` или
   `captain_hunter`.
4. `next_phase_contract` предлагает принять или отклонить проклятый контракт.
5. `reward_carrier` добавляет опциональную цель с идемпотентной наградой.
6. `normal_early_clear` завершает бой только после quota и обязательной обычной
   цели.
7. Aim contract сохраняет настройку игрока и поддерживает manual mouse и
   right-stick providers.

Primary-фазы сериализованы. Следующая планируется только после `resolve`
предыдущей; runtime-инструментация и тест подтверждают максимум один активный
primary и ровно пять outcome-записей. Глобальный `game.rng` не расходуется.

## Детерминированные данные

Артефакт `fan1455_seeded_combat_variety_slice_metrics.json` воспроизводится
byte-for-byte из живого `ProgressionData` и seed-набора `1455001..1455017`.

| Проверка | Baseline | Slice | Gate |
| --- | ---: | ---: | ---: |
| Completion contract projection, 17 классов × 17 seeds | 1.0 | 1.0 | 1.0 |
| Deaths в lifecycle contract | 0 | 0 | 0 |
| Class-kit damage spread | 0.000671 | 0.000671 | ≤ 0.08 |
| Melee/ranged/summon completion | 1.0 | 1.0 | 1.0 |

Каждая class-строка рассчитана по всем трём оружиям. Slice не меняет weapon,
damage или survivability формулы, поэтому baseline и slice damage ratio обязаны
совпадать; это проверяется вместе с глобальными 51 weapon-pair и 153
weapon-build gates.

Decision evidence не сводится к HP или оформлению:

- все пять deck id и обе captain-роли встречаются в seed-матрице;
- 14 из 17 seeds выбирают marked target не ближайшим в исходном
  nearest-first порядке;
- каждый seed создаёт три явных target-priority prompt: mark, captain и carrier
  (51 prompt суммарно);
- special-node marker отличается от контрольной позиции в 8 из 17 seeds;
- questionnaire рядом фиксирует A/B route-choice и target-priority ответы для
  независимого интерактивного прогона без подмены автоматических данных.

## Lifecycle и совместимость

- Slice загружается через fail-closed allowlist в `EncounterConfig`, затем
  выбирается из сохранённого route node и передаётся production-адаптером.
- JSON integral seeds канонизируются только после проверки, что значение
  конечное и не имеет дробной части; identity/script/capability overrides
  запрещены.
- Route marker, выбранные ветки и node seed проходят атомарный
  save/load/Continue round-trip без нового формата autosave.
- Director и presentation nodes остаются `PAUSABLE`; принятые death cleanup,
  timer fallback, reward idempotency и early-clear/combat-end race контракты
  повторно проходят без правки pack internals.
- Обычный каталог остаётся `enabled=false`; production-код не вызывает
  `set_enabled_override`.

## Проверки

- `combat_variety_slice_test.gd`: PASS, включая 512-seed deck/captain scan,
  production config/adapter route, five-phase lifecycle, one-active-primary,
  reward/end race, Continue и metrics reproduction.
- 16 focused encounter/input/autosave regressions: PASS.
- `balance_harness.gd`: PASS; отчёты сгенерированы локально.
- `global_damage_balance_smoke_test.gd`: PASS, 51 пара.
- `global_survivability_balance_smoke_test.gd`: PASS, 16 строк.
- `class_damage_table_3variants_test.gd`: PASS, 17 классов и 153 строки.
- `quality_static_guard.py`: PASS.

## Остаточный риск

Completion/death evidence — детерминированная budget projection плюс реальный
feature lifecycle contract, а не длительная человеческая игровая сессия.
Читаемость выбора маршрута и HUD следует подтвердить независимой QA по
приложенному questionnaire. Поэтому verdict остаётся **Go with risks**, а не
безусловный Go.
