# SCRUM-983 — Escape Hero Dossier: compact numeric stats and clean pause buttons

Статус: in_progress  
Контур: Codex  
Owner: combined Design+Back-end `/root/scrum983_dossier`  
Thread/Worker: `/root/scrum983_dossier`  
Jira: SCRUM-983  
Branch: `codex/scrum-983-escape-dossier`  
Worktree: `/Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum-983-escape-dossier`  
Locked paths: `scripts/pause_stats_menu.gd`, `tests/scrum983_escape_dossier_test.gd`, `tools/capture_scrum983_escape_dossier.gd`, `tests/ui_no_overlap_matrix_test.gd`, `build/qa/scrum983/**`, SCRUM-983 design package, this mirror, and the touched current/menu/visual-style docs
Explicitly excluded: `scripts/ui_screens.gd` (Claude SCRUM-968), `tests/runtime_smoke_test.gd` until the active Priest test lock is released, SCRUM-993/Atlas and every other worker path

## Context

The current Escape dossier spends visible space on explanations and carries
danger-red treatment too broadly. The user wants the important hero/build stats
as compact numeric rows/chips, full explanations on hover/focus and danger red
reserved for the destructive End Run action.

## Acceptance Criteria

- [x] Hero dossier shows compact localized stat labels plus numeric values, not always-visible explanatory paragraphs.
- [x] Attack speed, crit chance, crit damage and the other important derived stats use correct compact units.
- [x] Hover and keyboard/gamepad focus expose a complete tooltip for every stat.
- [x] All content/hitboxes/focus/scroll lanes stay inside the exact shared gold-shell safe zone at 1280×720, 1920×1080 and 2560×1440.
- [x] Continue and Main Menu are neutral with no red glow/tint; Settings is neutral; End Run alone remains danger red.
- [x] Focus starts on Continue and reaches all actions and stat tooltip targets without a trap.
- [x] Focused UI/no-overlap/gamepad/live-resize tests and real windowed screenshots cover the dossier.
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
- 2026-07-10: after SCRUM-981 release, rebased the accepted design package and
  implemented the responsive dossier in `scripts/pause_stats_menu.gd`. The
  shared frame is now a visual-only final layer; header, independently scrolling
  hero/derived columns and the fixed action footer use the exact 720p/1080p/2K
  rectangles from the accepted spec.
- 2026-07-10: base stats are 8 real semantic rows (one compact column at 720p,
  two at wider targets). Every base/survival/derived row is focusable and opens
  a complete localized tooltip with value, explanation, formula/source and
  influences. Focus navigation is geometric across grids and transfers to the
  nearest footer action without traps.
- 2026-07-10: focused geometry/content/tooltip/focus/live-resize gate PASS;
  dark-fantasy theme PASS; gamepad in-run PASS three consecutive times;
  gamepad full-flow PASS; runtime UI smoke PASS (known dummy-renderer capture
  warning only); no-overlap matrix PASS after replacing its obsolete visual
  frame peer with semantic header/body/footer peers.
- 2026-07-10: real windowed Metal captures PASS at 1280×720, 1920×1080 and
  2560×1440. Visual review confirms all labels, hitboxes, scroll lanes and focus
  art remain inside the inner content rect and no action/stat covers the frame.
- 2026-07-10: post-review fixed two screenshot-only defects that structural
  bounds checks could miss. The 1080p two-column base-stat rows now preserve a
  readable localized-name lane (oracle minimum: rendered `Сила`), and four
  alpha-1 reserve masks cover the complete viewport-minus-inner area below
  content/final frame so the underlying combat HUD cannot bleed through the
  ornament. Focused gate and all three windowed captures were regenerated PASS.
- 2026-07-10: independent implementation review closed three additional
  false-green risks. Derived chips now use measured compact Russian aliases and
  a responsive 54–64px value reserve with both text lanes asserted uncut;
  every stat (including long priority/formula cases) is focus-tested against an
  actual clipped 430×288 tooltip viewport; and footer Up neighbors are selected
  from clipped-visible rows only. Fixture Main/SubViewport WeakRefs are asserted
  released after every case. Focused/capture/overlap/theme/gamepad×3/full-flow/
  runtime-UI gates were rerun PASS.
- 2026-07-10: second independent review removed the remaining dynamic
  false-greens. Stat hover no longer invokes the generic 460/620px engine path;
  hover and focus share the bounded 430×288 panel, with wheel/Page/gamepad-
  shoulder access to long tails. Scroll changes now rebuild footer neighbors;
  the focused oracle scrolls both columns, checks all four actions and performs
  a physical `ui_up` transition. A Druid/summon-amulet fixture adds the
  summoner-only `summon_amount` row to the exhaustive tooltip/cleanup matrix.
- 2026-07-10: manual re-review closed wheel ownership: a focus-only tooltip no
  longer steals wheel after the pointer leaves stat rows. Physical oracle proves
  wheel-outside scrolls Hero content without changing tooltip scroll, while
  wheel-on-hover still scrolls the bounded tooltip. Review verdict: PASS.

## Design Paths

- Spec: `docs/design/mockups/scrum983_escape_dossier/spec.md`
- Runtime oracle: `docs/design/mockups/scrum983_escape_dossier/runtime_acceptance_test_plan.md`
- Plans/reports: `docs/design/mockups/scrum983_escape_dossier/ui_plan_*.json`, `*.report.json`
- Guides/previews: `docs/design/previews/scrum983_escape_dossier/`
- PixelLab manifest/source: `docs/design/references/scrum983_escape_dossier/`

## Current Blocker / Next Step

Implementation and focused/UI regression gates are green. The only remaining
gate is the repository-wide `tests/runtime_smoke_test.gd`: its legacy dossier
assertion must be updated from the old VBox/button-height contract to the real
`BaseStatsGrid` and exact 60/72px footer after the active Priest worker releases
its current test lock. Then rebase on fresh `origin/dev`, run the full smoke,
commit/push directly to `dev`, route Jira to `Контроль качества`, sync the
targeted mirror and remove the disposable worktree/cache.
