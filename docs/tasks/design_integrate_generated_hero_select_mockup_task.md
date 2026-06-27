# Задача Для Design-Агента: Внедрить сгенерированный ассет hero select mockup

Статус: new
Создано: 2026-06-15
Автор: Codex asset generator
Исполнитель: Design / Codex. Интеграция в код — через Back-end handoff при необходимости.
Версия: 0.1.5
Jira: SCRUM-445

## Autonomy / Approval
Пользователь заранее одобрил изменения в рамках этой задачи. Работать автономно, не ждать дополнительных подтверждений.

## Контекст
Сгенерирован новый PNG-референс через OpenAI Images API для FantasyDisk. Файл лежит в проектной папке референсов и должен быть оценен, доведен до production-ассета или использован как source/reference для внедрения.

## Source Asset
- PNG: `docs/design/references/hero_select_mockup/hero_select_layout_mockup.png`
- Model: `gpt-image-2`
- Size: `1536x1024`
- Quality: `high`
- Prompt:

```text
UI mockup / layout template for a fantasy roguelite HERO SELECT screen, dark fantasy D&D dragon style: dark stone background, thin ornate metallic gold frames with small red gems. Landscape 16:9. LAYOUT (max clarity, distinct framed panels): top-center a title banner reading 'ВЫБОР ГЕРОЯ'; LEFT a tall vertical framed panel for a large hero portrait (full-body character placeholder); CENTER a wide framed dossier panel with hero name header, several lines of description text, lines for 'Сильные:', 'Слабые:', 'Оружие:'; at the BOTTOM of the dossier a small ascension stepper row with a minus button, a label 'Возвышение 5/10', a plus button, and below it a wide 'ВЫБРАТЬ' button; TOP-RIGHT a circular compass/wind-rose stat radar widget labeled 'Характеристики'; BOTTOM a horizontal carousel strip with a row of small square hero icon slots; bottom-center a 'НАЗАД' button. Clean readable UI mockup, each element clearly separated, transparent-friendly dark panels, golden text.
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
