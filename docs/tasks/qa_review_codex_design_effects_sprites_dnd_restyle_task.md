# Задача Для QA-Агента: Review D&D Рестайла Спрайтов Эффектов

Статус: done 2026-06-12. Закрыта PM при ревизии: дубликат — целевая задача codex_design_effects_sprites_dnd_restyle уже имеет QA-Вердикт PASSED (полная проверка палитры/размеров/читаемости выполнена QA-воркером). Повторная проверка не требуется.
Создано: 2026-06-12
Автор: Codex dispatcher
Роль: QA (Claude)
Источник: `docs/tasks/codex_design_effects_sprites_dnd_restyle_task.md`
Готово к QA: исходная Design/Codex задача получила `review` 2026-06-12.

## Autonomy / Approval
Пользователь заранее одобрил QA-проверку всех in-scope изменений. QA не чинит
баги сам: найденные дефекты оформлять отдельными `bug_*.md` задачами на доске.

## Что Проверить
- Все 19 файлов `assets/sprites/effects/` заменены на месте и сохранили исходные
  имена, размеры, RGBA/alpha.
- Палитра соответствует D&D/tabletop стилю проекта и остается сдержанной:
  нет кислотного неона, чисто-белых пересветов и визуального шума.
- Формы лаконичны и читаются поверх `assets/backgrounds/field_meadow.png` и
  `assets/backgrounds/field_marsh.png`.
- Тинтуемые текстуры (`hazard_zone`, telegraph-related assets) корректно
  модулируются кодом и не ломают читаемость.
- `assets/sprites/effects/effects_dnd_preview.png` создан и полезен для review.
- `content_registry` и `CHANGELOG` обновлены после Designer review/интеграции.

## Ожидаемые Проверки
- Прочитать исходный task-файл и итоговый progress log.
- Проверить размеры/alpha всех 19 PNG.
- Визуально проверить preview-лист и несколько эффектов в игре.
- Прогнать `attack_vfx_smoke_test` и `runtime_smoke_test`, плюс обязательные QA
  regression checks по `docs/process/qa_protocol.md`.

## Acceptance Criteria
- [ ] Все пункты исходной задачи проверены фактически.
- [ ] Visual QA не нашел неоновых/пересвеченных/плохо читаемых эффектов.
- [ ] Smoke/regression проверки зеленые или оформлены bug tasks.
- [ ] В исходный task-файл добавлен `## QA-Вердикт` по протоколу.
- [ ] Board обновлена пометкой `QA: passed` или `QA: failed`.
