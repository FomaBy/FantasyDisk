# BUG: SCRUM-677 continue-run title breaks safe zone

Статус: new
Jira: SCRUM-681
Приоритет: high
Роль: Design / Back-end
Найдено QA при тестировании: `docs/tasks/SCRUM-677_continue_run_title_restyle.md`

## Воспроизведение

1. Open continue-run dialog after SCRUM-677.
2. Run UI no-overlap matrix / geometry check.
3. Compare `ContinueRunPanel` and button rects against `CR_PANEL_2K` and `CR_SAFE_2K`.

## Ожидание / Реальность

Expected:
- `ContinueRunPanel` remains exact `CR_PANEL_2K` slot: `680x380`.
- Runtime content stays inside `CR_SAFE_2K`.
- Title restyle does not push subtitle/buttons outside the decorated panel safe zone.

Actual:
- `ContinueRunPanel` lays out as `680x391`.
- `ContinueRunButtons` bottom is `855`, while `CR_SAFE_2K` bottom is `844`.
- No direct title/subtitle/button overlap, but content exits the safe zone by 11 px.

Additional tooling risk:
- `tools/build_continue_run_title_logo.py --check-only` is not a real check-only mode; the argument is ignored and the script regenerates output.

## Окружение

`dev`, `origin/dev` up to date, 2026-06-29 10:12 Europe/Vilnius.
Executor commit observed: `d7d31cdf`.
Positive gates: `runtime_smoke_ui_test.gd` PASS, `ui_no_overlap_matrix_test.gd` PASS.
Disk cleanup: no disposable checkout; subagent removed `/tmp` QA files.
