# Задача Для Design-Агента: Внедрить сгенерированный ассет settings menu unified

Статус: done
Создано: 2026-06-14
Автор: Codex asset generator
Исполнитель: Design / Codex. Интеграция в код — через Back-end handoff при необходимости.
Версия: 0.1.5
Jira: covered by SCRUM-391

## Autonomy / Approval
Пользователь заранее одобрил изменения в рамках этой задачи. Работать автономно, не ждать дополнительных подтверждений.

## Контекст
Сгенерирован новый PNG-референс через OpenAI Images API для FantasyDisk. Файл лежит в проектной папке референсов и должен быть оценен, доведен до production-ассета или использован как source/reference для внедрения.

## Source Asset
- PNG: `docs/design/references/settings_menu_unified/settings_tab_switcher_3slot_reference.png`
- Model: `gpt-image-2`
- Size: `1536x512`
- Quality: `high`
- Prompt:

```text
FantasyDisk settings menu tab switcher frame, exactly THREE large tab slots only, wide horizontal UI strip, Dungeons and Dragons dark fantasy, red and gold dragon button style mixed with thin dark steel unified frame, transparent-background-friendly, no text, no labels, no icons, no fourth empty slot, three equal clickable inner areas, selected left tab as deep crimson metal, two inactive tabs dark leather steel, small red gemstones, thin metallic bevels, safe empty center area inside each tab for runtime text, no yellow glow, no watermark
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
Covered by SCRUM-391. The generated Settings switcher reference was reviewed,
alpha-cleaned and converted into production candidate
`assets/sprites/ui/frames/settings/ui_frame_settings_tab_switcher_3slot.png`.
Runtime activation is handed off to
`docs/tasks/backend_settings_menu_unified_restyle_integration_task.md`.

## QA-Вердикт (2026-06-14)
Статус: PASSED (covered by SCRUM-391)

Генератор-стаб settings-switcher референса. Фактический deliverable (3-slot switcher
ассет + метаданные + Back-end handoff) верифицирован в QA-вердикте SCRUM-391.
Видимая интеграция switcher — Back-end задача (рантайм пока 4-slot). Не дублируется. Баги: нет.
