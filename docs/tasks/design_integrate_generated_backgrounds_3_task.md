# Задача Для Design-Агента: Внедрить сгенерированный ассет backgrounds

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
- PNG: `docs/design/references/backgrounds/field_misty_marsh_reference.png`
- Model: `gpt-image-2`
- Size: `2560x1440`
- Quality: `high`
- Prompt:

```text
FantasyDisk combat arena background, top-down Dungeons and Dragons dark fantasy tabletop battlemap, realistic painterly ground texture, 2560x1440 wide arena floor, low-to-medium contrast central gameplay area, no tall objects, no walls blocking play, no characters, no monsters, no UI, no text, no watermark, flush-to-ground details only, subtle directional light from upper left, readable for animated heroes and monsters on top, edges naturally detailed without hard seams, not noisy, not over-saturated, dark fantasy dragon-era game art style. Biome: misty swamp floor, cold foggy wet ground, pale moss, dark mud, faint water channels, ghostly blue-green tones, low contrast center.
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
