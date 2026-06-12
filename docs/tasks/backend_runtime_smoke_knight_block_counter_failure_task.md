# Задача Для Back-end-Агента: Runtime Smoke Fails On Knight Block Counter

Статус: new

Примечание PM (2026-06-12): на момент проверки в рабочем дереве шли ТРИ параллельные незакоммиченные работы (Backend: player/class_weapon — вторичные атрибуты; Designer: ui_screens — UI-редизайн; Codex: рестайл персонажей). Прогоны smoke ловят промежуточные состояния: один прогон PM был зеленым, следующие падали парс-ошибками НЕЗАВЕРШЕННОЙ UI-правки (_style_slider/_style_checkbox), а не рыцарем. ВЫПОЛНЯТЬ ЭТУ ЗАДАЧУ ПОСЛЕ того, как текущие работы Backend и Designer закоммичены: прогнать smoke 3x на чистом дереве; если рыцарь зеленый стабильно — закрыть как transient; если падает — чинить block/counter (вероятная связь: интерпретация Энергии меняет кулдаун контратаки в задаче вторичных атрибутов).
Создано: 2026-06-12
Автор: Codex Design handoff
Исполнитель: Back-end

## Autonomy / Approval

Пользователь заранее одобрил in-scope изменения. Работать автономно до исправления и зеленого smoke-test.

## Контекст

Во время Design-задачи `docs/tasks/codex_design_artifact_icons_per_item_regen_task.md` были перегенерированы только PNG-иконки артефактов и обновлена визуальная документация. GDScript/gameplay logic не менялись.

Требуемый smoke-test был запущен дважды:

```bash
/Users/sergeyfomin/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/sergeyfomin/Documents/AI\ Agent --script res://tests/runtime_smoke_test.gd
```

Оба запуска упали одинаково:

```text
ERROR: Expected Knight block to reduce damage and counter nearby enemies.
GDScript backtrace:
    [0] _fail (res://tests/runtime_smoke_test.gd:2507)
    [1] _test_unique_class_identity_patterns (res://tests/runtime_smoke_test.gd:1881)
```

## Что Уже Сделано

- Design asset pass завершен.
- `tools/validate_artifact_icons.py` зеленый: 53 artifact icons validated.
- `assets/sprites/ui/icons/artifact_per_item_preview.png` создан.
- Smoke-test запускался дважды и стабильно падает на Knight block/counter.

## Что Нужно От Back-end

1. Проверить `_test_unique_class_identity_patterns` в `tests/runtime_smoke_test.gd`.
2. Исправить логику Knight block/counter или тест, если тест устарел относительно текущего design/backend поведения.
3. Запустить runtime smoke-test и добиться зеленого результата.

## Files / Assets / IDs

- `tests/runtime_smoke_test.gd`
- Knight class / tower shield / block-counter implementation paths по текущей архитектуре.

## Acceptance Criteria

- Runtime smoke-test проходит без ошибки `Expected Knight block to reduce damage and counter nearby enemies`.
- Если поведение Knight меняется, обновлена соответствующая gameplay документация.
