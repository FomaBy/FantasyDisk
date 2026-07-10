# BUG: SCRUM-975 compact scroll geometry and layout guide are incomplete

Статус: in_progress
Приоритет: high
Роль: Design
Контур: Codex
Owner: Design/Codex
Thread: `/root/scrum1030_design`
Branch / worktree: `codex/scrum-1030-settings-design-fix` /
`/Users/sergeyfomin/Documents/FantasyDisk_worktrees/scrum-1030-settings-design-fix`
Locked paths: claimed Design scope is
`docs/design/references/scrum975_settings_game_tab/**`,
`docs/design/previews/scrum975_settings_game_tab/**`, and this mirror
Jira: SCRUM-1030
Sprint / fixVersion: `Спринт 0.2.1` / `0.2.1`
Blocked issue: SCRUM-975
Найдено QA при тестировании:
`docs/tasks/SCRUM-975_settings_four_tab_game_design.md`

## Autonomy / Approval

The user pre-approved all in-scope repository work. A Design/Codex worker must
claim Jira first, record exact locks, use FantasyDisk UI Director and the
content-zone planning workflow, preserve PixelLab provenance, validate, commit
and push to `origin/dev`, then return SCRUM-975 to independent QA.

## Контекст / Проблема

Independent QA of SCRUM-975 on fresh `origin/dev` `b243d6e26` found that the
accepted 720p planning package does not contain the complete scroll-content
inventory. `ui_plan_1280x720.json` ends after `row_monster_damage`, while
`layout_1280x720.json` renders only the two visible rows and a scroll hint.
There are no machine-readable rectangles for the other three rows, their
label/slider/value hitboxes or reset. The planning validator therefore reports
`ready_for_image` without validating most of the scrolled controls.

The committed `layout_2560x1440.guide.png` and `layout_guide.report.json` are
also stale relative to committed `layout.json`: a fresh renderer run uses
204px tab content zones at x=752/1036/1320/1604, while the committed guide says
164px at x=772/1056/1340/1624 and includes five slider zones that the canonical
layout source does not contain.

## Воспроизведение

1. Open `ui_plan_1280x720.json` and `layout_1280x720.json`; list the declared
   scroll rows and child control zones.
2. Run `validate_ui_layout_plan.py` against the compact plan; observe
   `ready_for_image` although rows 3–5 and reset are absent from the plan.
3. Render a guide from committed `layout.json` with
   `render_content_zones.py --guide-output` and compare it with the committed
   guide/report; `cmp`/`diff` show the geometry mismatch above.
4. Inspect the 1280 final/debug preview; only the top scroll state exists, so
   the omitted bottom controls cannot be checked against the frame interior.

## Ожидание / Реальность

Ожидание: committed machine-readable plans and reproducible guides
define every row, label, slider/value hitbox and reset for the full 720p scroll
content, and all artifacts agree with the accepted spec/final previews.

Реальность: the compact planning gate passes an incomplete content
inventory, and the wide guide/report contradict the committed canonical layout.
SCRUM-975 acceptance for all controls/hit areas and exact responsive geometry is
therefore unproven.

## Acceptance Criteria

- [ ] The 1280×720 plan includes all five row containers,
      label/slider/value hitboxes, reset and the 14px scrollbar lane within an
      explicit scroll content canvas; fixed header/back/tabs remain outside it.
- [ ] Top and bottom 720p debug evidence proves every scrolled control stays
      inside the true empty panel interior and does not overlap the scrollbar,
      scroll hint, separators or frame ornament.
- [ ] `validate_ui_layout_plan.py` returns `ready_for_image` only after the
      complete content inventory is collision-checked.
- [ ] The 2560 guide/report is regenerated from the committed canonical source;
      an exact rerun matches it, and spec/ui_plan/layout rectangles no longer
      contradict each other.
- [ ] 1280×720, 1920×1080 and 2560×1440 compositor reports remain `ok: true`;
      PixelLab provenance/source layers remain intact and no runtime
      GDScript/settings/gameplay path changes.
- [ ] The correction is pushed to `origin/dev` and SCRUM-975 passes an
      independent recheck.

## Work Log

- 2026-07-10: Jira claimed before edits by Design/Codex
  `/root/scrum1030_design`; scoped dirty-path audit was clean and a fresh
  worktree was created from `origin/dev` `23e15aed0`.
- 2026-07-10: the compact plan now contains an explicit `878×520` logical
  scroll-content canvas, all five 842×56 rows, separate label/slider/value
  fields, reset, physical `892×306` viewport and a reserved 14px scrollbar
  lane. Header, Back and the 2×2 tab grid remain fixed outside the viewport.
- 2026-07-10: top (`scroll_y=0`) and bottom (`scroll_y=214`) compositor layouts
  and final/debug evidence were added. The focused geometry gate proves their
  transforms, row-child containment, lane exclusion and fixed-zone identity.
- 2026-07-10: the canonical 2K layout now includes exact slider fields and
  matching label/value rectangles. Its guide/report and the 1080p derivative
  were regenerated from the canonical source instead of preserving the stale
  manual guide geometry.
- 2026-07-10: PixelLab MCP config access remained healthy. A dedicated
  textless bottom-scroll state source was queued as
  `1b60618f-a8ad-4695-82d8-099fbf1ad516`; no generic image fallback or runtime
  path was used.

## QA Evidence

- PixelLab/source post-processing and all three final composites reproduce
  byte-for-byte from committed sources.
- Visible final/debug previews are visually clean; the failure is the missing
  proof/contract for offscreen controls and the stale canonical guide.
- Godot 4.7 full runtime, UI, overlap, theme, animation, meta, targeting and
  gamepad regression gates all passed; this is a Design evidence/geometry bug,
  not a runtime regression.
