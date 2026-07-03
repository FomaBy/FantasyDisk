# BUG: SCRUM-855 referenced backend and QA task mirrors are missing from dev

Статус: done
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

## Результат 2026-07-04

SCRUM-863 initial bug condition is resolved on `dev`:
- Backend mirror exists and is committed:
  `docs/tasks/backend_aoe_weapon_overlays_zones_summons_doctor_task.md`.
- QA review mirror exists and is committed:
  `docs/tasks/qa_review_aoe_weapon_overlays_zones_summons_doctor_task.md`.
- Backend mirror records implementation summary, locked paths, focused tests,
  runtime smoke, docs touched, QA verdict, and disk cleanup.
- QA mirror was repaired from pending template to final `PASSED` evidence with
  the SCRUM-854/SCRUM-864 commits, focused test list, runtime smoke note,
  independent QA subagent result, and SCRUM-863 recheck cleanup.

Verification:
- `git log --all -- docs/tasks/backend_aoe_weapon_overlays_zones_summons_doctor_task.md docs/tasks/qa_review_aoe_weapon_overlays_zones_summons_doctor_task.md` shows committed history for both paths.
- SCRUM-863 QA recheck on fresh `origin/dev` confirmed the files exist; the
  remaining failure was only the pending QA mirror content, fixed here.
- No runtime code changed in the SCRUM-863 repair.

Disk cleanup: none created by the repair pass; QA recheck removed its disposable
clone/logs before this fix.
