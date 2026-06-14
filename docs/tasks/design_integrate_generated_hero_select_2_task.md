# Задача Для Design-Агента: Внедрить сгенерированный ассет hero select

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
- PNG: `docs/design/references/hero_select/frame_dossier_wide.png`
- Model: `gpt-image-2`
- Size: `1536x960`
- Quality: `high`
- Prompt:

```text
WIDE landscape rectangular DOSSIER description panel (about 3:2 wide) D&D Dark Fantasy Dragon UI frame, aged dark forged metal, muted gold trim, ruby gem accents, claw-notched corners, subtle dragon scale, ornate restrained, cohesive set. Single isolated frame on SOLID FLAT PURE MAGENTA #FF00FF background, EMPTY flat magenta interior for chroma-key, ornament ONLY on border, no text, no characters. Crisp, centered.
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
