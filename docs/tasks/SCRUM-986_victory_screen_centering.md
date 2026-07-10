# SCRUM-986 — Victory screen centering

Статус: in_progress
Jira: SCRUM-986
Версия: 0.2.1
Контур: Codex
Owner / Thread: Backend/Codex `/root`, combined with SCRUM-981/SCRUM-1032
Branch / worktree: `codex/scrum-981-gold-menu-shell` /
`/Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum-981-gold-menu-shell`
Locked paths: `scripts/ui_screens.gd`, `tests/ui_no_overlap_matrix_test.gd`,
`tests/scrum986_victory_centering_test.gd`, this mirror and focused evidence

## Preflight evidence

The SCRUM-981 full Victory result panel is already exact-centered and safe:

- 1280x720: `Rect2(391.5,133,497,454)`, center `(640,360)`;
- 1920x1080: `Rect2(575.5,189,769,702)`, center `(960,540)`;
- 2560x1440: `Rect2(831,310,898,820)`, center `(1280,720)`.

The transient `VictoryBannerFrame` still used the original 2K absolute
`y=608..832`. Its center stayed at `y=720`, so it was `+360px` below center and
clipped by `112px` at 1280x720, and `+180px` below center at 1920x1080.

## Fix

- Keep the canonical `960x224` chip, style, label, tween, 1.3s timing and
  continue callback unchanged.
- Anchor both axes at `0.5`; use vertical offsets `-112/+112`.
- Require the full frame inside the viewport and gold-shell safe area.
- Cover transient banner + full result modal at 1280x720, 1920x1080,
  2560x1440 and live 2560→1280 resize.
- Strengthen the shared no-overlap matrix so `victory_banner` requires viewport
  fit instead of exempting the transient frame.

## Acceptance

- [x] Runtime geometry uses responsive center anchors.
- [x] Focused test and no-overlap oracle are implemented.
- [x] Focused/no-overlap/runtime UI/gamepad full-flow gates PASS.
- [ ] Full runtime gate PASS after final rebase and Claude umbrella smoke lock
      release.
- [ ] Result committed and pushed to `origin/dev`, then routed to independent QA.

Disk cleanup: pending shared SCRUM-981 final gate/landing.
