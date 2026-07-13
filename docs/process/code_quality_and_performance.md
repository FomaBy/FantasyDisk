# Code Quality & Windows Performance Gate

Обновлено: 2026-07-13. Аудит FAN-1040 выполнен на исходном
`1190db1d1de10ab90e21d2cdea32be908efbeada`; исправления проверяются единым gate.

## Обязательные профили

```bash
python3 tools/quality_gate.py --profile changed --changed-ref origin/dev
python3 tools/quality_gate.py --profile full
```

Gate требует Godot 4.7 и последовательно проверяет case-sensitive `res://` пути,
синхронность версии и Windows export preset, архитектурные line-count ratchet’ы,
отсутствие raw/Base64 webhook credential, Python-тесты/синтаксис и direct +
inherited Godot suites. `changed` автоматически включает изменённые/новые тесты
и umbrella fallback для runtime/scene diff; `full` обнаруживает весь текущий
набор. Любой `SCRIPT ERROR`, `FATAL`, timeout или ненулевой exit — failure.
Filtered/skip-прогон имеет non-certifying статус `partial_pass`, пустой прогон
запрещён. `--static-only` — certifying CI-профиль, но не заменяет полный
локальный/release gate.

## Реестр находок

| Приоритет | Доказательство | Решение |
|---|---|---|
| Critical | `feedback_reporter.gd` содержал полный Discord webhook в обратимом base64; тест закреплял его как контракт | Удалён из source/export, resolver fail-closed, локальный fallback проверяет I/O. Старый webhook должен быть немедленно отозван/ротирован владельцем; безопасное production-решение — server-side rate-limited relay |
| High | `_taunt_target()` вызывался каждым enemy каждый physics tick и делал `StatusEffects.snapshot().duplicate(true)` | Добавлен scalar `status_value`; полный status map больше не копируется в target selection |
| High | `StatusEffects.tick()` строил `get_method_list()` каждый physics tick для каждого DoT | Introspection выполняется только при фактически наступившем DoT tick; финальное expiry также удаляет status/marker metadata |
| High | Каждый enemy отдельно вызывал `get_nodes_in_group("enemies")` при separation refresh | Все refresh в кадре используют один `CombatTargetQuery` snapshot; mass regression фиксирует 48 enemies, ровно одну генерацию snapshot и максимум 4 neighbors |
| High | Wave pack spawn повторно сканировал всю enemy group после каждого spawn | Cap вычисляется один раз, затем поддерживается локальным `remaining_slots`; combat smoke проверяет непревышение cap несколькими волнами |
| High | Автосейв удалял последний хороший checkpoint до успешного rename | Введён `.tmp` → `.bak` swap с rollback/recovery; regression имитирует прерванную замену |
| High | Configurable `PackedScene.instantiate() as Node2D` часто сразу разыменовывался | Общий `SceneContracts` валидирует root и освобождает wrong-root instance; применён к основным enemy/elite/boss/pickup/summon spawners |
| Medium | Focused shell discovery видел только точную первую строку `extends SceneTree` и обходил derived suites; Godot запускался мимо semaphore | Единый явный manifest включает derived combat suite; shell runner направлен через `godot_gate.py`; semaphore поддерживает POSIX и native Windows |
| Medium | `ui_screens.gd` (≈17k), `class_weapon.gd` (≈6k) и другие god objects продолжают расти | Static ratchet запрещает рост legacy-монолитов и новые scripts >1200 строк; extraction выполняется отдельными поведенческими задачами, без wholesale rewrite |

## Оставшиеся риски и границы этого прохода

- Feedback reporter всё ещё имеет один mutable pending slot и нет отмены retry timer:
  send → close → reopen может дать late callback/cross-report race. Исправление
  требует request-generation ownership и UI lifecycle regression, поэтому не
  смешивается с non-visual FAN-1040.
- Combat start не полностью транзакционен: отсутствие Player или failure обязательного
  prayer presenter могут оставить частично созданные HUD/music/runtime state. Нужен
  центральный `_abort_combat_start()` и fault-injection tests.
- Некоторые менее частые spawner paths всё ещё требуют миграции на `SceneContracts`;
  gate защищает новые массовые Node2D boundaries, но не обещает механическую замену
  всех duck-typed сцен за один проход.
- Threat-indicator discovery и Bastion taunt application имеют потенциальные
  group/status расходы. Первый затрагивает HUD cadence, второй — боевой баланс;
  оба требуют отдельных профилей/AC и не менялись здесь.
- `save_run_autosave()` возвращает failure, но ряд route/combat callers пока не
  показывает пользователю ошибку. Сохранённый checkpoint больше не уничтожается,
  однако caller-visible retry/error policy остаётся отдельной UX/persistence задачей.
- Renderer остаётся `gl_compatibility`, Windows export — x86_64 embedded PCK/S3TC,
  ANGLE/D3D12 выключены. Менять backend без A/B профиля на реальной Windows машине
  запрещено; Mac headless не является доказательством Windows frametime.

## Performance acceptance

При массовых изменениях принимаются детерминированные бюджеты, а не субъективное
«ощущается плавно»: число group snapshots/candidate visits, bounded node counts,
cache generations и отсутствие per-frame deep copies/introspection. Wall-clock
threshold в shared CI допустим только как дополнительный сигнал из-за шумности.
Финальная Windows release-проверка всё равно включает профиль на реальном Windows
устройстве и не подменяется macOS headless.
