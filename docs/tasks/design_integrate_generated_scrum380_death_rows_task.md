# Задача Для Design-Агента: Внедрить сгенерированный ассет scrum380 death rows

Статус: done
Создано: 2026-06-14
Автор: Codex asset generator
Исполнитель: Design / Codex. Интеграция в код — через Back-end handoff при необходимости.
Версия: 0.1.5
Jira: covered by SCRUM-380

## Autonomy / Approval
Пользователь заранее одобрил изменения в рамках этой задачи. Работать автономно, не ждать дополнительных подтверждений.

## Контекст
Сгенерирован новый PNG-референс через OpenAI Images API для FantasyDisk. Файл лежит в проектной папке референсов и должен быть оценен, доведен до production-ассета или использован как source/reference для внедрения.

## Source Asset
- PNG: `docs/design/references/scrum380_death_rows/druid_beast_death_row_reference.png`
- Model: `gpt-image-2`
- Size: `1536x1024`
- Quality: `high`
- Prompt:

```text
FantasyDisk Dungeons and Dragons dark fantasy transparent sprite sheet reference: six full-frame death animation poses for an allied druid beast wolf spirit, same character across all frames, left-facing top-down/isometric game sprite, 6 equal poses in a single horizontal row, gradual collapse and fade into soft blue-green spirit embers, readable silhouette, stable bottom-center pivot, no text, no labels, no UI frame, no background except solid bright green chroma for alpha cleanup.
```

## Что Нужно Сделать
1. Проверить визуальное качество, соответствие текущему dark fantasy art direction и читаемость в целевом размере.
2. Подготовить финальный ассет в нужной runtime-папке `assets/sprites/...` или оставить как approved reference, если прямое внедрение пока не требуется.
3. Если нужны Godot-сцены, скрипты, импорт, theme mapping или логика подключения — создать/передать Back-end handoff с точными путями и acceptance criteria.
4. Обновить `docs/design/content_registry.md`, релевантные domain docs и `CHANGELOG.md`, если ассет вошел в игру.

## Acceptance Criteria
- [ ] PNG из `docs/design/references/` просмотрен и принят/доработан перед runtime-интеграцией.
- [ ] Финальный ассет, если создается, имеет стабильное имя и лежит в правильной `assets/sprites/...` папке.
- [ ] Не тронуты `.import` файлы без необходимости.
- [ ] При runtime-интеграции пройдены релевантные Godot smoke/UI checks.
- [ ] Jira и task-файл синхронизированы после смены статуса.

## Result — 2026-06-14

Covered by SCRUM-380 `design_full_frame_death_rows_allies_elites_bosses_task.md`. The generated reference was accepted into the full 19-entity death-row pass, postprocessed to transparent runtime frames/row sheets, validated, imported through Godot, and handed back to Animator through SCRUM-370.


## QA-Вердикт (2026-06-14)
Статус: PASSED (covered by SCRUM-380)

Генератор-стаб death-row референса. Фактический deliverable (death-ряды 19
сущностей) произведён и **верифицирован в QA-вердикте SCRUM-380** (114 кадров,
манифест, контакт-превью, Godot import чист). Runtime .tres-интеграция — Animator
SCRUM-370. Не дублируется. Баги: нет.
