# BUG: SCRUM-855 referenced backend and QA task mirrors are missing from dev

Статус: new
Приоритет: high
Роль: Back-end / QA
Версия: 0.2.1
Контур: Codex
Исполнитель: Codex
Jira: SCRUM-863
Найдено QA при тестировании: SCRUM-855
Связано: SCRUM-855

## Воспроизведение

1. Open Jira SCRUM-855 description.
2. Follow the referenced task mirror paths:
   - `docs/tasks/qa_review_aoe_weapon_overlays_zones_summons_doctor_task.md`
   - `docs/tasks/backend_aoe_weapon_overlays_zones_summons_doctor_task.md`
3. Check fresh `origin/dev`.

## Ожидание / Реальность

Expected:
- SCRUM-855 acceptance says documentation and task evidence must match the
  actual code.
- The referenced QA and backend task mirrors/evidence files exist on `dev`, with
  implementation notes, focused test commands, and any visual overlay screenshots
  needed for review.

Actual:
- Both referenced files are absent from fresh `origin/dev`.
- `git log --all --` for those paths does not find committed history.
- No SCRUM-855-specific evidence bundle was found under `build/qa/`, and the
  independent QA subagent found no `hammer_contact`/hammer readability preview
  for the overlay acceptance point.

## Окружение

- QA source: Jira SCRUM-855 description and acceptance criteria.
- Verified on `origin/dev` after fast-forward to `7a74c850`.
- Positive focused tests exist for parts of the feature, but the committed
  task/evidence contract is missing.

## Suggested Fix

- Restore or create the backend task mirror with implementation summary, locked
  paths, exact focused test list, and evidence references.
- Restore or create the QA review mirror, including final verdict and links to
  any screenshots/reports.
- Add the SCRUM-855 evidence bundle or update Jira to point to the correct
  committed evidence paths.
