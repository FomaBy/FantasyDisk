# SCRUM-971 — Atlas/Guild selected-class name above the constellation tree

Статус: done
Версия: 0.2.1
Jira: SCRUM-971
Контур: Codex
Owner: Backend/Codex `/root`
Thread/Worker: `root-next3`
Branch: `codex/scrum971-atlas-class-label`

## Scope And Locks

Locked runtime scope: the selected-class label and responsive center-column
hunk of `scripts/ui_screens.gd`. Focused coverage:
`tests/atlas_scrum971_selected_class_label_test.gd`. Evidence/spec paths:
`docs/design/mockups/scrum971_atlas_class_label/`,
`docs/design/references/scrum971_atlas_class_label/`, this mirror, and the Atlas
paragraphs in `meta_constellations.md`, `menus_ui.md`, and
`current_game_state.md`.

Explicitly excluded: Atlas frame/source art, constellation or Guild graph data,
node geometry, progression/balance, class configs, Hero Select, Shop, and all
SCRUM-952 paths. SCRUM-970 is accepted and released; the new work must preserve
its real-pointer and scratch-`user://` contract.

## UX / Architecture Decision

The existing header has no safe empty segment: it already owns both tabs,
resource chips, responsive spacers, and Back. The selected localized class name
therefore receives a compact native-text row above the central canvas. A
responsive center `VBoxContainer` owns that row and the existing expanding
canvas. The class strip and right dossier remain body siblings; the outer frame
and all authored content margins remain unchanged.

Source of truth is
`ProgressionData.character_config(class_id).title`, identical to the class
medallion tooltip. `_atlas_refresh()` owns the text assignment, so initial open,
medallion selection, responsive refresh, and Constellation/Guild tab switches
cannot drift.

No new panel or texture is added. The label is centered native gold text with a
dark outline and `MOUSE_FILTER_IGNORE`.

## Pre-Implementation Evidence

- Fresh branch/worktree from `origin/dev` `50016c95e`.
- Jira detailed owner/worker/lane/locks heartbeat posted before source edits.
- SCRUM-970 baseline real-pointer matrix PASS at 1280×720, 1920×1080,
  2048×1152, and 2560×1440 with isolated scratch user data.
- Windowed baseline screenshots confirm the header is occupied and the center
  canvas is the only correct ownership region.
- Content-zone plan: `ui_plan.json` → `decision: ready_for_image`; 17 class
  medallions fit as 9 two-column rows without a scrollbar, and the native-title
  zone fits at 15 px down to the declared 10 px minimum.
- PixelLab asset `d17b4090-9c7c-4e98-91e8-b788be339530` generated before
  runtime implementation; source SHA-256
  `945f9aff7f7d4432fd7df3dfacb2d7578745b055f73b993bb8afa6b87fca0efa`.
  Content-zone composite fits `БЕРСЕРК` on one line and keeps frame ornament,
  controls, socket art, and graph lines outside the title zone.

## Verification Contract

Focused matrix covers 1280×720, 1920×1080, 2048×1152, and 2560×1440. It checks
all 17 localized titles; same-dispatch medallion updates; visibility on both
tabs; native lightweight styling; parent/content-zone ownership; and no overlap
with header, class strip, canvas, dossier, or footer. Existing SCRUM-970 bounded
pointer, allocation, tab, reset, Back, gamepad, no-overlap, theme, UI runtime,
and full runtime gates remain required.

## Implementation Result

- Added native `AtlasSelectedClassLabel` above `AtlasCanvas` inside responsive
  `AtlasCenterColumn`; no runtime texture or decorative panel was added.
- `_atlas_refresh()` resolves the selected title through
  `ProgressionData.character_config(class_id)` and updates it synchronously on
  initial open, all 17 medallions, and both tabs.
- Visual inspection of Metal captures at 1280×720 and 2048×1152 confirms the
  label is readable over the starfield and does not cross the outer ornament,
  header plates/currencies, constellation sockets, dossier, or footer.

## Green Gate

PASS on the implementation tree:

- `atlas_scrum971_selected_class_label_test.gd` headless + windowed Metal;
- `atlas_scrum970_clickability_test.gd` bounded pointer matrix;
- `meta40_atlas_screen_smoke_test.gd`, `meta_skill_tree_smoke_test.gd`,
  `skill_tree_per_hero_test.gd`;
- `ui_no_overlap_matrix_test.gd`, `dark_fantasy_ui_theme_test.gd`;
- `gamepad_menu_focus_test.gd`, `gamepad_full_flow_smoke_test.gd`;
- `runtime_smoke_ui_test.gd`, full `runtime_smoke_test.gd`.

All stateful runs used isolated HOME/XDG scratch roots; SCRUM-970 and SCRUM-971
also enforce their explicit test-only `--user-data-dir` argument. Runtime UI/full
emit the known dummy-renderer screenshot diagnostic but exit 0 and report PASS.

Independent QA: pending after push to `origin/dev`.

Implementation commit: `260dd13f1`, pushed directly to `origin/dev` after a
conflict-free rebase on QA evidence `6246ecb80`. Post-rebase focused,
SCRUM-970 bounded-pointer, and full runtime gates PASS.

Disk cleanup: removed the 446 MiB task `.godot` cache, 34 MiB Atlas capture
directories, and all owned isolated HOME/XDG/user-data scratch roots. The clean
task worktree is retained only until independent QA dispatch is recorded.

Thread cleanup: not a disposable worker thread.

## Independent QA Verdict — 2026-07-11

**PASSED** on a disposable read-only production checkout at fresh
`origin/dev` (`1c1d27e59` before QA evidence). Implementation under review:
`260dd13f1`.

- PixelLab MCP provenance is present and internally traceable: UI asset
  `d17b4090-9c7c-4e98-91e8-b788be339530`, committed source SHA-256
  `945f9aff7f7d4432fd7df3dfacb2d7578745b055f73b993bb8afa6b87fca0efa`,
  `ui_plan.report.json` decision `ready_for_image`, and a passing compositor
  fit report. The generated mockup is spec/reference evidence only; the runtime
  does not reuse its art layer and reserves a real native-label row above the
  canvas.
- Focused `atlas_scrum971_selected_class_label_test.gd` PASS headless and
  windowed Metal at 1280×720, 1920×1080, 2048×1152, and 2560×1440. It verifies
  all 17 localized `ProgressionData` titles, same-dispatch medallion updates,
  visibility in Constellation and Guild, lightweight native styling, and exact
  non-intersection with header, class strip, canvas, dossier, footer, and the
  frame-safe Atlas layout.
- Independent visual inspection of Metal captures at 1280×720 and 2048×1152:
  title remains readable in empty starfield space above every graph node and
  line; it does not cover currency/Back/header controls, the dossier, footer,
  or any outer-frame ornament. No heavy panel was introduced.
- `atlas_scrum970_clickability_test.gd` PASS headless and windowed Metal with
  unique scratch `user://`: real bounded pointer path, preview/buy, Guild tab,
  reset/cancel, Back, and focus/navigation contract remain intact.
- Regression PASS: `gamepad_menu_focus_test.gd`,
  `gamepad_full_flow_smoke_test.gd`, `ui_no_overlap_matrix_test.gd`,
  `runtime_smoke_ui_test.gd`, and isolated full `runtime_smoke_test.gd`.
  Runtime UI/full emitted only the established dummy-renderer null-texture
  screenshot diagnostic and exited 0 with PASS.

Production code/assets were not modified by independent QA.

Disk cleanup: removed QA `.godot` import cache (446 MiB), Metal captures
(11 MiB), all per-run HOME/XDG/user-data scratch roots, and the disposable QA
worktree/branch after evidence push.

Thread cleanup: disposable QA subagent returned to the dispatcher after Jira,
GitHub, and disk cleanup.
