# SCRUM-1094 — Atlas malformed locked dossier hides purchase failure

Статус: in_progress
Версия: 0.2.1
Jira: SCRUM-1094
Тип: bug
Контур: Codex
Роль: Back-end
Owner: Back-end / Codex subagent
Thread: /root/scrum1093_main_menu_version
Combined scope: SCRUM-1093 + SCRUM-1094, identical `scripts/ui_screens.gd` lock
Найдено QA при тестировании: `SCRUM-1091`
Blocked issue: `SCRUM-1091`
Locked paths: `scripts/ui_screens.gd`,
`tests/scrum1094_atlas_failure_precedence_test.gd`, this mirror and relevant
Atlas/UI docs.

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

## Implementation result

- `scripts/ui_screens.gd` now evaluates `dossier_blocked` first and routes
  ordinary locked/purchased hints through `elif`, so no later branch can
  overwrite the explicit schema failure.
- `tests/scrum1094_atlas_failure_precedence_test.gd` mutates both an available
  and a locked schema-6 node, checks the exact safe description/condition,
  rejects generic fallbacks and requires Buy visible+disabled.
- Pre-integration PASS: SCRUM-1094 focused regression; SCRUM-1091 exact 357/51
  descriptions and dossier UI matrix; migrated Meta40 Atlas; SCRUM-1067/1068
  validators and schema final runtime gates; no-overlap; runtime UI/full smoke.
