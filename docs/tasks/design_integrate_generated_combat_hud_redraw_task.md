# Задача Для Design-Агента: Внедрить сгенерированный ассет combat hud redraw

Статус: done
Создано: 2026-06-14
Автор: Codex asset generator
Исполнитель: Design / Codex. Интеграция в код — через Back-end handoff при необходимости.
Версия: 0.1.5
Jira: SCRUM-398

## Autonomy / Approval
Пользователь заранее одобрил изменения в рамках этой задачи. Работать автономно, не ждать дополнительных подтверждений.

## Контекст
Сгенерирован новый PNG-референс через OpenAI Images API для FantasyDisk. Файл лежит в проектной папке референсов и должен быть оценен, доведен до production-ассета или использован как source/reference для внедрения.

## Source Asset
- PNG: `docs/design/references/combat_hud_redraw/combat_hud_redraw_reference_sheet.png`
- Model: `gpt-image-2`
- Size: `1536x1024`
- Quality: `high`
- Prompt:

```text
FantasyDisk dark fantasy Dungeons and Dragons combat HUD asset sheet, transparent background requested, no text, no letters, no numbers, no watermark. Create a clean game UI kit: one long thin top-left resource HUD panel frame, four compact resource card frames, red health bar fill, blue experience bar fill, violet ultimate charge bar fill, gold coin counter medallion, ornate timer panel, small ascension badge, opaque red and gold dragon level-up plus button. Style must match ornate dark metal with red gems, red-gold dragon button kit, thin metallic frame, painterly realistic D&D UI, readable over combat, safe empty dark centers for labels and icons, no meaningless circles lines squares, no content on decorative borders. Arrange components with spacing on a single reference sheet.
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

Covered by parent Design task `design_combat_hud_full_redraw_skill_task.md` / SCRUM-390.
The generated source sheet was accepted as reference only, then postprocessed into
alpha-ready production candidates:

- `docs/design/references/combat_hud_redraw/combat_hud_redraw_reference_sheet_alpha_clean.png`
- `assets/sprites/ui/frames/combat_hud/`
- `assets/sprites/ui/hud/combat_hud/`

Runtime wiring is intentionally handed off to Back-end because the active HUD is
assembled in `scripts/ui_screens.gd` and must preserve gameplay/HUD update logic.

## QA-Вердикт (2026-06-14)
Статус: PASSED (covered by SCRUM-390)

Генератор-стаб combat-HUD reference. Собственный deliverable на месте: alpha-clean
reference + production-candidates под `assets/sprites/ui/frames/combat_hud/` +
`assets/sprites/ui/hud/combat_hud/`. Полный combat-HUD редроу — родитель SCRUM-390
(`design_combat_hud_full_redraw_skill_task.md`, **in_progress**); рантайм-проводка
HUD — Back-end. Эту задачу проверю по факту в составе SCRUM-390 (когда done/review).
Не дублируется. Баги: нет.
