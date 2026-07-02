# Задача Для Design-Агента: Внедрить сгенерированный ассет hero select mockup

Статус: done / superseded by Hero Select v4 runtime
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

## Result / Closure
- Reviewed source reference: `docs/design/references/hero_select_mockup/hero_select_layout_mockup.png`.
- Layout metadata exists beside the source image as `elements.json` and `elements_normalized.json`.
- Closed as approved historical reference only: the active runtime implementation is Hero Select v4 from SCRUM-470/SCRUM-491, so this legacy mockup does not need a separate runtime integration pass.
- No final runtime asset was copied into `assets/sprites/...`; no `.import` files were intentionally modified.
- Related runtime/UI coverage is handled by the Hero Select v4 QA path (`runtime_smoke_ui_test.gd`, `ui_no_overlap_matrix_test.gd`, `runtime_smoke_test.gd`).

## QA-Вердикт
Статус: PASSED

Проверено claude-qa 2026-07-02 на origin/dev (d2de5600). Reference-only / superseded design-задача, ранее уже принята (PASSED 2026-06-28). Дрейф обратно в «Контроль качества» вызван отсутствием этого блока — board_sync держит `Статус: done` без `## QA-Вердикт`/`Статус: PASSED` в «Контроль качества». Блок добавлен для устойчивого закрытия.

Сверка acceptance на origin/dev:
- Source-референс на месте: `docs/design/references/hero_select_mockup/hero_select_layout_mockup.png` + layout-метаданные `elements.json` / `elements_normalized.json` ✓
- Финальный runtime-ассет не создавался (reference-only, закрыт как approved historical reference); активный путь — Hero Select v4 (SCRUM-470/491) ✓
- `.import` без stray-правок; runtime-код не ссылается на легаси-мокап ✓
- Прошлый verdict-коммит (b8db8422) — предок origin/dev; runtime-покрытие hero-select зелёное на прошлом прогоне ✓
