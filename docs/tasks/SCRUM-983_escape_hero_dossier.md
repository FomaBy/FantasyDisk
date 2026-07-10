# SCRUM-983 — Escape Hero Dossier: compact numeric stats and clean pause buttons

Статус: in_progress  
Контур: Codex  
Owner: combined Design+Back-end `/root/scrum983_dossier`  
Thread/Worker: `/root/scrum983_dossier`  
Jira: SCRUM-983  
Branch: `codex/scrum-983-escape-dossier`  
Worktree: `/Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum-983-escape-dossier`  
Locked paths (Design stage): `docs/design/mockups/scrum983_escape_dossier/**`, `docs/design/references/scrum983_escape_dossier/**`, `docs/design/previews/scrum983_escape_dossier/**`, this task mirror, SCRUM-983 unique test-plan files  
Explicitly excluded until SCRUM-981 release: `scripts/ui_screens.gd`, `scripts/pause_stats_menu.gd`, shared menu/current-state/content-registry docs, `tests/runtime_smoke_test.gd`, SCRUM-981/SCRUM-1030/SCRUM-985/Claude paths

## Context

The current Escape dossier spends visible space on explanations and carries
danger-red treatment too broadly. The user wants the important hero/build stats
as compact numeric rows/chips, full explanations on hover/focus and danger red
reserved for the destructive End Run action.

## Acceptance Criteria

- [ ] Hero dossier shows compact localized stat labels plus numeric values, not always-visible explanatory paragraphs.
- [ ] Attack speed, crit chance, crit damage and the other important derived stats use correct compact units.
- [ ] Hover and keyboard/gamepad focus expose a complete tooltip for every stat.
- [ ] All content/hitboxes/focus/scroll lanes stay inside the exact shared gold-shell safe zone at 1280×720, 1920×1080 and 2560×1440.
- [ ] Continue and Main Menu are neutral with no red glow/tint; Settings is neutral; End Run alone remains danger red.
- [ ] Focus starts on Continue and reaches all actions and stat tooltip targets without a trap.
- [ ] Focused UI/no-overlap/gamepad/live-resize tests and real windowed screenshots cover the dossier.
- [ ] Runtime smoke and full regression gate pass before push to `origin/dev`.

## Work Log

- 2026-07-10: Jira checked in current sprint 199; issue was To Do, unassigned,
  Codex-labeled and had only a historical backlog note. No SCRUM-983 local mirror,
  dirty unique path or active owner existed. Claimed in Jira before edits.
- 2026-07-10: created clean worktree from `origin/dev` `23e15aed0`; preserved all
  active Claude, SCRUM-981, SCRUM-1030 and SCRUM-985 worktrees.
- 2026-07-10: read UI Director, content-zone compositor and PixelLab asset
  workflow; PixelLab config smoke `get_balance` PASS, no secrets printed.
- 2026-07-10: responsive `ui_plan_*.json` gates PASS at 720p/1080p/2K:
  `decision: ready_for_image`, `ok:true`, zero errors/warnings. The 688×384
  compositor guide also reports every sample zone `ok:true`.
- 2026-07-10: PixelLab source generation started from the approved exact-zone
  contract. Runtime/shared files remain untouched until `/root` releases locks.
- 2026-07-10: accepted PixelLab UI asset
  `ccc0e262-f062-4eb3-90d5-71c68c7db203` on the first attempt. Source is
  688×384 RGBA with real transparency (`alpha 0..255`, 96,081 transparent,
  168,111 opaque, zero partial-alpha pixels), no checkerboard or baked text.
  Visual QA confirms exactly one title well, one hero dossier, four stat wells
  2×2 and four actions with only End Run crimson. Compositor/debug report:
  all 10 zones `ok:true`.

## Design Paths

- Spec: `docs/design/mockups/scrum983_escape_dossier/spec.md`
- Runtime oracle: `docs/design/mockups/scrum983_escape_dossier/runtime_acceptance_test_plan.md`
- Plans/reports: `docs/design/mockups/scrum983_escape_dossier/ui_plan_*.json`, `*.report.json`
- Guides/previews: `docs/design/previews/scrum983_escape_dossier/`
- PixelLab manifest/source: `docs/design/references/scrum983_escape_dossier/`

## Current Blocker / Next Step

Design generation/acceptance continues now. Runtime integration is deliberately
blocked by the active SCRUM-981 shared-UI locks. After the Design commit, keep
the Jira issue `В работе` with a fresh heartbeat and wait for explicit release;
do not push the design-only commit to `dev` until safe rebase/integration.
