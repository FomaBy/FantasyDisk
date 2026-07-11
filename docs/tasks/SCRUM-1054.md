# SCRUM-1049 Bug: gratitude button focus is yellow instead of neutral

Статус: in_progress
Версия: 0.2.1
Jira: SCRUM-1054
Контур: Codex
Owner: Back-end
Thread: /root/ui_unification_backend_focus_fix
Locked paths: `scripts/ui_screens.gd` gratitude focus color, relevant SCRUM-1051 tests, result section in this file

## Context / problem

Independent QA for SCRUM-1049 found that `MainMenuCreditsButton` focus uses a gold/yellow border `Color(0.96, 0.80, 0.46)`. The shared FantasyDisk UI contract and SCRUM-1050 spec require a neutral-bright, non-yellow focus state.

## Acceptance criteria

- Credits focus is clearly visible but low-saturation/neutral.
- Default/hover/pressed/disabled geometry and exact 64/72/88 responsive rects do not change.
- Focused semantic-family, gold-shell and dark-fantasy theme tests include and pass a non-yellow focus assertion.

## Back-end result (2026-07-11)

Status: fixed in shared worktree; root owns commit/push/Jira transition.

- `scripts/ui_screens.gd::_gratitude_button_style("focus")` now uses a neutral
  cool bright-metal border `Color(0.84, 0.88, 0.94, 0.98)` and neutral dark
  backing `Color(0.11, 0.12, 0.14, 0.58)`. Border saturation is approximately
  `0.106`, blue remains the strongest channel, and the state is visibly
  distinct from the warm hover treatment.
- Border width, content margins, corner radius and all responsive placement
  calculations are unchanged.
- `tests/scrum1051_ui_button_family_test.gd` now rejects focus colors with
  saturation above `0.15`, yellow/warm channel ordering, or a focus border equal
  to hover.

Verification:

- PASS `tests/scrum1051_ui_button_family_test.gd`;
- PASS `tests/scrum981_gold_menu_shell_test.gd` at 1280×720, 1920×1080 and
  2560×1440, including live resize;
- PASS `tests/dark_fantasy_ui_theme_test.gd`.

Files changed: `scripts/ui_screens.gd`,
`tests/scrum1051_ui_button_family_test.gd`, this result section.

No commit/push performed by subagent, per root instruction. Disk cleanup: none
created.
