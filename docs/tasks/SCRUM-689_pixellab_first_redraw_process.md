# SCRUM-689 — PixelLab-first redraw process rule

Jira: SCRUM-689
Статус: done
Контур: Codex
Executor: Codex
Owner: Codex PM/process worker
Thread: 019f1cef-574d-7692-91fb-be9d2779d1dc
Branch/worktree: codex/scrum-689-pixellab-process at `/Users/sergeyfomin/.codex/worktrees/scrum-689-pixellab-process`
Locked paths: `AGENTS.md`; `docs/process/ai_agent_memorandum.md`; `docs/process/agent_role_boundaries_and_handoffs.md`; `docs/process/pm_workflow.md`; this mirror

## Scope

Make future FantasyDisk redraw tasks PixelLab-first by default, while preserving
existing UI-director and content-zone rules. This is a process/documentation
task only; no gameplay, runtime, asset, or animation file changes.

## Acceptance

- Process documentation states that future redraw tasks use PixelLab by default.
- Allowed non-PixelLab exceptions must be explicit in Jira/task evidence.
- PM, Design, Animator and Codex workers can discover the rule before creating
  or executing redraw tasks.
- UI frame/content-zone hard rule remains intact.

## Result

- Updated `AGENTS.md` so future redraw source work is PixelLab-first by default,
  with `fantasydisk-asset-generator` reserved for non-redraw work or explicit
  Jira overrides.
- Updated `docs/process/ai_agent_memorandum.md` so new agents see PixelLab-first
  redraw in the skill/pipeline table and hard rules.
- Updated `docs/process/agent_role_boundaries_and_handoffs.md` so Design and
  Animator role boundaries carry the PixelLab-first redraw rule, transparent
  assets, pivots, 8-direction/animation contracts and runtime-safe evidence.
- Updated `docs/process/pm_workflow.md` with a dedicated PixelLab-first Redraw
  Intake section for PM/dispatcher task wording.
- Preserved the UI-director/content-zone/frame ornament rule: PixelLab is the
  redraw art source, not permission to place content on decorative borders.

## Verification

- `git diff --check` — passed.
- `python3 tools/jira_board_sync.py --task docs/tasks/SCRUM-689_pixellab_first_redraw_process.md --dry-run` — linked existing `SCRUM-689`, no issue creation.
- Text validation script checked required PixelLab-first/content-zone/exception
  wording in all changed docs — passed.

Disk cleanup: remove disposable worktree
`/Users/sergeyfomin/.codex/worktrees/scrum-689-pixellab-process` after final
push/Jira update; no `.godot`, generated assets or task temp caches were created.

## QA-Вердикт: PASSED

Проверено 2026-07-01 claude-qa на origin/dev @ ef22bf9f.
- Документация делает будущие redraw-задачи PixelLab-first: AGENTS.md, docs/process/pm_workflow.md (раздел «PixelLab-first Redraw Intake»), docs/process/ai_agent_memorandum.md, docs/process/agent_role_boundaries_and_handoffs.md.
- Non-PixelLab исключения требуют явной записи в Jira/task (override/blocker) — зафиксировано во всех четырёх документах.
- Правило видно для PM (pm_workflow), Design+Animator (role_boundaries), Codex (AGENTS.md) и новых агентов (memorandum).
- UI frame/content-zone hard rule сохранён и явно оговорён (PixelLab — источник арта, не разрешение класть контент на орнамент).
- Задача документация-only: код/сцены/ассеты/анимации не менялись → smoke-тесты не требуются.
Статус: PASSED
