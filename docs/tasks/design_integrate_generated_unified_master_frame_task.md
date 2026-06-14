# Задача Для Design-Агента: Внедрить сгенерированный ассет unified master frame

Статус: new
Создано: 2026-06-14
Автор: Codex asset generator
Исполнитель: Design / Codex. Интеграция в код — через Back-end handoff при необходимости.
Версия: 0.1.5
Jira: pending sync

## Autonomy / Approval
Пользователь заранее одобрил изменения в рамках этой задачи. Работать автономно, не ждать дополнительных подтверждений.

## Контекст
Сгенерирован новый PNG-референс через OpenAI Images API для FantasyDisk. Файл лежит в проектной папке референсов и должен быть оценен, доведен до production-ассета или использован как source/reference для внедрения.

## Source Asset
- PNG: `docs/design/references/unified_master_frame/ui_frame_unified_master_reference.png`
- Model: `gpt-image-2`
- Size: `1024x1024`
- Quality: `high`
- Prompt:

```text
FantasyDisk unified master UI frame for a dark fantasy Dungeons and Dragons game. One square ornate 9-slice-compatible frame only, no text, no icons, no labels. Realistic dark forged metal and deep crimson leather, subtle dragon-scale bevels, aged brass/gold edge highlights, small believable rivets and claw-like corners, no random circles or decorative filler. Clean empty dark flat center content area. Border must be thinner than old bulky frames, readable corners, horizontal and vertical edge bands mostly straight and repeatable/tileable, minimal unique detail in edge stretch zones, optional subtle center ornaments at top and bottom that can be ignored. Put the frame on a solid bright green chroma background for alpha cleanup; no drop shadow outside the frame.
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
