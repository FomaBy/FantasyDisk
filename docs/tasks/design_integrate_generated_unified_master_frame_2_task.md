# Задача Для Design-Агента: Внедрить сгенерированный ассет unified master frame

Статус: done
Создано: 2026-06-14
Автор: Codex asset generator
Исполнитель: Design / Codex. Интеграция в код — через Back-end handoff при необходимости.
Версия: 0.1.5
Jira: covered by SCRUM-384

## Autonomy / Approval
Пользователь заранее одобрил изменения в рамках этой задачи. Работать автономно, не ждать дополнительных подтверждений.

## Контекст
Сгенерирован новый PNG-референс через OpenAI Images API для FantasyDisk. Файл лежит в проектной папке референсов и должен быть оценен, доведен до production-ассета или использован как source/reference для внедрения.

## Source Asset
- PNG: `docs/design/references/unified_master_frame/thin_metallic_unified_frame_reference.png`
- Model: `gpt-image-2`
- Size: `1024x1024`
- Quality: `high`
- Prompt:

```text
FantasyDisk dark fantasy Dungeons and Dragons user interface frame asset, square 9-slice ready ornate but THIN metallic border, very thin bevelled dark steel edges, slim corners, four small polished red gemstones embedded in the corners, optional subtle dragon head medallions centered on each edge but kept outside the large empty stretchable center, transparent-background-friendly composition, no text, no labels, no icons in the center, no watermark, clean flat empty inner content area, tileable straight horizontal and vertical border segments, realistic painterly metal with gold scratches and dark steel, elegant not bulky, content must remain fully inside the inner safe area, game UI frame source art on plain neutral background for alpha cleanup
```

## Что Нужно Сделать
1. Проверить визуальное качество, соответствие текущему dark fantasy art direction и читаемость в целевом размере.
2. Подготовить финальный ассет в нужной runtime-папке `assets/sprites/...` или оставить как approved reference, если прямое внедрение пока не требуется.
3. Если нужны Godot-сцены, скрипты, импорт, theme mapping или логика подключения — создать/передать Back-end handoff с точными путями и acceptance criteria.
4. Обновить `docs/design/content_registry.md`, релевантные domain docs и `CHANGELOG.md`, если ассет вошел в игру.

## Acceptance Criteria
- [x] PNG из `docs/design/references/` просмотрен и принят/доработан перед runtime-интеграцией.
- [x] Финальный ассет, если создается, имеет стабильное имя и лежит в правильной `assets/sprites/...` папке.
- [x] Не тронуты `.import` файлы без необходимости.
- [x] При runtime-интеграции пройдены релевантные Godot smoke/UI checks.
- [x] Jira и task-файл синхронизированы после смены статуса.

## Result
Covered by SCRUM-384. Reference
`docs/design/references/unified_master_frame/thin_metallic_unified_frame_reference.png`
was used as the generated art direction source for the thin metallic unified
frame revision. Final runtime assets were written to the preserved
`assets/sprites/ui/frames/unified/` paths, with metadata/previews/docs updated
from `docs/tasks/design_unified_frame_revise_thin_metallic_task.md`.

## QA-Вердикт (2026-06-14)
Статус: PASSED (covered by SCRUM-384)

Генератор-стаб thin-metallic reference. Фактический deliverable (тонкая ревизия
единого фрейма) верифицирован в QA-вердикте SCRUM-384 (margins 128→72, самоцветы,
9-slice, тесты зелёные). Не дублируется. Баги: нет.
