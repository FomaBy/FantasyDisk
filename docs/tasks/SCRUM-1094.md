# SCRUM-1094 — Atlas malformed locked dossier hides purchase failure

Статус: new
Версия: 0.2.1
Jira: SCRUM-1094
Тип: bug
Контур: Codex
Роль: Back-end
Owner: unassigned
Найдено QA при тестировании: `SCRUM-1091`
Blocked issue: `SCRUM-1091`
Locked paths: `scripts/ui_screens.gd` (только приоритет сообщения
`AtlasNodeCondition`); focused regression test.

## Воспроизведение

1. В runtime-проекции установить для locked schema-6 узла
   `dossier_valid = false`, `dossier = {}`.
2. Открыть Атлас и выбрать узел до покупки его prerequisite.
3. Проверить `AtlasNodeDesc`, `AtlasBuyButton`, `AtlasNodeCondition`.

## Ожидание / Реальность

Ожидание: безопасный desc, disabled Buy и явная причина
`Покупка отключена: требуется корректный schema-6 dossier.` имеют приоритет при
любом node status.

Реальность: desc и disabled Buy корректны, но обычная locked-state ветка сразу
перезаписывает причину на `Нужна соседняя купленная звезда` либо currency hint.

## Окружение

- `origin/dev f7b9d7373`;
- implementation `b36a650e2`;
- Godot 4.7, isolated user data, 1280×720;
- independent oracle: `tests/scrum1091_independent_qa_test.gd`.

## Acceptance

- invalid dossier condition всегда имеет приоритет над availability hints;
- available и locked malformed nodes сохраняют явную причину блокировки;
- Buy остаётся disabled, plausible fallback copy отсутствует;
- focused Atlas dossier UI, no-overlap/runtime UI и full runtime smoke зелёные.
