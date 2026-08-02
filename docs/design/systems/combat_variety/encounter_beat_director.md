# Encounter Feature foundation + `marked_target` slice (FAN-1447, FAN-2022)

Контракт: **encounter-beats-v1**. Пакет вводит один data-driven «бит» боя на
нормальном бою и первый vertical slice `marked_target`. FAN-2022 расширяет этот
же контракт общими default-off seams для внешних feature definitions,
канонического spawn plan, wave quota и act-scoped state. Всё живёт в
изолированном пакете `scripts/encounters/**` + `data/encounters/**`; feature-код
не получает приватный API `CombatDirector`.

## Что такое «бит»

Бит — самодостаточный сценарный момент внутри уже существующего боевого
lifecycle: он детерминированно планируется от seed узла, срабатывает в своём окне,
ведёт цель/презентацию и отдаёт outcome в метрики. Production-бит
`marked_target` НЕ спавнит волны и не трогает баланс: он только помечает уже
живого рядового врага. Отдельные feature-пакеты могут объявить capability
`spawn_plan`, но исполняются только через общий ограниченный context.

## Архитектура пакета

| Файл | Роль |
| --- | --- |
| `data/encounters/beats.json` | Корневой registry `encounter-beats-v1`: default-off gate, built-in definitions и allowlisted `feature_roots`. |
| `scripts/encounters/encounter_config.gd` | Строгая schema/type/path/resource validation, duplicate quarantine, recursive `*.feature.json` discovery и sorted immutable reads. |
| `scripts/encounters/encounter_feature.gd` | Versioned `EncounterFeature` API v1, optional spawn-plan builder, outcome и act-state normalization. |
| `scripts/encounters/encounter_context.gd` | Узкий context: read API боя, `combat` для нативных терминалов, `aspect_rng`, canonical spawn-plan executor, quota marker и atomic act-state checkpoint. |
| `scripts/encounters/encounter_metrics.gd` | Локальные in-memory метрики + детерминированный JSON-экспорт. |
| `scripts/encounters/encounter_beat_director.gd` | Узел-двигатель: discovery → план одного primary-бита → trigger/tick/resolve → очистка. |
| `scripts/encounters/encounter_adapter.gd` | Адаптер: lifecycle директора и read-only live/route spawn-plan projections. |
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

## Registry contract и fail-closed discovery (FAN-2022)

Корень обязан иметь `schema_version=1`, `contract=encounter-beats-v1` и
`beats`-массив. Definition обязана иметь `schema_version=1`,
`type=encounter_feature`, валидный `snake_case id`, boolean `enabled/primary`,
известные capabilities и существующий script строго внутри
`res://scripts/encounters/features/*.gd`. Внешние packs читаются только из
allowlisted `feature_roots` и только из файлов `*.feature.json`.

Discovery сортируется по пути, затем по id. Если id повторён, неизвестен type или
capability, schema/тип поля повреждены, script вышел за allowlist либо ресурс не
существует, запись отбрасывается. При duplicate отбрасываются все definitions с
этим id: порядок файлов не может выбрать победителя. Возвращаемые Dictionary и
Array — deep copies. Общий `enabled=false` остаётся production default-off gate;
внутренний `enabled=true` лишь делает корректную запись доступной после включения
общего gate.

### Runtime identity: type проверяется, id принадлежит registry

При инстанцировании директор сверяет только `definition_type()` — единственную
runtime-идентичность, общую для всех features. `id` берётся из записи каталога,
потому что один pack-скрипт легально обслуживает несколько definitions и биндит
свою роль из переданного `beat_def` (см. captain-роли ниже). По этому же id
ключуются метрики, act-state и canonical spawn plan.

### Совместимость `captain-wave-roles-v1` (FAN-2040)

Пакет `data/encounters/features/captains/captains.json` мигрирован под
EncounterFeature API v1: каждая роль несёт `schema_version=1`,
`type=encounter_feature`, boolean `enabled` и `capabilities=["primary_beat"]`
рядом с прежними `role`, `primary`, `script`, `trigger_window`, `seed_salt`,
тегами и `payload`. Контракт `captain-wave-roles-v1` и семантика ролей не
менялись — добавлены только registry-поля, которых требует строгая validation.

Per-role `enabled=true` — это registry availability, а НЕ активация: боевой gate
пакета остаётся pack-level `enabled=false`, который читает
`CaptainCatalog.is_enabled()` и проверяет `captain_feature.is_eligible()`.
Валидная роль обязана оставаться в `all_features()`, `enabled_features()` и
`primary_beats()`; malformed или unknown definition по-прежнему fail closed и
отбрасывается целиком.

### Consumer contract `context.combat`

`EncounterContext.combat` — живой `CombatDirector` боя, который директор
проставляет в `begin()`. Feature использует его только для нативных терминалов
(`normal_early_clear` зовёт `context.combat.call_deferred("_end_combat", true)`),
а не для чтения боевого состояния — для чтения существует остальной context.
Снятие этого поля ломает early-clear на рантайме: victory-путь становится
недостижим. Поле обязано существовать и быть проводимым.

## Canonical spawn plan и route/combat parity

Feature с capability `spawn_plan` возвращает только data request. Context
принимает schema v1 и валидирует normal battle, stage range, active cap, safe
radius не меньше `420`, не более 8 entries, count `1..8` на entry и `24` всего,
а также scene against существующего ordinary-enemy allowlist. Результат
канонизируется и включает `node_seed`, stage, sorted entries, total count и
`threat_scene`. Несколько подходящих planners fail closed вместо stacking.

Route preview и live combat получают deep-copy projection одного и того же
builder-а. Исполнение доступно feature только как injected `Callable` через
`EncounterContext.execute_spawn_plan()`; приватные методы `CombatDirector` не
передаются. `CombatDirector.spawn_encounter_plan()` повторно сверяет plan с
текущей projection, normal battle, cap/quota и использует существующий ordinary
spawn path. При выключенном gate либо пустом plan прежний wave loop выполняется
без новой ветки поведения.

## Wave quota marker

Один обычный targetable enemy на Context может получить typed meta
`encounter_wave_quota_excluded=true`. Он остаётся в group `enemies`, поэтому
обычные target queries и damage работают без изменений, но общий quota count его
не учитывает. Elite/boss markers, не-boolean meta и превышение лимита fail closed;
без marker результат равен прежнему `group.size()`.

## Act-scoped state и autosave

Optional autosave section `encounter_feature_state` имеет envelope schema v1:
`schema_version`, `act`, `entries`, `quarantined`. Запись feature хранит только
решение (`accepted|declined`), одноразовые offer/claim counts, risk state и
idempotency checkpoint ids. UI nodes, payload конкретного feature и неизвестные
поля запрещены.

Checkpoint нормализует старое и новое состояние, обновляет deep copy и при
запрошенной pre-risk durability вызывает существующий atomic run autosave. Если
save не удался, in-memory transition откатывается. Отсутствующая section в
legacy save означает пустое валидное состояние; wrong version/act, unknown id и
malformed record переводят весь act envelope в `quarantined` с пустыми entries,
поэтому из повреждённого состояния нельзя восстановить reward/risk claim. При
новом run и переходе акта entries сбрасываются. Внешняя schema autosave остаётся
v1.

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

Новые features подключаются данными built-in registry либо отдельным
`*.feature.json` под allowlisted root. Ни директор, ни адаптер при этом не
редактируются.

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
python3 tools/godot_gate.py --headless --path . --script res://tests/encounters/encounter_registry_contract_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/encounters/encounter_spawn_plan_quota_test.gd
python3 tools/godot_gate.py --headless --path . --script res://tests/encounters/encounter_feature_state_autosave_test.gd
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
