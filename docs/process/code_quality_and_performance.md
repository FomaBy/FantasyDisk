# Code Quality & Windows Performance Gate

Обновлено: 2026-08-01. Аудит FAN-1040 выполнен на исходном
`1190db1d1de10ab90e21d2cdea32be908efbeada`; исправления проверяются единым gate.

## Lean default и risk-профили

Обычное небольшое gameplay/scene/test изменение запускает один непосредственно
затронутый suite через `tools/godot_gate.py`; второй нужен только для отдельного
failure mode. `changed`/`full` не являются локальной матрицей по умолчанию.
Полный gate требуется только для release/publish, saves/migrations, network,
payments/secrets/security или уже красного CI, когда focused checks не изолируют
причину. Не дублировать один full gate на developer, QA, PR и post-merge стадиях.

Доступные broad-профили для этих случаев:

```bash
python3 tools/quality_gate.py --profile changed --changed-ref origin/dev
python3 tools/quality_gate.py --profile full
```

Gate требует Godot 4.7 и последовательно проверяет case-sensitive `res://` пути,
синхронность версии и Windows export preset, архитектурные line-count ratchet’ы,
отсутствие raw/Base64 webhook credential, Python-тесты/синтаксис и direct +
inherited Godot suites. `changed` автоматически включает изменённые/новые тесты
и `semantic_typography_scrum1061_test` для области inventory, а также umbrella fallback для runtime/scene diff; `full` обнаруживает весь текущий
набор. Discovery рекурсивна: Godot suites берутся из всего `tests/**`, а
Python-тесты запускаются отдельной `unittest discover` на каждый каталог с
`test_*.py`, потому что `unittest` не заходит в non-package подкаталоги.
Одинаковые имена suites в разных каталогах отвергаются как ambiguous.
Любой `SCRIPT ERROR`, `FATAL`, timeout или ненулевой exit — failure. С FAN-1700
провал набора не зависит от кода возврата: набор сообщает о провале через
`push_error()`, Godot печатает при этом кадр `at: push_error (`, и гейт считает
такой вывод фатальным даже при exit 0. Это закрывает ложно-зелёный прогон, когда
`_fail()` без `return` доходит до успешного `quit()` (отложенный `quit(1)`
затирается нулём). Обычные `ERROR:`-строки движка без этого кадра остаются
безобидными и набор не роняют. С FAN-1718 эта сигнатура не может измениться
молча: фикстуры FAN-1700 в `tests/test_quality_tools.py` обязаны нести баннер
пинованного `GODOT_BUILD_ID` из `quality.yml`, а live-probe
(`LiveEngineSignatureTests`) запускает установленный движок на минимальном
временном проекте с `push_error(...)` и читает вывод боевым классификатором;
чистый контрольный прогон обязан остаться без сигнала. Без движка probe
детерминированно скипается с указанием причины; кандидатный CI экспортирует
`GODOT_BIN` (закреплено в `test_quality_workflow.py`), поэтому там probe
исполняется всегда, а заданный, но нерабочий `GODOT_BIN` — громкий failure,
не skip.
Filtered/skip-прогон имеет non-certifying статус `partial_pass`, пустой прогон
запрещён: нулевой выбор Godot-тестов или `Ran 0 tests` в Python-discovery дают
`failed` с записью в `static_checks`, а не зелёный отчёт. Staged, unstaged или untracked worktree также всегда non-certifying и
фиксируется в JSON evidence; commit-range и index whitespace проверяются
отдельно. `--static-only` — engine-free профиль: `select_godot_tests` возвращает
для него пустой список, поэтому он допустим только там, где Godot не установлен
(push в `dev`). Required-проверка на pull request и merge queue запускает
`changed` на закреплённом Godot `4.7.stable.official.5b4e0cb0f`. Для обычного
малого PR это единственный broad CI; `full` остаётся release/risk gate для
случаев выше.

## Реестр находок

| Приоритет | Доказательство | Решение |
|---|---|---|
| Critical | `feedback_reporter.gd` содержал полный Discord webhook в обратимом base64; тест закреплял его как контракт | Credential удалён, старый webhook отозван (`DELETE 204`, контрольный `404`). FAN-1056 добавил server-only relay, release-safe client protocol, server auth/rate/idempotency/privacy tests и post-export secret scan. Production остаётся выключен до provisioning HTTPS/storage/new webhook |
| High | `_taunt_target()` вызывался каждым enemy каждый physics tick и делал `StatusEffects.snapshot().duplicate(true)` | Добавлен scalar `status_value`; полный status map больше не копируется в target selection |
| High | `StatusEffects.tick()` строил `get_method_list()` каждый physics tick для каждого DoT | Introspection выполняется только при фактически наступившем DoT tick; финальное expiry также удаляет status/marker metadata |
| High | Каждый enemy отдельно вызывал `get_nodes_in_group("enemies")` при separation refresh | Все refresh в кадре используют один `CombatTargetQuery` snapshot; mass regression фиксирует 48 enemies, ровно одну генерацию snapshot и максимум 4 neighbors |
| High | Wave pack spawn повторно сканировал всю enemy group после каждого spawn | Cap вычисляется один раз, затем поддерживается локальным `remaining_slots`; combat smoke проверяет непревышение cap несколькими волнами |
| High | Автосейв удалял последний хороший checkpoint до успешного rename, а clear мог оставить восстанавливаемый `.bak` | Введён `.tmp` → `.bak` swap с rollback/recovery; clear проверяет ошибки и удаляет auxiliary-файлы раньше primary; regressions покрывают оба прерывания |
| High | Configurable `PackedScene.instantiate() as Node2D` часто сразу разыменовывался | Общий `SceneContracts` валидирует root и освобождает wrong-root instance; применён к основным enemy/elite/boss/pickup/summon spawners |
| Medium | Focused shell discovery видел только точную первую строку `extends SceneTree` и обходил derived suites; Godot запускался мимо semaphore | Единый динамический discovery включает direct и inherited suites; shell runner направлен через `godot_gate.py`; semaphore поддерживает POSIX и native Windows |
| Medium | `ui_screens.gd` (≈17k), `class_weapon.gd` (≈6k) и другие god objects продолжают расти | Static ratchet запрещает рост legacy-монолитов и новые scripts >1200 строк; extraction выполняется отдельными поведенческими задачами, без wholesale rewrite |

## Оставшиеся риски и границы этого прохода

- Feedback lifecycle race из FAN-1040 закрыт в FAN-1046: monotonic request owner,
  at-most-once completion и cancellation защищают reopen/supersede. FAN-1056
  дополнительно guards двухфазный relay по `(request_id, phase)`. Оставшийся
  feedback blocker — только внешний production provisioning/rollout FAN-1041.
- Combat start не полностью транзакционен: отсутствие Player или failure обязательного
  prayer presenter могут оставить частично созданные HUD/music/runtime state. Нужен
  центральный `_abort_combat_start()` и fault-injection tests.
- Некоторые менее частые spawner paths всё ещё требуют миграции на `SceneContracts`;
  gate защищает новые массовые Node2D boundaries, но не обещает механическую замену
  всех duck-typed сцен за один проход.
- Threat-indicator discovery переведён на общий snapshot с refresh 10 Hz, а
  Bastion taunt читает scalar status без deep-copy. Оставшийся spatial O(N²)
  separation требует native benchmark и отдельного grid-equivalence изменения.
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
устройстве и не подменяется macOS headless. С FAN-2798 она обязана включать
заполненный перф-раздел по `docs/qa/perf-checklist.md` (метрики M1–M5 с числами);
вердикт Windows-проверки без него неполный.
