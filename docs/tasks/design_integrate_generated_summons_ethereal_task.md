# Задача Для Design-Агента: Внедрить сгенерированный ассет summons ethereal

Статус: done
Создано: 2026-06-14
Автор: Codex asset generator
Исполнитель: Design / Codex. Интеграция в код — через Back-end handoff при необходимости.
Версия: 0.1.5
Jira: SCRUM-401

## Autonomy / Approval
Пользователь заранее одобрил изменения в рамках этой задачи. Работать автономно, не ждать дополнительных подтверждений.

## Контекст
Сгенерирован новый PNG-референс через OpenAI Images API для FantasyDisk. Файл лежит в проектной папке референсов и должен быть оценен, доведен до production-ассета или использован как source/reference для внедрения.

## Source Asset
- PNG: `docs/design/references/summons_ethereal/summons_ethereal_source_sheet.png`
- Model: `gpt-image-2`
- Size: `1536x1024`
- Quality: `high`
- Prompt:

```text
FantasyDisk summon allies ethereal source sheet, transparent background requested, no text, no letters, no numbers, no watermark. Four distinct allied spirit creatures in Dungeons and Dragons dark fantasy painterly style: 1 ghostly cyan wolf beast, 2 larger pack spirit wolf with flowing spectral mane, 3 small alchemical homunculus spirit with vial/core shapes, 4 humanoid leadership echo banner-guardian spirit. All must be clearly allied summons, blue/cyan translucent ghost bodies, soft inner glow, smoky fading edges, white-blue rim light, not dark monsters, readable top-down game sprites, centered separate characters, no ground shadows baked, no UI frames.
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

## Result Summary — 2026-06-14

Covered by parent task `design_summons_ethereal_redraw_anim_from_scratch_task.md`
/ SCRUM-399.

- Source PNG accepted as the visual reference for the ethereal summon pass.
- Runtime static and animated PNGs were updated in place under
  `assets/sprites/allies/` while preserving existing SpriteFrames paths and
  timings.
- Contact/readability previews and manifest are stored under
  `docs/design/previews/` and `docs/design/references/summons_ethereal/`.
- Godot import and `tests/animation_smoke_test.gd` passed; full runtime smoke is
  blocked by unrelated Back-end/UI assertions documented in SCRUM-399 and
  handoff `backend_runtime_smoke_levelup_summon_death_regression_task.md`.

## QA-Вердикт (2026-06-14)
Статус: PASSED (covered by SCRUM-399)

Генератор-стаб ethereal-summon reference. Собственные ассеты на месте (ethereal
static/animated sources druid_beast/pack_spirit и др.), animation_smoke зелёный.
Полный ethereal-редроу — родитель SCRUM-399 (`design_summons_ethereal_redraw_anim_from_scratch_task.md`,
статус **blocked/К выполнению**); проверю его по факту при разблокировке/готовности.
Прежний runtime_smoke-блок (level-up/summon death регрессия) на момент QA УСТРАНЁН
(runtime_smoke зелёный). Не дублируется. Баги: нет.
