# Encounter Beat Director — foundation + `marked_target` slice (FAN-1447)

Контракт: **encounter-beats-v1**. Пакет вводит один data-driven «бит» боя на
нормальном бою и первый vertical slice `marked_target`, НЕ создавая второй
wave/spawn-цикл. Всё живёт в изолированном пакете `scripts/encounters/**` +
`data/encounters/**`; в существующий `CombatDirector` добавлен ровно один узкий
адаптер.

## Что такое «бит»

Бит — самодостаточный сценарный момент внутри уже существующего боевого
lifecycle: он детерминированно планируется от seed узла, срабатывает в своём окне,
ведёт цель/презентацию и отдаёт outcome в метрики. Бит НЕ спавнит волны и не
трогает баланс: `marked_target` только помечает уже живого рядового врага.

## Архитектура пакета

| Файл | Роль |
| --- | --- |
| `data/encounters/beats.json` | Каталог битов: id, eligibility, окно триггера, seed salt, теги, payload, success/failure, metrics-теги. `enabled=false` (default-off). |
| `scripts/encounters/encounter_config.gd` | Загрузка каталога, `is_enabled()` + in-memory override (тест/QA), sorted-by-id discovery. |
| `scripts/encounters/encounter_feature.gd` | Versioned базовый контракт `EncounterFeature` (API v1) + билдер outcome. |
| `scripts/encounters/encounter_context.gd` | Versioned read-обёртка боя (враги/игрок/время + `aspect_rng`). |
| `scripts/encounters/encounter_metrics.gd` | Локальные in-memory метрики + детерминированный JSON-экспорт. |
| `scripts/encounters/encounter_beat_director.gd` | Узел-двигатель: discovery → план одного primary-бита → trigger/tick/resolve → очистка. |
| `scripts/encounters/encounter_adapter.gd` | Адаптер: держит директора текущего боя, отдаёт наружу только `begin()`/`shutdown()`. |
| `scripts/encounters/features/marked_target_feature.gd` | Первый бит: маркер над целью + HUD-таймер + success/failure. |
| `scripts/combat_director.gd` | Тонкая сцепка: preload + поле + два вызова (+7 строк). |

## Versioned API (v1)

Lifecycle, который гарантирует директор:

```
plan(context, beat_def)        -> {trigger_at, window} | {}
on_trigger(context, beat_def)  -> bool          # true = бит реально стартовал
on_tick(context, delta)        -> void          # каждый НЕ-паузный кадр
is_resolved()                  -> bool
resolve(context, reason)       -> outcome        # + освобождение всех узлов
```

`outcome` (schema v1): `beat_id, status(completed|failed|aborted), duration,
damage_to_target, player_died, reason`.

## Детерминизм и seed

Момент триггера и выбор цели берутся из **независимого** генератора
`game.node_aspect_rng(current_node_seed, salt)` — той же фабрики, что уже питает
`node_elite_scene` / `node_background_path`. Глобальный боевой `game.rng` НЕ
расходуется, поэтому:

- одинаковый seed узла → тот же бит и тот же момент;
- другой seed → свой момент, но спавн-детерминизм маршрута не сдвигается;
- каждый бит имеет свою `seed_salt`; выбор цели домешивает вторую соль.

## Интеграция в CombatDirector (адаптер)

`scripts/combat_director.gd` держит ratchet 1500 строк
(`tools/quality_static_guard.py`), поэтому логика адаптера вынесена в
`scripts/encounters/encounter_adapter.gd`, а в боевом цикле осталось +7 строк:
preload, поле `_encounters` и два вызова.

1. `_finalize_combat_start()` → `_encounters.begin(game, self)` — создаёт
   директора (узел-ребёнок Main, `process_mode = PAUSABLE`) и планирует один
   primary-бит. Первым делом снимает протёкшего директора прошлого боя.
2. `_end_combat(victory)` → `_encounters.shutdown(victory)` — терминальная
   очистка ДО `_clear_world`/`_clear_hud`: снимаются маркеры, твины, колбэки;
   пишутся метрики исхода и death-флаг.

Новые биты подключаются **только данными**: запись в `beats.json` (id + путь к
скрипту-фиче). Ни директор, ни адаптер при этом не редактируются.

## Пауза, level-up, молитва, cleanup

Директор — узел с `PROCESS_MODE_PAUSABLE`, поэтому его `_process` и все дети-
маркеры замерзают ровно тогда же, когда `get_tree().paused=true` (пауза, level-up,
молитва, досье, фидбек) — как и боевой `_process` Main. Отдельной pause-логики
нет. Молитва вдобавок выбирается ДО `_finalize_combat_start`, так что бит даже не
стартует до её выбора. Смерть/конец боя → `resolve` фичи освобождает маркер, HUD-
таймер, убивает твин и отключает `died`-колбэк; узел директора `queue_free`.

## Default-off parity

`enabled=false` в каталоге — адаптер не создаёт директора, бой байт-идентичен
baseline (проверено `beat_marked_target_runtime_test` и регрессией
`runtime_smoke_combat_test`). Тест/QA включают через
`EncounterConfig.set_enabled_override(true)` — состояние только в памяти, без сети.

## Метрики (локально, без сети)

Считаются `offered / triggered / completed / failed / aborted` и per-beat записи
`duration / damage_to_target / player_died / reason`. Экспорт —
`EncounterMetrics.export_json()` (sort_keys, детерминирован). Снапшот последнего
боя дублируется в `EncounterMetrics.last_summary` для QA. Никакого
feedback/network pipeline не задействовано.

## `marked_target` (первый slice)

На 20–40 секунде нормального боя помечается один живой рядовой враг (не элитка/
мини-элитка/босс): пульсирующее кольцо-маркер следует за целью + экранный HUD-
отсчёт окна (10 c). Успех — цель убита в окне (`completed`, урон = стартовый HP);
провал — окно вышло или цель потеряна (`failed`). Idempotent: терминал считается
один раз.

## Запуск тестов (важно для QA)

С FAN-1675 (`discover tests recursively`) `tools/quality_gate.py` находит
`tests/encounters/beat_*` автоматически, поэтому штатный прогон — обычный gate:

```
python3 tools/quality_gate.py beat_       # только биты
python3 tools/quality_gate.py --profile full
```

Точечно (тот же результат, минуя static-проверки):

```
python3 tools/godot_gate.py --headless --path . --script res://tests/encounters/beat_director_determinism_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/encounters/beat_director_lifecycle_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/encounters/beat_marked_target_runtime_test.gd
```

Каждый печатает `... passed.` и завершается с кодом 0; SCRIPT ERROR-ов быть не
должно.

## Соответствие acceptance criteria

1. Тот же seed → тот же бит/момент; другой seed не рушит route determinism —
   `beat_director_determinism_test`.
2. ≤1 primary-бит на нормальный бой; boss/elite/event исключены —
   `beat_director_lifecycle` (D), `beat_marked_target_runtime`.
3. Пауза/level-up/молитва замораживают бит (PAUSABLE); смерть/конец очищают
   targets/UI/tweens/callbacks — `beat_director_lifecycle` (C, E), адаптер.
4. Без активного бита бой = baseline — default-off parity + регрессия
   `runtime_smoke_combat_test`.
5. Метрики trigger/offered/completed/failed/duration/damage/death без сети —
   `EncounterMetrics`, проверено в lifecycle-тесте.
6. Focused deterministic/pause/cleanup/isolation/runtime тесты PASS; docs — этот
   файл.
